import { ConversationState } from '../types';
import { ChunkResult } from './KBManager';

/**
 * GeminiService.ts
 * Uses Gemini API directly. Never caches the API key in memory properties.
 */
export class GeminiService {
  private readonly baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  private async _getKey(): Promise<string> {
    if (!window.electronAPI) return '';
    return (await window.electronAPI.getCredential('GEMINI_API_KEY')) || '';
  }

  async updateConversationState(
    current: ConversationState,
    recentLines: string[],
    latestUtterance: string
  ): Promise<ConversationState> {
    const key = await this._getKey();
    if (!key) return current;

    const prompt = `You are tracking the state of a live conversation.
Previous state: ${JSON.stringify(current)}
Recent transcript (last 8 lines): ${recentLines.join('\n')}
Latest utterance: "${latestUtterance}"
Return ONLY valid JSON, no markdown, no explanation:
{"topic":"...","summary":"...","openQuestions":[...],"tensions":[...],"recentDecisions":[...],"goals":[...],"confidence":"high"|"medium"|"low"}`;

    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), 8000);

    try {
      const response = await fetch(`${this.baseUrl}?key=${key}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 400 },
        }),
        signal: controller.signal,
      });

      const json = await response.json();
      let text = json?.candidates?.[0]?.content?.parts?.[0]?.text || '';
      
      text = text.trim();
      if (text.startsWith('```json')) text = text.slice(7).replace(/```$/, '').trim();
      else if (text.startsWith('```')) text = text.slice(3).replace(/```$/, '').trim();

      return JSON.parse(text) as ConversationState;
    } catch (e) {
      console.warn('[GeminiService] updateConversationState failed, returning unchanged', e);
      return current;
    } finally {
      clearTimeout(id);
    }
  }

  async rerank(query: string, chunks: ChunkResult[]): Promise<ChunkResult[]> {
    const key = await this._getKey();
    if (!key || chunks.length === 0) return chunks;

    const numbered_chunks = chunks.map((c, i) => `[${i}] ${c.breadcrumb}: ${c.chunk.body}`).join('\n\n');
    
    const prompt = `Rank these ${chunks.length} knowledge base chunks by relevance to: "${query}"
Return ONLY a JSON array of 0-based indices, most relevant first. Example: [2,0,4,1,3]
Chunks:
${numbered_chunks}`;

    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), 5000);

    try {
      const response = await fetch(`${this.baseUrl}?key=${key}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.1, maxOutputTokens: 50 },
        }),
        signal: controller.signal,
      });

      const json = await response.json();
      let text = json?.candidates?.[0]?.content?.parts?.[0]?.text || '';
      text = text.replace(/```json/g, '').replace(/```/g, '').trim();
      
      const indices: number[] = JSON.parse(text);
      if (Array.isArray(indices) && indices.length === chunks.length) {
        return indices.map(idx => chunks[idx]).filter(c => c !== undefined);
      }
      throw new Error("Invalid format");
    } catch {
      return chunks; // Return original cosine order on failure
    } finally {
      clearTimeout(id);
    }
  }

  async generateSuggestion(
    utterance: string,
    state: ConversationState,
    topChunks: ChunkResult[],
    recentLines: string[]
  ): Promise<string | 'SKIP'> {
    const key = await this._getKey();
    if (!key) return 'SKIP';

    const top_3_chunks_with_source = topChunks.slice(0,3).map(c => `Source: ${c.breadcrumb}\nContent: ${c.chunk.body}`).join('\n\n');

    const prompt = `You are a silent meeting assistant.
Topic: ${state.topic}
Summary: ${state.summary}
Open questions: ${state.openQuestions.join(', ')}
What they just said: "${utterance}"
Recent conversation: ${recentLines.slice(-4).join('\n')}
Relevant notes from knowledge base:
${top_3_chunks_with_source}
Suggest 1 specific talking point (max 2 sentences, no preamble, no markdown).
If the notes are not relevant enough, respond with exactly: SKIP`;

    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), 10000);

    try {
      const response = await fetch(`${this.baseUrl}?key=${key}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.3, maxOutputTokens: 300 },
        }),
        signal: controller.signal,
      });

      const json = await response.json();
      let text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
      
      if (!text || text.trim() === 'SKIP') return 'SKIP';
      
      return text.replace(/[*_#`]/g, '').trim(); // very brief markdown strip
    } catch {
      return 'SKIP';
    } finally {
      clearTimeout(id);
    }
  }
}
