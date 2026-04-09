import React, { useState, useEffect, useRef } from 'react';
import { TranscriptSegment, AppSettings, SuggestionCard as SuggestionCardType } from './types';
import { AudioCapture } from './services/AudioCapture';
import { WebSocketManager, WSState } from './services/WebSocketManager';
import { KBManager } from './services/KBManager';
import { VectorSearch } from './services/VectorSearch';
import { GeminiService } from './services/GeminiService';
import { SuggestionManager } from './services/SuggestionManager';
import { SessionManager } from './services/SessionManager';

import ConsentScreen from './components/ConsentScreen';
import StatusBar from './components/StatusBar';
import MainWindow from './components/MainWindow';
import SettingsPanel from './components/SettingsPanel';

function App() {
  const [hasAcceptedConsent, setHasAcceptedConsent] = useState(() => {
    return localStorage.getItem('hasAcceptedConsent') === 'true';
  });
  
  const [version, setVersion] = useState<string>('');
  const [isLive, setIsLive] = useState(false);
  const [wsState, setWsState] = useState<WSState>('disconnected');
  const [segments, setSegments] = useState<TranscriptSegment[]>([]);
  const [suggestions, setSuggestions] = useState<SuggestionCardType[]>([]);
  const [isThinking, setIsThinking] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  
  // KB state
  const [kbState, setKbState] = useState({ indexedFileCount: 0, indexingCurrent: 0, indexingTotal: 0, error: '' });
  const [saveToast, setSaveToast] = useState<{folder: string} | null>(null);

  const [settings, setSettings] = useState<AppSettings>({
    gcpWebSocketUrl: '',
    gcpRestUrl: '',
    geminiApiKey: '',
    kbFolderPath: ''
  });

  const servicesRef = useRef<{
    audioCap: AudioCapture;
    wsMan: WebSocketManager;
    kbMan: KBManager;
    vecSearch: VectorSearch;
    gemService: GeminiService;
    suggMan: SuggestionManager;
    sessMan: SessionManager;
  } | null>(null);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === ',') {
        e.preventDefault();
        setShowSettings(true);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useEffect(() => {
    if (saveToast) {
      const id = setTimeout(() => setSaveToast(null), 3000);
      return () => clearTimeout(id);
    }
  }, [saveToast]);

  useEffect(() => {
    let unmounted = false;

    const initServices = async () => {
      let wsUrl = '', restUrl = '', gemApiKey = '', kbFolder = '';

      if (window.electronAPI) {
        window.electronAPI.getVersion().then(v => { if (!unmounted) setVersion(v); }).catch(() => {});
        try {
          wsUrl = await window.electronAPI.getCredential('WS_URL') || '';
          restUrl = await window.electronAPI.getCredential('REST_URL') || '';
          gemApiKey = await window.electronAPI.getCredential('GEMINI_API_KEY') || '';
          kbFolder = await window.electronAPI.getCredential('KB_FOLDER') || '';
          if (!unmounted) setSettings({ gcpWebSocketUrl: wsUrl, gcpRestUrl: restUrl, geminiApiKey: gemApiKey, kbFolderPath: kbFolder });
        } catch (e) {
          console.error("Credentials error", e);
        }
      }

      if (unmounted) return;

      const wsMan = new WebSocketManager();
      const kbMan = new KBManager();
      const vecSearch = new VectorSearch();
      const gemService = new GeminiService();
      const suggMan = new SuggestionManager(wsMan, vecSearch, gemService, kbMan);
      const sessMan = new SessionManager();
      const audioCap = new AudioCapture();

      kbMan.setRestUrl(restUrl);

      // KB Wiring
      kbMan.on('indexing', (s) => setKbState(p => ({ ...p, indexingCurrent: s.current, indexingTotal: s.total, error: '' })));
      kbMan.on('ready', (s) => {
        vecSearch.load(kbMan.getChunks());
        setKbState(p => ({ ...p, indexedFileCount: s.fileCount, indexingCurrent: 0, indexingTotal: 0 }));
      });
      kbMan.on('error', (s) => setKbState(p => ({ ...p, error: s.message, indexingCurrent: 0, indexingTotal: 0 })));

      if (kbFolder) kbMan.startWatching(kbFolder);

      // Sugg Wiring
      suggMan.on('suggestion', (c) => {
         setSuggestions(suggMan.getSuggestions());
         sessMan.addSuggestion(c);
      });
      suggMan.on('thinking', setIsThinking);

      // Core Wiring
      audioCap.on('audioChunk', (chunk, speaker) => wsMan.sendAudioChunk(chunk, speaker));
      wsMan.on('transcript', (seg) => {
        setSegments(prev => [...prev, seg]);
        sessMan.addSegment(seg);
      });
      wsMan.on('stateChange', setWsState);
      
      // Session Wiring
      sessMan.on('saved', (ev) => setSaveToast({ folder: ev.folderPath }));

      servicesRef.current = { audioCap, wsMan, kbMan, vecSearch, gemService, suggMan, sessMan };
    };

    initServices();

    return () => {
      unmounted = true;
      if (servicesRef.current) {
        servicesRef.current.audioCap.stop();
        servicesRef.current.wsMan.disconnect();
        servicesRef.current.kbMan.stopWatching();
        servicesRef.current.sessMan.stop();
      }
    };
  }, []);

  const handleToggleLive = async () => {
    if (!servicesRef.current) return;
    const { audioCap, wsMan, sessMan } = servicesRef.current;

    if (isLive) {
      audioCap.stop();
      wsMan.disconnect();
      await sessMan.endSession();
      setIsLive(false);
    } else {
      setSegments([]);
      setSuggestions([]);
      const urlToConnect = settings.gcpWebSocketUrl || 'ws://localhost:8000';
      wsMan.connect(urlToConnect);
      sessMan.start();
      await audioCap.start();
      setIsLive(true);
    }
  };

  const handleDismissSuggestion = (id: string) => {
    if (servicesRef.current) {
      servicesRef.current.suggMan.dismiss(id);
      setSuggestions(servicesRef.current.suggMan.getSuggestions());
    }
  };

  const handleSaveSettings = async (newSettings: AppSettings) => {
    if (window.electronAPI) {
      await window.electronAPI.setCredential('WS_URL', newSettings.gcpWebSocketUrl);
      await window.electronAPI.setCredential('REST_URL', newSettings.gcpRestUrl);
      await window.electronAPI.setCredential('GEMINI_API_KEY', newSettings.geminiApiKey);
      await window.electronAPI.setCredential('KB_FOLDER', newSettings.kbFolderPath);
    }
    
    if (servicesRef.current) {
      servicesRef.current.kbMan.setRestUrl(newSettings.gcpRestUrl);
      if (newSettings.kbFolderPath !== settings.kbFolderPath) {
        await servicesRef.current.kbMan.startWatching(newSettings.kbFolderPath);
      }
    }
    setSettings(newSettings);
  };

  if (!hasAcceptedConsent) {
    return <ConsentScreen onAccept={() => setHasAcceptedConsent(true)} />;
  }

  return (
    <div className="h-screen w-full flex flex-col relative">
      <StatusBar 
        version={version} 
        isLive={isLive} 
        wsState={wsState} 
        onToggleLive={handleToggleLive} 
      />
      <MainWindow 
        suggestions={suggestions} 
        segments={segments} 
        isThinking={isThinking} 
        onDismissSuggestion={handleDismissSuggestion} 
      />
      {saveToast && (
        <div className="absolute bottom-6 left-1/2 -translate-x-1/2 bg-blue-600 shadow-md text-white px-4 py-2 rounded-full text-xs animate-slide-down">
          Session saved to {saveToast.folder}
        </div>
      )}
      {showSettings && (
        <SettingsPanel 
          initialSettings={settings} 
          onSave={handleSaveSettings} 
          onClose={() => setShowSettings(false)} 
        />
      )}
      
      {/* Mini KB Status injected for user insight if indexed/indexing */}
      <div className="absolute bottom-2 right-2 text-xs text-gray-500 max-w-xs text-right">
         {kbState.indexingCurrent > 0 ? (
           <span className="text-blue-400">Indexing {kbState.indexingCurrent}/{kbState.indexingTotal}...</span>
         ) : kbState.error ? (
           <span className="text-red-400">{kbState.error}</span>
         ) : (
           <span>{kbState.indexedFileCount} notes loaded</span>
         )}
      </div>
    </div>
  );
}

export default App;
