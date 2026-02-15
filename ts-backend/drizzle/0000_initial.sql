-- AI 提供商配置表
CREATE TABLE IF NOT EXISTS ai_provider_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(100) NOT NULL UNIQUE,
  api_key VARCHAR(500) NOT NULL,
  base_url VARCHAR(500),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Token 审计日志表
CREATE TABLE IF NOT EXISTS token_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trace_id VARCHAR(100) NOT NULL,
  user_id VARCHAR(100) NOT NULL,
  provider VARCHAR(100) NOT NULL,
  model VARCHAR(100) NOT NULL,
  prompt_tokens INTEGER NOT NULL,
  completion_tokens INTEGER NOT NULL,
  total_tokens INTEGER NOT NULL,
  latency_ms INTEGER NOT NULL,
  status VARCHAR(20) NOT NULL,
  error_message VARCHAR(1000),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 为 token_audit_logs 创建索引
CREATE INDEX IF NOT EXISTS token_audit_logs_user_id_idx ON token_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS token_audit_logs_trace_id_idx ON token_audit_logs(trace_id);

-- AI 对话表
CREATE TABLE IF NOT EXISTS ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id VARCHAR(100) NOT NULL,
  title VARCHAR(500),
  messages JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
