import EventEmitter from 'eventemitter3';
import chokidar from 'chokidar';
import fs from 'fs';
import path from 'path';
import CryptoJS from 'crypto-js';
import { KBChunk } from '../types';

export type ChunkResult = {
  chunk: KBChunk;
  score: number;
  sourceFile: string;
  breadcrumb: string;
};

export type KBEvents = {
  indexing: (state: { current: number; total: number; fileName: string }) => void;
  ready: (state: { fileCount: number; chunkCount: number }) => void;
  error: (state: { message: string }) => void;
};

export class KBManager extends EventEmitter<KBEvents> {
  private chunks: KBChunk[] = [];
  private watcher: chokidar.FSWatcher | null = null;
  private gcpRestUrl: string = '';

  getChunks(): KBChunk[] {
    return this.chunks;
  }

  setRestUrl(url: string) {
    this.gcpRestUrl = url;
  }

  async startWatching(folderPath: string): Promise<void> {
    this.stopWatching();
    
    // Load cache
    const cacheStr = localStorage.getItem('kb_chunks');
    if (cacheStr) {
      try {
        this.chunks = JSON.parse(cacheStr);
        this.emit('ready', { fileCount: new Set(this.chunks.map(c => c.filePath)).size, chunkCount: this.chunks.length });
      } catch {
        this.chunks = [];
      }
    }

    if (!folderPath) {
      this.emit('error', { message: 'No folder path provided' });
      return;
    }

    try {
      if (!fs.statSync(folderPath).isDirectory()) {
         this.emit('error', { message: 'Path is not a directory' });
         return;
      }
    } catch {
      this.emit('error', { message: 'Invalid folder path' });
      return;
    }

    this.watcher = chokidar.watch(folderPath, {
      ignored: /(^|[\/\\])\../,
      persistent: true,
      depth: 5,
    });

    let initialScanComplete = false;
    let filesFound: string[] = [];

    this.watcher.on('add', (filePath) => {
      if (filePath.endsWith('.md') || filePath.endsWith('.txt')) {
        if (!initialScanComplete) {
          filesFound.push(filePath);
        } else {
          this._processFiles([filePath]);
        }
      }
    });

    this.watcher.on('change', (filePath) => {
      if (filePath.endsWith('.md') || filePath.endsWith('.txt')) {
        this._processFiles([filePath]);
      }
    });

    this.watcher.on('unlink', (filePath) => {
      const initialCount = this.chunks.length;
      this.chunks = this.chunks.filter(c => c.filePath !== filePath);
      if (this.chunks.length !== initialCount) {
        this._saveCache();
        this.emit('ready', { fileCount: new Set(this.chunks.map(c => c.filePath)).size, chunkCount: this.chunks.length });
      }
    });

    this.watcher.on('ready', () => {
      initialScanComplete = true;
      if (filesFound.length > 0) {
        this._processFiles(filesFound);
      }
    });
  }

  stopWatching(): void {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
  }

  async reindexAll(): Promise<void> {
    this.chunks = [];
    localStorage.removeItem('kb_chunks');
    if (this.watcher) {
       const watchedPaths = Object.keys(this.watcher.getWatched());
       if (watchedPaths.length > 0) {
           const rootPath = watchedPaths[0]; // best effort approximation for absolute root
           this.stopWatching();
           await this.startWatching(rootPath);
       }
    }
  }

  private async _processFiles(filePaths: string[]) {
    if (!this.gcpRestUrl) {
      this.emit('error', { message: 'GCP REST Base URL is not set in settings' });
      return;
    }

    let filesChanged = 0;
    
    for (let i = 0; i < filePaths.length; i++) {
      const filePath = filePaths[i];
      try {
        const content = fs.readFileSync(filePath, 'utf-8');
        const hash = CryptoJS.SHA256(content).toString();
        
        // Skip if already indexed with same hash
        if (this.chunks.some(c => c.filePath === filePath && c.fileHash === hash)) {
          continue;
        }

        this.emit('indexing', { current: i + 1, total: filePaths.length, fileName: path.basename(filePath) });

        // Remove old chunks for this file
        this.chunks = this.chunks.filter(c => c.filePath !== filePath);
        
        const newChunksText = this._chunkContent(filePath, content);
        
        // Batch Embedding
        const batchSize = 32;
        const newKBChunks: KBChunk[] = [];
        
        for (let j = 0; j < newChunksText.length; j += batchSize) {
          const batch = newChunksText.slice(j, j + batchSize);
          const response = await fetch(`${this.gcpRestUrl}/v1/embeddings`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ input: batch.map(b => b.textToEmbed), model: 'nomic-embed-text' }),
          });
          
          if (!response.ok) throw new Error(`Embedding API failed: ${response.statusText}`);
          const data = await response.json();
          const vectors: number[][] = data.data.map((item: any) => item.embedding);
          
          batch.forEach((info, index) => {
            newKBChunks.push({
              id: crypto.randomUUID(),
              filePath,
              breadcrumb: info.breadcrumb,
              body: info.body,
              embedding: vectors[index],
              fileHash: hash,
            });
          });
        }
        
        this.chunks.push(...newKBChunks);
        filesChanged++;
        
      } catch (err) {
        console.error(`Failed to process ${filePath}`, err);
      }
    }

    if (filesChanged > 0) {
      this._saveCache();
      this.emit('ready', { fileCount: new Set(this.chunks.map(c => c.filePath)).size, chunkCount: this.chunks.length });
    }
  }

  private _chunkContent(filePath: string, content: string): Array<{breadcrumb: string, textToEmbed: string, body: string}> {
    const fileName = path.basename(filePath);
    const results: Array<{breadcrumb: string, textToEmbed: string, body: string}> = [];
    
    if (filePath.endsWith('.md')) {
      const regex = /^(#{1,3})\s+(.*)$/gm;
      const lines = content.split('\n');
      let currentHeading = fileName;
      let currentBody: string[] = [];
      
      const pushChunk = () => {
        const bodyStr = currentBody.join('\n').trim();
        if (bodyStr.split(/\s+/).length >= 50) {
          const breadcrumb = `${fileName} > ${currentHeading}`;
          results.push({
            breadcrumb,
            body: bodyStr,
            textToEmbed: `${breadcrumb}\n\n${bodyStr}`
          });
        }
      };

      for (const line of lines) {
        const match = /^(#{1,3})\s+(.*)$/.exec(line);
        if (match) {
          pushChunk();
          currentHeading = match[2].trim();
          currentBody = [];
        } else {
          currentBody.push(line);
        }
      }
      pushChunk(); // flush last
    } else {
      // txt or headingless
      const pars = content.split('\n\n');
      let currentChunk: string[] = [];
      let wordCount = 0;
      
      const pushChunk = () => {
        const bodyStr = currentChunk.join('\n\n').trim();
        if (bodyStr.split(/\s+/).length >= 50) {
          const breadcrumb = `${fileName}`;
          results.push({
            breadcrumb,
            body: bodyStr,
            textToEmbed: `${breadcrumb}\n\n${bodyStr}`
          });
        }
      };

      for (const p of pars) {
        const words = p.split(/\s+/).length;
        if (wordCount + words > 400 && currentChunk.length > 0) {
          pushChunk();
          currentChunk = [];
          wordCount = 0;
        }
        currentChunk.push(p);
        wordCount += words;
      }
      pushChunk(); // flush last
    }
    
    return results;
  }

  private _saveCache() {
    try {
      localStorage.setItem('kb_chunks', JSON.stringify(this.chunks));
    } catch (e) {
      console.warn("Could not save to localStorage, size limit exceeded?", e);
    }
  }
}
