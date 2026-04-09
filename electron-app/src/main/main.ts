import { app, BrowserWindow, ipcMain, dialog } from 'electron';
import * as path from 'path';

let mainWindow: BrowserWindow | null = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 420,
    height: 700,
    minWidth: 400,
    minHeight: 600,
    frame: false,
    transparent: false,
    alwaysOnTop: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  // Windows Content Protection (replaces NSWindow.sharingType = .none)
  mainWindow.setContentProtection(true);

  if (process.platform === 'win32') {
    // Attempting to set display affinity for Windows using native modules might be needed,
    // but setContentProtection(true) usually covers basic screen capture hiding in recent Electron versions.
    try {
       mainWindow.setContentProtection(true);
    } catch (e) {
       console.warn("Could not set content protection on Windows", e);
    }
  }

  // Determine whether to load the Dev server or the built index.html
  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:5173');
  } else {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC Handlers
ipcMain.handle('keychain:get', async (event, key) => {
  // Mock implementations for Phase 1 testing
  console.log('keychain:get called for', key);
  return 'test-credential-value';
});

ipcMain.handle('keychain:set', async (event, key, value) => {
  console.log('keychain:set called for', key, value);
  return true;
});

ipcMain.handle('keychain:delete', async (event, key) => {
  console.log('keychain:delete called for', key);
  return true;
});

ipcMain.handle('session:save', async (event, data) => {
  console.log('session:save called');
  return true;
});

ipcMain.handle('folder:pick', async () => {
  if (mainWindow) {
    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ['openDirectory', 'createDirectory']
    });
    return result.canceled ? null : result.filePaths[0];
  }
  return null;
});

ipcMain.handle('app:version', () => {
  return app.getVersion();
});
