import EventEmitter from 'eventemitter3';
import { TranscriptSegment } from '../types';

export type WSState = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

export type WebSocketEvents = {
  transcript: (segment: TranscriptSegment) => void;
  stateChange: (state: WSState) => void;
  error: (msg: string) => void;
};

/**
 * WebSocketManager.ts
 * Manages WebSocket connection, queues raw PCM audio frames if offline, and auto-reconnects.
 */
export class WebSocketManager extends EventEmitter<WebSocketEvents> {
  private ws: WebSocket | null = null;
  private _sessionId: string | null = null;
  private state: WSState = 'disconnected';
  private reconnectAttempts = 0;
  private pendingQueue: Array<{ header: string; buffer: ArrayBuffer }> = [];
  
  private readonly maxReconnects = 5;
  private readonly backoffDelays = [1000, 2000, 4000, 8000, 30000];

  get sessionId(): string | null {
    return this._sessionId;
  }

  connect(wsUrl: string): void {
    if (this._sessionId === null) {
      this._sessionId = crypto.randomUUID();
    }
    this._setState(this.reconnectAttempts > 0 ? 'reconnecting' : 'connecting');

    try {
      this.ws = new WebSocket(`${wsUrl}/ws/transcribe`);
      this.ws.binaryType = 'arraybuffer';

      this.ws.onopen = () => {
        this.reconnectAttempts = 0;
        this._setState('connected');
        console.log(`[WebSocketManager] Connected. ID: ${this._sessionId}`);
        this._flushQueue();
      };

      this.ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data as string) as TranscriptSegment & { type?: string };
          if (msg.type === 'transcript') {
            this.emit('transcript', msg);
          }
        } catch {
          console.warn('[WebSocketManager] Could not parse message', event.data);
        }
      };

      this.ws.onclose = () => {
        this._setState('disconnected');
        this._tryReconnect(wsUrl);
      };

      this.ws.onerror = (e) => {
        console.error('[WebSocketManager] WebSocket error', e);
        this.emit('error', 'WebSocket connection error');
      };
    } catch (err) {
      this.emit('error', String(err));
    }
  }

  sendAudioChunk(chunk: Float32Array, speaker: 'you' | 'them'): void {
    if (!this._sessionId) return;

    // Send JSON control header
    const header = JSON.stringify({
      type: 'audio',
      speaker,
      session_id: this._sessionId,
    });

    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      this.pendingQueue.push({ header, buffer: chunk.buffer as ArrayBuffer });
      if (this.pendingQueue.length > 10) {
        console.warn('[WebSocketManager] Queue max 10 reached, dropping oldest audio chunk');
        this.pendingQueue.shift();
      }
      return;
    }

    this.ws.send(header);
    this.ws.send(chunk.buffer as ArrayBuffer);
  }

  disconnect(): void {
    if (this.ws && this._sessionId && this.ws.readyState === WebSocket.OPEN) {
      try {
        this.ws.send(JSON.stringify({ type: 'end_session', session_id: this._sessionId }));
      } catch { /* ignore */ }
      this.ws.close();
    }
    this.ws = null;
    this._sessionId = null;
    this.pendingQueue = [];
    this.reconnectAttempts = 0;
    this._setState('disconnected');
  }

  private _setState(newState: WSState) {
    if (this.state !== newState) {
      this.state = newState;
      this.emit('stateChange', this.state);
    }
  }

  private _flushQueue() {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    for (const item of this.pendingQueue) {
      this.ws.send(item.header);
      this.ws.send(item.buffer);
    }
    this.pendingQueue = [];
  }

  private _tryReconnect(wsUrl: string): void {
    if (this._sessionId === null) return; // Means intentional disconnect
    if (this.reconnectAttempts < this.maxReconnects) {
      const delay = this.backoffDelays[this.reconnectAttempts] || 30000;
      this.reconnectAttempts++;
      console.log(`[WebSocketManager] Reconnecting in ${delay}ms...`);
      setTimeout(() => {
        if (this._sessionId) this.connect(wsUrl);
      }, delay);
    }
  }
}
