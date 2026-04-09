import React from 'react';
import { SuggestionCard as SuggestionCardType } from '../types';

interface Props {
  card?: SuggestionCardType;
  isThinking?: boolean;
  onDismiss?: (id: string) => void;
}

const SuggestionCard: React.FC<Props> = ({ card, isThinking, onDismiss }) => {
  if (isThinking) {
    return (
      <div className="bg-[#1a2a3a] border border-[rgba(255,255,255,0.08)] rounded-xl p-4 mb-3 animate-slide-down">
        <div className="flex flex-col gap-2 animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-3/4"></div>
          <div className="h-4 bg-gray-700 rounded w-1/2"></div>
        </div>
      </div>
    );
  }

  if (!card) return null;

  const dotColor = 
    card.confidence === 'high' ? 'bg-green-500 shadow-green-500/50' :
    card.confidence === 'medium' ? 'bg-yellow-500 shadow-yellow-500/50' : 'bg-red-500 shadow-red-500/50';

  const handleClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    onDismiss?.(card.id);
  };

  return (
    <div 
      onClick={handleClick}
      className="bg-[#1a2a3a] border border-[rgba(255,255,255,0.08)] rounded-xl p-4 mb-3 cursor-pointer hover:bg-[#1f3246] transition-colors animate-slide-down flex flex-col gap-2 relative shadow-sm"
    >
      <p className="text-sm text-white font-medium leading-relaxed max-w-[95%]">
        {card.text}
      </p>
      
      <div className="flex items-center gap-2 mt-1">
        <span className={`inline-block w-2 h-2 rounded-full shadow-sm ${dotColor}`} />
        <span className="text-xs text-gray-400 truncate opacity-80" title={card.sourceBreadcrumb}>
          {card.sourceFile}
        </span>
      </div>
      
      {/* Subtle dismiss affordance */}
      <span className="absolute top-2 right-2 text-gray-500 text-[10px] opacity-0 group-hover:opacity-100 transition-opacity">✕</span>
    </div>
  );
};

export default SuggestionCard;
