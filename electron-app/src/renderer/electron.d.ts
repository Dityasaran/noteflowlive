// Type declarations for the Electron IPC bridge exposed via preload.ts
export interface ElectronAPI {
  getCredential: (key: string) => Promise<string | null>;
  setCredential: (key: string, value: string) => Promise<boolean>;
  saveSession: (data: unknown) => Promise<boolean>;
  pickFolder: () => Promise<string | null>;
  getVersion: () => Promise<string>;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}
