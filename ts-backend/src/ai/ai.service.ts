import { Injectable, Logger } from '@nestjs/common';
import { DrizzleService } from '../database/drizzle.service';
import { tokenAuditLogs } from '../database/schema';
import {
  IAiProvider,
  AiRequest,
  AiResponse,
} from './interfaces/ai-provider.interface';
import { MockAiProvider } from './providers/mock.provider';

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);
  private providers: Map<string, IAiProvider> = new Map();

  constructor(
    private drizzle: DrizzleService,
    private mockProvider: MockAiProvider,
  ) {
    this.registerProvider(mockProvider);
  }

  private registerProvider(provider: IAiProvider) {
    this.providers.set(provider.getId(), provider);
  }

  async generate(request: AiRequest, providerId = 'mock'): Promise<AiResponse> {
    const provider = this.providers.get(providerId);
    if (!provider) {
      throw new Error(`Provider ${providerId} not found`);
    }

    this.logger.log(
      `Processing AI request. traceId=${request.traceId}, provider=${providerId}`,
    );

    try {
      const response = await provider.generate(request);

      // Async Audit
      this.auditLog(request, response).catch((err: unknown) => {
        if (err instanceof Error) {
          this.logger.error(
            `Failed to write audit log: ${err.message}`,
            err.stack,
          );
        } else {
          this.logger.error(
            'Failed to write audit log: Unknown error',
            JSON.stringify(err),
          );
        }
      });

      return response;
    } catch (error: unknown) {
      let errorMessage: string;
      let errorStack: string | undefined;

      if (error instanceof Error) {
        errorMessage = error.message;
        errorStack = error.stack;
      } else {
        errorMessage = 'Unknown error';
        errorStack = JSON.stringify(error);
      }

      this.logger.error(`AI Generation failed: ${errorMessage}`, errorStack);

      // 记录失败审计日志
      this.drizzle.db
        .insert(tokenAuditLogs)
        .values({
          traceId: request.traceId,
          userId: request.userId,
          provider: providerId,
          model: request.model || 'unknown',
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0,
          latencyMs: 0,
          status: 'failed',
          errorMessage: errorMessage,
        } as any)
        .catch((err: unknown) => {
          const errMsg =
            err instanceof Error ? err.message : JSON.stringify(err);
          this.logger.error('Failed to log audit failure', errMsg);
        });

      throw error;
    }
  }

  private async auditLog(request: AiRequest, response: AiResponse) {
    await this.drizzle.db.insert(tokenAuditLogs).values({
      traceId: request.traceId,
      userId: request.userId,
      provider: response.provider,
      model: response.model,
      promptTokens: response.usage?.promptTokens || 0,
      completionTokens: response.usage?.completionTokens || 0,
      totalTokens: response.usage?.totalTokens || 0,
      latencyMs: response.latencyMs || 0,
      status: 'success',
      errorMessage: null,
    } as any);
  }
}
