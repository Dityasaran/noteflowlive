import React from 'react';
import { AppSettings } from '../types';

interface Props {
  initialSettings: AppSettings;
  onSave: (settings: AppSettings) => Promise<void>;
  onClose: () => void;
}

const SettingsPanel: React.FC<Props> = ({ initialSettings, onSave, onClose }) => {
  const [settings, setSettings] = React.useState<AppSettings>(initialSettings);
  const [error, setError] = React.useState<string | null>(null);
  const [isSaving, setIsSaving] = React.useState(false);

  const handleChange = (key: keyof AppSettings, value: string) => {
    setSettings(prev => ({ ...prev, [key]: value }));
    setError(null);
  };

  const handlePickFolder = async () => {
    if (window.electronAPI) {
      const folder = await window.electronAPI.pickFolder();
      if (folder) handleChange('kbFolderPath', folder);
    }
  };

  const handleSaveClick = async () => {
    if (!settings.gcpWebSocketUrl.trim() || !settings.gcpRestUrl.trim()) {
      setError('GCP URLs cannot be empty.');
      return;
    }
    
    setIsSaving(true);
    await onSave(settings);
    setIsSaving(false);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-[9000]" style={{ backdropFilter: 'blur(4px)' }}>
      <div className="bg-[#1a2a3a] border border-[rgba(255,255,255,0.08)] rounded-xl w-80 p-5 shadow-2xl animate-slide-down flex flex-col">
        <div className="flex items-center justify-between mb-5 border-b border-[rgba(255,255,255,0.05)] pb-3">
          <h2 className="text-base font-bold text-white tracking-wide">Settings</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white text-lg">✕</button>
        </div>

        <div className="space-y-4 flex-1">
          {/* Form Fields */}
          {(
            [
              { label: 'GCP WebSocket URL', key: 'gcpWebSocketUrl' as const, placeholder: 'wss://…/ws/transcribe', type: 'text' },
              { label: 'GCP REST Base URL', key: 'gcpRestUrl' as const, placeholder: 'https://…', type: 'text' },
              { label: 'Gemini API Key', key: 'geminiApiKey' as const, placeholder: 'Password (AIza…)', type: 'password' },
            ]
          ).map(({ label, key, placeholder, type }) => (
            <div key={key}>
              <label className="text-xs font-semibold text-gray-300 block mb-1.5">{label}</label>
              <input
                type={type}
                className="w-full bg-[#0D1B2A] text-white text-[13px] rounded-md px-3 py-2 border border-gray-700/50 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none transition-colors"
                placeholder={placeholder}
                value={settings[key]}
                onChange={e => handleChange(key, e.target.value)}
              />
            </div>
          ))}

          {/* Folder Picker */}
          <div>
            <label className="text-xs font-semibold text-gray-300 block mb-1.5">Knowledge Base Folder</label>
            <div className="flex gap-2">
              <input
                type="text"
                className="flex-1 min-w-0 bg-[#0D1B2A] text-white text-[13px] rounded-md px-3 py-2 border border-gray-700/50 outline-none truncate"
                placeholder="Pick a folder…"
                value={settings.kbFolderPath}
                readOnly
              />
              <button
                onClick={handlePickFolder}
                className="px-3 py-2 bg-gray-700 hover:bg-gray-600 rounded-md text-[13px] text-white font-medium transition-colors whitespace-nowrap shadow-sm"
              >
                Browse
              </button>
            </div>
          </div>
          
          <button className="text-xs font-semibold text-gray-400 hover:text-white border border-gray-700 rounded-md px-3 py-1.5 w-full flex items-center justify-center gap-2 mt-2 transition-colors">
            <span>🔄</span> Re-index KB
          </button>
        </div>

        {error && <div className="mt-4 text-xs font-medium text-red-400 text-center bg-red-400/10 py-2 rounded-md">{error}</div>}

        <div className="mt-5 pt-4 border-t border-[rgba(255,255,255,0.05)]">
          <button
            onClick={handleSaveClick}
            disabled={isSaving}
            className="w-full py-2.5 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-sm font-bold transition-colors shadow-sm disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save Settings'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default SettingsPanel;
