import { Controller, Post, Body, Req } from '@nestjs/common';
import type { Request } from 'express';
import { AiService } from './ai.service';
import { GenerateTextDto } from './dto/generate-text.dto';
import { v4 as uuidv4 } from 'uuid';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('generate')
  async generate(@Body() dto: GenerateTextDto, @Req() req: Request) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    const user = (req as any).user as { id?: string } | undefined;
    const userId = user?.id || 'anonymous';
    const traceId = (req.headers['x-trace-id'] as string) || uuidv4();

    return this.aiService.generate(
      {
        ...dto,
        userId,
        traceId,
      },
      dto.provider,
    );
  }
}
