const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getCredential: (key: string) => ipcRenderer.invoke('keychain:get', key),
  setCredential: (key: string, value: string) => ipcRenderer.invoke('keychain:set', key, value),
  saveSession: (data: any) => ipcRenderer.invoke('session:save', data),
  pickFolder: () => ipcRenderer.invoke('folder:pick'),
  getVersion: () => ipcRenderer.invoke('app:version')
});
