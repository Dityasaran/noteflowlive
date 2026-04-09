import React, { useState } from 'react';

interface ConsentScreenProps {
  onAccept: () => void;
}

const ConsentScreen: React.FC<ConsentScreenProps> = ({ onAccept }) => {
  const [agreed, setAgreed] = useState(false);

  const handleAccept = () => {
    if (agreed) {
      localStorage.setItem('hasAcceptedConsent', 'true');
      onAccept();
    }
  };

  return (
    <div className="fixed inset-0 flex flex-col items-center justify-center bg-[#0D1B2A] text-white z-[9999] px-8" style={{ border: 'none', outline: 'none' }}>
      
      {/* App Icon */}
      <div className="text-5xl mb-6">🎙️</div>
      
      {/* Title & Subtitle */}
      <h1 className="text-3xl font-bold mb-3 tracking-wide">Before you start recording</h1>
      <p className="text-sm text-gray-400 text-center max-w-sm mb-10 leading-relaxed">
        NoteFlow Live captures your microphone and desktop audio to synthesize real-time meeting insights.
      </p>

      {/* Info Sections */}
      <div className="space-y-6 w-full max-w-sm mb-10">
        <div className="flex gap-4">
          <div className="text-xl">🌍</div>
          <div>
            <p className="text-sm font-semibold text-white mb-0.5">Your responsibility</p>
            <p className="text-xs text-gray-400 leading-tight">You must obtain direct consent from all participants in accordance with local recording laws.</p>
          </div>
        </div>
        <div className="flex gap-4">
          <div className="text-xl">🔒</div>
          <div>
            <p className="text-sm font-semibold text-white mb-0.5">Your privacy</p>
            <p className="text-xs text-gray-400 leading-tight">Your audio never leaves your device — models execute locally or on your private GCP cluster.</p>
          </div>
        </div>
        <div className="flex gap-4">
          <div className="text-xl">💾</div>
          <div>
            <p className="text-sm font-semibold text-white mb-0.5">Your data</p>
            <p className="text-xs text-gray-400 leading-tight">Sessions are auto-saved strictly to your Documents/NoteFlow directory.</p>
          </div>
        </div>
      </div>

      {/* Consent Checkbox */}
      <div className="flex items-start gap-3 w-full max-w-sm mb-8 bg-[#1a2a3a] p-4 rounded-xl border border-[rgba(255,255,255,0.08)]">
        <input 
          type="checkbox" 
          id="consentCheckbox"
          checked={agreed}
          onChange={(e) => setAgreed(e.target.checked)}
          className="mt-0.5 cursor-pointer accent-blue-500 w-4 h-4 shrink-0"
        />
        <label htmlFor="consentCheckbox" className="text-xs text-gray-300 leading-snug cursor-pointer select-none">
          I understand and agree to obtain consent from all participants before recording.
        </label>
      </div>

      {/* Submit Button */}
      <button
        onClick={handleAccept}
        disabled={!agreed}
        className={`w-full max-w-sm py-3 rounded-lg text-sm font-bold transition-all ${
          agreed 
            ? 'bg-blue-600 hover:bg-blue-500 text-white cursor-pointer shadow-lg shadow-blue-500/20' 
            : 'bg-gray-700 text-gray-400 cursor-not-allowed opacity-60'
        }`}
      >
        Get Started
      </button>

    </div>
  );
};

export default ConsentScreen;
