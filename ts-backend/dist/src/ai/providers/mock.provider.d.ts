import { IAiProvider, AiRequest, AiResponse } from '../interfaces/ai-provider.interface';
export declare class MockAiProvider implements IAiProvider {
    getId(): string;
    generate(request: AiRequest): Promise<AiResponse>;
}
