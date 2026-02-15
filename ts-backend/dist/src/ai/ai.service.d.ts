import { DrizzleService } from '../database/drizzle.service';
import { AiRequest, AiResponse } from './interfaces/ai-provider.interface';
import { MockAiProvider } from './providers/mock.provider';
export declare class AiService {
    private drizzle;
    private mockProvider;
    private readonly logger;
    private providers;
    constructor(drizzle: DrizzleService, mockProvider: MockAiProvider);
    private registerProvider;
    generate(request: AiRequest, providerId?: string): Promise<AiResponse>;
    private auditLog;
}
