import React, { useEffect, useRef } from 'react';
import { TranscriptSegment } from '../types';

interface Props {
  segments: TranscriptSegment[];
}

const TranscriptPanel: React.FC<Props> = ({ segments }) => {
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  
  // Use a ref for isUserScrolling to avoid re-render loops triggering endless scroll fights
  const isUserScrolling = useRef(false);

  const handleScroll = () => {
    if (!scrollContainerRef.current) return;
    const { scrollTop, scrollHeight, clientHeight } = scrollContainerRef.current;
    const isAtBottom = scrollHeight - scrollTop - clientHeight < 10;
    
    // If user scrolled up, pause auto-scroll. If they hit bottom, resume.
    isUserScrolling.current = !isAtBottom;
  };

  useEffect(() => {
    if (!isUserScrolling.current) {
      bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [segments]); // trigger on segments array change

  const formatTime = (ms: number) => {
    const d = new Date(ms);
    return d.toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
  };

  if (segments.length === 0) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-center">
        <div className="w-12 h-12 mb-3 bg-[#1a2a3a] rounded-full flex items-center justify-center">
          <span className="text-xl">💬</span>
        </div>
        <p className="text-sm text-gray-500 tracking-wide">Waiting for conversation...</p>
      </div>
    );
  }

  return (
    <div 
      className="h-full overflow-y-auto px-5 py-4 space-y-4" 
      ref={scrollContainerRef}
      onScroll={handleScroll}
    >
      {segments.map((seg, i) => {
        const isYou = seg.speaker === 'you';
        return (
          <div key={i} className={`flex flex-col ${isYou ? 'items-end' : 'items-start'}`}>
            <div className={`flex items-baseline gap-2 mb-1 px-1`}>
              <span className={`text-[10px] font-bold tracking-wider uppercase ${isYou ? 'text-blue-400' : 'text-green-400'}`}>
                {isYou ? 'You:' : 'Them:'}
              </span>
              <span className="text-[10px] text-gray-600 font-mono">{formatTime(seg.timestamp)}</span>
            </div>
            
            <div 
              className={`max-w-[85%] text-[13px] px-3.5 py-2 rounded-2xl break-words shadow-sm leading-relaxed ${
                isYou 
                  ? 'bg-blue-600/20 border border-blue-500/20 text-blue-50 rounded-tr-sm' 
                  : 'bg-green-600/10 border border-green-500/20 text-gray-100 rounded-tl-sm'
              }`}
            >
              {seg.text}
            </div>
          </div>
        );
      })}
      <div ref={bottomRef} className="h-2" />
    </div>
  );
};

export default TranscriptPanel;
