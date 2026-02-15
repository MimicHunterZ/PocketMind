import { IsNotEmpty, IsString, IsOptional, IsNumber } from 'class-validator';

export class GenerateTextDto {
  @IsString()
  @IsNotEmpty()
  userPrompt: string;

  @IsString()
  @IsOptional()
  systemPrompt?: string;

  @IsString()
  @IsOptional()
  model?: string;

  @IsNumber()
  @IsOptional()
  temperature?: number;

  @IsString()
  @IsOptional()
  provider?: string;
}
