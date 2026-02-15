export interface AiGenerationUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface AiResponse {
  content: string;
  usage?: AiGenerationUsage;
  latencyMs?: number;
  provider: string;
  model: string;
}

export interface AiRequest {
  systemPrompt?: string;
  userPrompt: string;
  model?: string;
  temperature?: number;
  userId: string; // For auditing
  traceId: string; // For observability
}

export interface IAiProvider {
  getId(): string;
  generate(request: AiRequest): Promise<AiResponse>;
}
