"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiConversations = exports.tokenAuditLogs = exports.aiProviderConfigs = void 0;
const pg_core_1 = require("drizzle-orm/pg-core");
const drizzle_orm_1 = require("drizzle-orm");
exports.aiProviderConfigs = (0, pg_core_1.pgTable)('ai_provider_configs', {
    id: (0, pg_core_1.varchar)('id', { length: 36 }).primaryKey().default((0, drizzle_orm_1.sql) `gen_random_uuid()::text`),
    provider: (0, pg_core_1.varchar)('provider', { length: 100 }).notNull().unique(),
    apiKey: (0, pg_core_1.varchar)('api_key', { length: 500 }).notNull(),
    baseUrl: (0, pg_core_1.varchar)('base_url', { length: 500 }),
    isActive: (0, pg_core_1.boolean)('is_active').notNull().default(true),
    createdAt: (0, pg_core_1.timestamp)('created_at').notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at').notNull().defaultNow(),
});
exports.tokenAuditLogs = (0, pg_core_1.pgTable)('token_audit_logs', {
    id: (0, pg_core_1.varchar)('id', { length: 36 }).primaryKey().default((0, drizzle_orm_1.sql) `gen_random_uuid()::text`),
    traceId: (0, pg_core_1.varchar)('trace_id', { length: 100 }).notNull(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 100 }).notNull(),
    provider: (0, pg_core_1.varchar)('provider', { length: 100 }).notNull(),
    model: (0, pg_core_1.varchar)('model', { length: 100 }).notNull(),
    promptTokens: (0, pg_core_1.integer)('prompt_tokens').notNull(),
    completionTokens: (0, pg_core_1.integer)('completion_tokens').notNull(),
    totalTokens: (0, pg_core_1.integer)('total_tokens').notNull(),
    latencyMs: (0, pg_core_1.integer)('latency_ms').notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 20 }).notNull(),
    errorMessage: (0, pg_core_1.varchar)('error_message', { length: 1000 }),
    createdAt: (0, pg_core_1.timestamp)('created_at').notNull().defaultNow(),
}, (table) => ({
    userIdIdx: (0, pg_core_1.index)('token_audit_logs_user_id_idx').on(table.userId),
    traceIdIdx: (0, pg_core_1.index)('token_audit_logs_trace_id_idx').on(table.traceId),
}));
exports.aiConversations = (0, pg_core_1.pgTable)('ai_conversations', {
    id: (0, pg_core_1.varchar)('id', { length: 36 }).primaryKey().default((0, drizzle_orm_1.sql) `gen_random_uuid()::text`),
    userId: (0, pg_core_1.varchar)('user_id', { length: 100 }).notNull(),
    title: (0, pg_core_1.varchar)('title', { length: 500 }),
    messages: (0, pg_core_1.json)('messages').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at').notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at').notNull().defaultNow(),
});
//# sourceMappingURL=schema.js.map