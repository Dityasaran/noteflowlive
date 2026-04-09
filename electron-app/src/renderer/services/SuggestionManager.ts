import EventEmitter from 'eventemitter3';
import { ConversationState, SuggestionCard, TranscriptSegment } from '../types';
import { WebSocketManager } from './WebSocketManager';
import { VectorSearch } from './VectorSearch';
import { GeminiService } from './GeminiService';
import { KBManager } from './KBManager';

export type SuggestionEvents = {
  suggestion: (card: SuggestionCard) => void;
  thinking: (isThinking: boolean) => void;
};

export class SuggestionManager extends EventEmitter<SuggestionEvents> {
  private suggestions: SuggestionCard[] = [];
  private conversationState: ConversationState = {
    topic: 'Brainstorming',
    summary: 'Conversation started',
    openQuestions: [],
    tensions: [],
    recentDecisions: [],
    goals: [],
    confidence: 'medium'
  };
  private lastSuggestionTime: number = 0;
  private newThemUtterancesSinceStateUpdate: number = 0;
  private recentLines: TranscriptSegment[] = [];

  constructor(
    private wsManager: WebSocketManager,
    private vectorSearch: VectorSearch,
    private geminiService: GeminiService,
    private kbManager: KBManager
  ) {
    super();

    // Setup periodic dismissal
    setInterval(() => {
      const now = Date.now();
      const initialCount = this.suggestions.length;
      this.suggestions = this.suggestions.filter(c => (now - c.triggeredAt.getTime()) < 300_000);
      if (this.suggestions.length !== initialCount) {
        this.emit('suggestion', this.suggestions[0]); // mock re-trigger state binding hook logic
      }
    }, 15000);

    this.wsManager.on('transcript', (seg) => this._onTranscript(seg));
  }

  getSuggestions() {
    return this.suggestions;
  }

  dismiss(id: string) {
    this.suggestions = this.suggestions.filter(s => s.id !== id);
  }

  private async _onTranscript(segment: TranscriptSegment) {
    this.recentLines.push(segment);
    if (this.recentLines.length > 20) this.recentLines.shift();

    // 1. Gate: wait for "them", require 8 words
    if (segment.speaker === 'you') return;
    const words = segment.text.split(/\s+/).length;
    if (words < 8) return;

    this.newThemUtterancesSinceStateUpdate++;

    // 2. Gate: 90s cooldown
    const now = Date.now();
    if (now - this.lastSuggestionTime < 90_000) return;

    // 3. Gate: VectorSearch isReady
    if (!this.vectorSearch.isReady()) return;

    this.emit('thinking', true);
    let isPipelineActive = true;

    try {
      // 4. Embed utterance
      const restUrl = await this._getRestUrl();
      if (!restUrl) return;

      const embedRes = await fetch(`${restUrl}/v1/embeddings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ input: [segment.text], model: 'nomic-embed-text' }),
      });
      if (!embedRes.ok) return;
      const embedData = await embedRes.json();
      const embedding: number[] = embedData.data[0].embedding;

      // 5. Cosine search -> top 5
      const top5chunks = this.vectorSearch.search(embedding, 5);
      if (top5chunks.length === 0) return;

      // 6. Gate: top chunk score < 0.72
      if (top5chunks[0].score < 0.72) return;

      // 7. Parallel rerank + state update
      const promises: Promise<any>[] = [
        this.geminiService.rerank(segment.text, top5chunks)
      ];

      let stateUpdateIndex = -1;
      if (this.newThemUtterancesSinceStateUpdate >= 4) {
        stateUpdateIndex = promises.length;
        const formattedLines = this.recentLines.slice(-8).map(l => `${l.speaker === 'you' ? 'You' : 'Them'}: ${l.text}`);
        promises.push(this.geminiService.updateConversationState(this.conversationState, formattedLines, segment.text));
        this.newThemUtterancesSinceStateUpdate = 0;
      }

      const results = await Promise.all(promises);
      const reranked_topchunks = results[0];
      if (stateUpdateIndex !== -1) {
        this.conversationState = results[stateUpdateIndex];
      }

      // 8. Gate: conversation state low
      if (this.conversationState.confidence === 'low') return;

      // 9. Generate suggestion
      const recentFormatted = this.recentLines.slice(-4).map(l => `${l.speaker === 'you' ? 'You' : 'Them'}: ${l.text}`);
      const rawText = await this.geminiService.generateSuggestion(segment.text, this.conversationState, reranked_topchunks, recentFormatted);

      // 10. Emit card if not SKIP
      if (rawText !== 'SKIP') {
        this.lastSuggestionTime = Date.now();
        const top = reranked_topchunks[0] || top5chunks[0];
        
        const card: SuggestionCard = {
          id: crypto.randomUUID(),
          text: rawText,
          sourceFile: top.sourceFile,
          sourceBreadcrumb: top.breadcrumb,
          confidence: top.score > 0.85 ? 'high' : top.score > 0.72 ? 'medium' : 'low',
          triggeredAt: new Date()
        };

        this.suggestions = [card, ...this.suggestions].slice(0, 3);
        this.emit('suggestion', card);
      }
    } catch (err) {
      console.error('[SuggestionManager] Pipeline failed', err);
    } finally {
      if (isPipelineActive) {
        this.emit('thinking', false);
      }
    }
  }

  private async _getRestUrl() {
    if (!window.electronAPI) return null;
    return await window.electronAPI.getCredential('REST_URL');
  }
}
