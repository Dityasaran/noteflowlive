import EventEmitter from 'eventemitter3';

export type AudioChunkEvent = {
  audioChunk: (chunk: Float32Array, speaker: 'you' | 'them') => void;
};

/**
 * AudioCapture.ts
 * Captures microphone and system audio using the Web Audio API.
 * Emits raw Float32Array chunks of 16kHz mono audio.
 */
export class AudioCapture extends EventEmitter<AudioChunkEvent> {
  private micContext: AudioContext | null = null;
  private sysContext: AudioContext | null = null;
  private micProcessor: ScriptProcessorNode | null = null;
  private sysProcessor: ScriptProcessorNode | null = null;
  private micStream: MediaStream | null = null;
  private sysStream: MediaStream | null = null;

  async getAvailableDevices(): Promise<MediaDeviceInfo[]> {
    await navigator.mediaDevices.getUserMedia({ audio: true }); // Request permission to see labels
    return navigator.mediaDevices.enumerateDevices();
  }

  isSystemAudioAvailable(): boolean {
    const isMac = navigator.userAgent.toLowerCase().includes('mac');
    const isWin = navigator.userAgent.toLowerCase().includes('win');
    // On Windows, the browser provides display media audio natively.
    return isWin || isMac;
  }

  async start(): Promise<void> {
    const isMac = navigator.userAgent.toLowerCase().includes('mac');
    const devices = await this.getAvailableDevices();
    let blackholeId: string | null = null;

    if (isMac) {
      const bhDevice = devices.find(d => 
        d.kind === 'audioinput' && d.label.toLowerCase().includes('blackhole')
      );
      if (bhDevice) blackholeId = bhDevice.deviceId;
    }

    // Capture mic
    try {
      this.micStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: 16000,
          channelCount: 1,
          echoCancellation: false,
          noiseSuppression: false,
        },
      });
      this._setupContext(this.micStream, 'you', true);
      console.log('[AudioCapture] Mic started (16kHz mono)');
    } catch (e) {
      console.error('[AudioCapture] Failed to start mic:', e);
    }

    // Capture system
    try {
      if (isMac && blackholeId) {
        this.sysStream = await navigator.mediaDevices.getUserMedia({
          audio: {
            deviceId: { exact: blackholeId },
            sampleRate: 16000,
            channelCount: 1,
            echoCancellation: false,
            noiseSuppression: false,
          },
        });
        this._setupContext(this.sysStream, 'them', false);
        console.log('[AudioCapture] BlackHole system audio started');
      } else if (!isMac) {
        // Windows (or Linux)
        this.sysStream = await navigator.mediaDevices.getDisplayMedia({
          audio: {
            sampleRate: 16000,
            channelCount: 1,
          },
          video: true,
        });
        
        // We must stop the video track immediately so we only record audio
        this.sysStream.getVideoTracks().forEach(t => t.stop());
        
        this._setupContext(this.sysStream, 'them', false);
        console.log('[AudioCapture] DisplayMedia system audio started');
      } else {
        console.warn('[AudioCapture] System audio not available. Install BlackHole on Mac.');
      }
    } catch (e) {
      console.error('[AudioCapture] Failed to start system audio:', e);
    }
  }

  stop(): void {
    this.micProcessor?.disconnect();
    this.micContext?.close();
    this.micStream?.getTracks().forEach(t => t.stop());
    
    this.sysProcessor?.disconnect();
    this.sysContext?.close();
    this.sysStream?.getTracks().forEach(t => t.stop());

    this.micProcessor = null;
    this.micContext = null;
    this.micStream = null;
    this.sysProcessor = null;
    this.sysContext = null;
    this.sysStream = null;

    console.log('[AudioCapture] Stopped');
  }

  private _setupContext(stream: MediaStream, speaker: 'you' | 'them', isMic: boolean) {
    const context = new AudioContext({ sampleRate: 16000 });
    const source = context.createMediaStreamSource(stream);
    const processor = context.createScriptProcessor(4096, 1, 1);

    processor.onaudioprocess = (event) => {
      const channelData = event.inputBuffer.getChannelData(0);
      // Clone array buffer otherwise context might recycle it
      const chunk = new Float32Array(channelData);
      this.emit('audioChunk', chunk, speaker);
    };

    source.connect(processor);
    processor.connect(context.destination);

    if (isMic) {
      this.micContext = context;
      this.micProcessor = processor;
    } else {
      this.sysContext = context;
      this.sysProcessor = processor;
    }
  }
}
