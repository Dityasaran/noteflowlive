import React from 'react';
import SuggestionCard from './SuggestionCard';
import TranscriptPanel from './TranscriptPanel';
import { TranscriptSegment, SuggestionCard as SuggestionCardType } from '../types';

interface Props {
  suggestions: SuggestionCardType[];
  segments: TranscriptSegment[];
  isThinking: boolean;
  onDismissSuggestion: (id: string) => void;
}

const MainWindow: React.FC<Props> = ({ suggestions, segments, isThinking, onDismissSuggestion }) => {
  return (
    <div className="flex flex-col flex-1 h-full w-full overflow-hidden">
      
      {/* Top 40% - Suggestions Container */}
      <div className="h-[40%] bg-[#0D1B2A] p-4 overflow-y-auto">
        <div className="max-w-xl mx-auto flex flex-col justify-end min-h-full">
          {suggestions.length === 0 && !isThinking ? (
            <div className="flex-1 flex flex-col items-center justify-center mt-4">
              <span className="text-sm text-gray-500 tracking-wide font-medium">Listening for moments to help...</span>
            </div>
          ) : (
            <div className="flex flex-col-reverse justify-end">
              {/* Note: reversed so map ordering natively drops from top */}
              {isThinking && <SuggestionCard isThinking />}
              {suggestions.map((card) => (
                <SuggestionCard key={card.id} card={card} onDismiss={onDismissSuggestion} />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Divider */}
      <div className="h-[1px] bg-[rgba(255,255,255,0.08)] w-full shadow-[0_1px_4px_rgba(0,0,0,0.5)] z-10" />

      {/* Bottom 60% - Transcript */}
      <div className="h-[60%] bg-[#09131e] relative">
        <TranscriptPanel segments={segments} />
      </div>

    </div>
  );
};

export default MainWindow;
