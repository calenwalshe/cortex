export type GsdAction =
  | { type: 'init-project'; brief: string }
  | { type: 'plan'; phase: number }
  | { type: 'execute'; phase: number }
  | { type: 'verify'; phase: number }
  | { type: 'resume' }
  | { type: 'done' }
  | { type: 'error'; reason: string };

export interface ParsedState {
  currentPhase: number;
  totalPhases: number;
  plansInPhase: number;
  plansComplete: number;
  status: string;
}

export interface PhaseInfo {
  number: number;
  name: string;
  complete: boolean;
}

export interface TelegramConfig {
  botToken: string;
  chatId: number;
  gateTimeoutMs: number;      // default 4 hours
  heartbeatIntervalMs: number; // default 30 minutes
}

export interface StuckDetectorConfig {
  windowSize: number;
  threshold: number;
  readOnlyMultiplier: number;
}

export interface RunnerConfig {
  projectDir: string;
  projectBrief?: string;
  maxTurns: number;
  maxBudgetUsd: number;
  compactionThreshold: number;
  logLevel: string;
  stuckDetector: StuckDetectorConfig;
  telegram?: TelegramConfig;
}
