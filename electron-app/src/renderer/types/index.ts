export interface TranscriptSegment {
  speaker: 'you' | 'them'
  text: string
  timestamp: number
}

export interface SuggestionCard {
  id: string
  text: string
  sourceFile: string
  sourceBreadcrumb: string
  confidence: 'high' | 'medium' | 'low'
  triggeredAt: Date
}

export interface ConversationState {
  topic: string
  summary: string
  openQuestions: string[]
  tensions: string[]
  recentDecisions: string[]
  goals: string[]
  confidence: 'high' | 'medium' | 'low'
}

export interface KBChunk {
  id: string
  filePath: string
  breadcrumb: string
  body: string
  embedding: number[]
  fileHash: string
}

export interface AppSettings {
  gcpWebSocketUrl: string
  gcpRestUrl: string
  geminiApiKey: string
  kbFolderPath: string
}
