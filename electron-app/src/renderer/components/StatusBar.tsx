import React, { useEffect, useState } from 'react';
import { WSState } from '../services/WebSocketManager';

interface Props {
  version: string;
  isLive: boolean;
  wsState: WSState;
  onToggleLive: () => void;
}

const StatusBar: React.FC<Props> = ({ version, isLive, wsState, onToggleLive }) => {
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (isLive) {
      interval = setInterval(() => {
        setSeconds((s) => s + 1);
      }, 1000);
    } else {
      setSeconds(0);
    }
    return () => clearInterval(interval);
  }, [isLive]);

  const formatTime = (totalSeconds: number) => {
    const m = Math.floor(totalSeconds / 60).toString().padStart(2, '0');
    const s = (totalSeconds % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };

  const isDisconnectedAndMidSession = isLive && (wsState === 'disconnected' || wsState === 'reconnecting');

  return (
    <div className="flex flex-col relative z-50 shadow-md">
      {/* Main Status Bar */}
      <div 
        className="flex items-center justify-between px-4 h-12 bg-[#1a2a3a] border-b border-[rgba(255,255,255,0.08)] select-none"
        style={{ WebkitAppRegion: 'drag' } as any}
      >
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-white tracking-wide">NoteFlow</span>
          <span className="text-xs text-gray-500 font-mono mt-0.5">v{version}</span>
        </div>

        <div className="absolute left-1/2 -translate-x-1/2 text-sm text-gray-300 font-mono tracking-widest font-semibold">
          {isLive ? formatTime(seconds) : '00:00'}
        </div>

        <div className="flex items-center gap-4" style={{ WebkitAppRegion: 'no-drag' } as any}>
          {/* Connection Indicator */}
          <div className="flex items-center gap-1.5" title={`WebSocket State: ${wsState}`}>
            <span
              className={`inline-block w-2 h-2 rounded-full ${
                wsState === 'connected' ? 'bg-green-500' :
                wsState === 'connecting' || wsState === 'reconnecting' ? 'bg-yellow-500 animate-pulse' :
                'bg-red-500'
              }`}
            />
          </div>

          <button
            onClick={onToggleLive}
            className={`px-4 py-1.5 rounded-md text-xs font-bold transition-all cursor-pointer ${
              isLive
                ? 'bg-red-600 hover:bg-red-500 text-white shadow shadow-red-600/20'
                : 'bg-green-600 hover:bg-green-500 text-white shadow shadow-green-600/20'
            }`}
          >
            {isLive ? 'Stop' : 'Go Live'}
          </button>
        </div>
      </div>

      {/* Reconnecting Banner */}
      {isDisconnectedAndMidSession && (
        <div className="bg-yellow-600 text-white text-xs text-center py-1.5 shadow-sm font-semibold tracking-wide flex items-center justify-center gap-2 px-4 animate-slide-down">
          <span>⚠️</span> Connection lost — reconnecting...
        </div>
      )}
    </div>
  );
};

export default StatusBar;
