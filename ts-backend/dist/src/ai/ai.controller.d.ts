import type { Request } from 'express';
import { AiService } from './ai.service';
import { GenerateTextDto } from './dto/generate-text.dto';
export declare class AiController {
    private readonly aiService;
    constructor(aiService: AiService);
    generate(dto: GenerateTextDto, req: Request): Promise<import("./interfaces/ai-provider.interface").AiResponse>;
}
