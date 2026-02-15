import { Global, Module } from '@nestjs/common';
import { DrizzleService } from './drizzle.service';

/**
 * Drizzle 数据库模块
 * 全局模块，提供数据库连接服务
 */
@Global()
@Module({
  providers: [DrizzleService],
  exports: [DrizzleService],
})
export class DrizzleModule {}
