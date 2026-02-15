import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { MockAiProvider } from './providers/mock.provider';
import { DrizzleModule } from '../database/drizzle.module';

@Module({
  imports: [DrizzleModule],
  controllers: [AiController],
  providers: [AiService, MockAiProvider] as const,
  exports: [AiService],
})
export class AiModule {}
