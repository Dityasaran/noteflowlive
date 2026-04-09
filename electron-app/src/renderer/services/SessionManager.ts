import EventEmitter from 'eventemitter3';
import { SuggestionCard, TranscriptSegment } from '../types';

export type SessionEvents = {
  saved: (state: { folderPath: string }) => void;
};

export class SessionManager extends EventEmitter<SessionEvents> {
  private sessionId: string;
  private startedAt: string;
  private segments: TranscriptSegment[] = [];
  private suggestionsShown: SuggestionCard[] = [];
  private flushTimer: ReturnType<typeof setInterval> | null = null;
  private lastSavedCount = 0;

  constructor() {
    super();
    this.sessionId = crypto.randomUUID();
    this.startedAt = new Date().toISOString();
  }

  start() {
    this.stop();
    this.sessionId = crypto.randomUUID();
    this.startedAt = new Date().toISOString();
    this.segments = [];
    this.suggestionsShown = [];
    this.lastSavedCount = 0;

    this.flushTimer = setInterval(async () => {
      await this._flush(true);
    }, 60000);
  }

  stop() {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
    }
  }

  async endSession() {
    this.stop();
    if (this.segments.length > 0) {
      await this._flush(false);
    }
  }

  addSegment(seg: TranscriptSegment) {
    this.segments.push(seg);
  }

  addSuggestion(card: SuggestionCard) {
    this.suggestionsShown.push(card);
  }

  private async _flush(partial: boolean) {
    if (!window.electronAPI) return;
    if (partial && this.segments.length === this.lastSavedCount) return;

    const payload = {
      session_id: this.sessionId,
      started_at: this.startedAt,
      ended_at: partial ? null : new Date().toISOString(),
      transcript: [...this.segments],
      suggestions: [...this.suggestionsShown],
      partial
    };

    try {
      await window.electronAPI.saveSession(payload);
      this.lastSavedCount = this.segments.length;
      if (!partial) {
        const folder = await window.electronAPI.getCredential('KB_FOLDER');
        this.emit('saved', { folderPath: folder || 'Documents/NoteFlow' });
      }
    } catch (e) {
      console.warn('[SessionManager] Failed to flush to disk', e);
    }
  }
}
