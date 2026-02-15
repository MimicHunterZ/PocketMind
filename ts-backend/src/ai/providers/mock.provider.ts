import { Injectable } from '@nestjs/common';
import {
  IAiProvider,
  AiRequest,
  AiResponse,
} from '../interfaces/ai-provider.interface';

@Injectable()
export class MockAiProvider implements IAiProvider {
  getId(): string {
    return 'mock';
  }

  async generate(request: AiRequest): Promise<AiResponse> {
    const start = Date.now();
    // Simulate network delay
    await new Promise((resolve) => setTimeout(resolve, 500));

    return {
      content: `[Mock AI Response] Analysed: ${request.userPrompt}`,
      usage: {
        promptTokens: request.userPrompt.length,
        completionTokens: 10,
        totalTokens: request.userPrompt.length + 10,
      },
      latencyMs: Date.now() - start,
      provider: 'mock',
      model: 'mock-v1', // Default mock model
    };
  }
}
