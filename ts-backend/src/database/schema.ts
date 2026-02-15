import { pgTable, varchar, boolean, timestamp, integer, json, index } from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

/**
 * AI 提供商配置表
 * 存储不同 AI 提供商的配置信息（如 OpenAI, DeepSeek, DashScope 等）
 */
export const aiProviderConfigs = pgTable('ai_provider_configs', {
  id: varchar('id', { length: 36 }).primaryKey().default(sql`gen_random_uuid()::text`),
  provider: varchar('provider', { length: 100 }).notNull().unique(), // 提供商名称，例如 "openai", "deepseek", "dashscope"
  apiKey: varchar('api_key', { length: 500 }).notNull(), // API 密钥
  baseUrl: varchar('base_url', { length: 500 }), // 可选的基础 URL 覆盖
  isActive: boolean('is_active').notNull().default(true), // 是否启用该提供商
  createdAt: timestamp('created_at').notNull().defaultNow(), // 创建时间
  updatedAt: timestamp('updated_at').notNull().defaultNow(), // 更新时间
});

/**
 * Token 审计日志表
 * 记录所有 AI 请求的 token 使用情况和性能指标
 */
export const tokenAuditLogs = pgTable('token_audit_logs', {
  id: varchar('id', { length: 36 }).primaryKey().default(sql`gen_random_uuid()::text`),
  traceId: varchar('trace_id', { length: 100 }).notNull(), // 请求跟踪 ID
  userId: varchar('user_id', { length: 100 }).notNull(), // 触发请求的用户 ID
  provider: varchar('provider', { length: 100 }).notNull(), // 使用的提供商（例如 "openai"）
  model: varchar('model', { length: 100 }).notNull(), // 使用的具体模型（例如 "gpt-4"）
  promptTokens: integer('prompt_tokens').notNull(), // 提示词 token 数量
  completionTokens: integer('completion_tokens').notNull(), // 完成 token 数量
  totalTokens: integer('total_tokens').notNull(), // 总 token 数量
  latencyMs: integer('latency_ms').notNull(), // 请求延迟（毫秒）
  status: varchar('status', { length: 20 }).notNull(), // 请求状态："success" 或 "failed"
  errorMessage: varchar('error_message', { length: 1000 }), // 错误信息（如果失败）
  createdAt: timestamp('created_at').notNull().defaultNow(), // 创建时间
}, (table) => ({
  userIdIdx: index('token_audit_logs_user_id_idx').on(table.userId),
  traceIdIdx: index('token_audit_logs_trace_id_idx').on(table.traceId),
}));

/**
 * AI 对话表
 * 存储用户与 AI 的对话历史
 */
export const aiConversations = pgTable('ai_conversations', {
  id: varchar('id', { length: 36 }).primaryKey().default(sql`gen_random_uuid()::text`),
  userId: varchar('user_id', { length: 100 }).notNull(), // 用户 ID
  title: varchar('title', { length: 500 }), // 对话标题
  messages: json('messages').notNull(), // 消息数组（JSON 格式存储以保证灵活性）
  createdAt: timestamp('created_at').notNull().defaultNow(), // 创建时间
  updatedAt: timestamp('updated_at').notNull().defaultNow(), // 更新时间
});
