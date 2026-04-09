import { ChunkResult } from './KBManager';
import { KBChunk } from '../types';

export class VectorSearch {
  private chunks: KBChunk[] = [];
  private normalizedEmbeddings: Map<string, number[]> = new Map();
  private ready = false;

  load(chunks: KBChunk[]) {
    this.chunks = chunks;
    this.normalizedEmbeddings.clear();
    
    // Normalize vectors on load for faster repeated searches
    for (const chunk of chunks) {
      if (chunk.embedding && chunk.embedding.length > 0) {
        this.normalizedEmbeddings.set(chunk.id, this._normalize(chunk.embedding));
      }
    }
    this.ready = chunks.length > 0;
  }

  isReady(): boolean {
    return this.ready;
  }

  search(queryEmbedding: number[], topK: number = 5): ChunkResult[] {
    if (!this.ready || this.chunks.length === 0) return [];

    const normQuery = this._normalize(queryEmbedding);
    const results: ChunkResult[] = [];

    for (const chunk of this.chunks) {
      const normDoc = this.normalizedEmbeddings.get(chunk.id);
      if (!normDoc) continue;

      const score = this._dotProduct(normQuery, normDoc);
      results.push({
        chunk,
        score,
        sourceFile: chunk.breadcrumb.split(' > ')[0] || chunk.filePath,
        breadcrumb: chunk.breadcrumb,
      });
    }

    return results.sort((a, b) => b.score - a.score).slice(0, topK);
  }

  private _normalize(vector: number[]): number[] {
    let mag = 0;
    for (let i = 0; i < vector.length; i++) mag += vector[i] * vector[i];
    mag = Math.sqrt(mag);
    if (mag === 0) return vector;
    
    const result = new Array(vector.length);
    for (let i = 0; i < vector.length; i++) {
        result[i] = vector[i] / mag;
    }
    return result;
  }

  private _dotProduct(v1: number[], v2: number[]): number {
    let dot = 0;
    const len = Math.min(v1.length, v2.length);
    for (let i = 0; i < len; i++) {
      dot += v1[i] * v2[i];
    }
    return dot;
  }
}
