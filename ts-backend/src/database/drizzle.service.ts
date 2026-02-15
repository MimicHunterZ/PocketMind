import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { drizzle, PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from '../database/schema';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Drizzle 数据库服务
 * 封装 Drizzle ORM 的数据库连接和操作
 */
@Injectable()
export class DrizzleService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DrizzleService.name);
  private client: postgres.Sql;
  public db: PostgresJsDatabase<typeof schema>;

  constructor(private configService: ConfigService) {}

  /**
   * 模块初始化时建立数据库连接
   */
  async onModuleInit() {
    try {
      const databaseUrl = this.configService.get<string>('DATABASE_URL');
      if (!databaseUrl) {
        throw new Error('DATABASE_URL 环境变量未配置');
      }

      this.logger.log('正在连接数据库...');

      // 创建 PostgreSQL 客户端 (使用 require 以避免模块导入问题)
      const pg = require('postgres');
      const postgresImpl = pg.default || pg;
      this.client = postgresImpl(databaseUrl, {
        max: 10, // 最大连接数
        idle_timeout: 20, // 空闲连接超时（秒）
        connect_timeout: 10, // 连接超时（秒）
      });

      // 初始化 Drizzle ORM
      this.db = drizzle(this.client, { schema });

      this.logger.log('数据库连接成功');

      // 执行数据库迁移
      await this.runMigrations();
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : JSON.stringify(error);
      this.logger.error(`数据库连接失败: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * 执行数据库迁移
   */
  private async runMigrations() {
    try {
      this.logger.log('开始执行数据库迁移...');

      const migrationPath = path.join(
        process.cwd(),
        'drizzle',
        '0000_initial.sql',
      );
      if (fs.existsSync(migrationPath)) {
        const migrationSql = fs.readFileSync(migrationPath, 'utf-8');
        await this.client.unsafe(migrationSql);
        this.logger.log('数据库迁移执行成功！');
      } else {
        this.logger.warn('迁移文件不存在，跳过迁移');
      }
    } catch (error) {
      // 如果表已存在，忽略错误
      const errorMessage =
        error instanceof Error ? error.message : JSON.stringify(error);
      if (errorMessage.includes('already exists')) {
        this.logger.log('数据库表已存在，跳过迁移');
      } else {
        this.logger.error(`数据库迁移失败： ${errorMessage}`);
        throw error;
      }
    }
  }

  /**
   * 模块销毁时关闭数据库连接
   */
  async onModuleDestroy() {
    try {
      if (this.client) {
        this.logger.log('正在关闭数据库连接...');
        await this.client.end();
        this.logger.log('数据库连接已关闭');
      }
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : JSON.stringify(error);
      this.logger.error(`关闭数据库连接失败: ${errorMessage}`);
    }
  }
}
