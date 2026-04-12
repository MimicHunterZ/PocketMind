# 后端数据库设计规范

## 概述

PocketMind 后端使用 **PostgreSQL** 作为主数据库,本文档定义数据库设计的最佳实践。

## 技术栈

- **数据库**: PostgreSQL 15+
- **ORM**: MyBatis-Plus (与 Spring Boot 4.x 对齐)
- **连接池**: HikariCP
- **扩展**: pgvector (向量搜索)

## 命名规范

### 表命名

- **复数形式**: `notes`, `users`, `tags`
- **下划线分隔**: `chat_messages`, `resource_records`
- **避免缩写**: `categories` (不是 `cats`)

### 字段命名

- **下划线分隔**: `user_id`, `created_at`, `is_deleted`
- **布尔字段前缀 `is_`**: `is_deleted`, `is_public`
- **时间字段后缀 `_at`**: `created_at`, `updated_at`, `deleted_at`

### 索引命名

- **格式**: `idx_{table}_{columns}`
- **示例**: `idx_notes_user_id`, `idx_notes_user_id_created_at`

### 外键命名

- **格式**: `fk_{table}_{ref_table}`
- **示例**: `fk_notes_users`, `fk_note_tags_notes`

## 表结构设计

### 基础字段

**每个表必须包含**:

```sql
CREATE TABLE notes (
    -- 主键 (自增 ID)
    id BIGSERIAL PRIMARY KEY,
    
    -- UUID (用于跨系统引用和同步)
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    
    -- 业务字段
    user_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    
    -- 时间戳 (使用 TIMESTAMPTZ 包含时区信息)
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- 逻辑删除
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 乐观锁 (可选)
    version INTEGER NOT NULL DEFAULT 0
);
```

### 索引设计

#### 单列索引

```sql
-- 外键字段
CREATE INDEX idx_notes_user_id ON notes(user_id);

-- 查询条件字段
CREATE INDEX idx_notes_created_at ON notes(created_at);

-- 唯一索引
CREATE UNIQUE INDEX idx_notes_uuid ON notes(uuid);
```

#### 组合索引

```sql
-- 联合查询字段 (注意顺序: 过滤性强的字段在前)
CREATE INDEX idx_notes_user_id_created_at ON notes(user_id, created_at DESC);

-- 覆盖索引 (包含查询的所有字段)
CREATE INDEX idx_notes_user_id_title ON notes(user_id, is_deleted) INCLUDE (title, created_at);
```

#### 部分索引

```sql
-- 只索引未删除的记录
CREATE INDEX idx_notes_active ON notes(user_id, created_at) WHERE is_deleted = FALSE;

-- 只索引特定状态
CREATE INDEX idx_notes_published ON notes(created_at) WHERE status = 'PUBLISHED';
```

#### 全文索引

```sql
-- 全文搜索
CREATE INDEX idx_notes_title_fts ON notes USING GIN (to_tsvector('chinese', title));
CREATE INDEX idx_notes_content_fts ON notes USING GIN (to_tsvector('chinese', content));

-- 查询
SELECT * FROM notes
WHERE to_tsvector('chinese', title || ' ' || content) @@ to_tsquery('chinese', '搜索词');
```

#### 向量索引 (pgvector)

```sql
-- 安装 pgvector 扩展
CREATE EXTENSION vector;

-- 添加向量字段
ALTER TABLE notes ADD COLUMN embedding vector(1536);

-- 创建向量索引 (HNSW 算法)
CREATE INDEX idx_notes_embedding ON notes USING hnsw (embedding vector_cosine_ops);

-- 向量搜索
SELECT *, 1 - (embedding <=> '[0.1, 0.2, ...]'::vector) AS similarity
FROM notes
WHERE user_id = 1
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 10;
```

### 关系设计

#### 一对多关系

```sql
-- 用户 → 笔记 (一对多)
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 外键索引
CREATE INDEX idx_notes_user_id ON notes(user_id);
```

#### 多对多关系

```sql
-- 笔记 ↔ 标签 (多对多)
CREATE TABLE tags (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    user_id BIGINT NOT NULL,
    UNIQUE(user_id, name)
);

-- 关联表
CREATE TABLE note_tags (
    note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (note_id, tag_id)
);

-- 索引
CREATE INDEX idx_note_tags_tag_id ON note_tags(tag_id);
```

#### 自引用关系

```sql
-- 分类树结构
CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id BIGINT REFERENCES categories(id),
    user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);
```

## JSONB 字段使用

### 适用场景

- ✅ 非结构化数据 (如元数据、配置)
- ✅ 变化频繁的字段
- ✅ 不需要关系约束的数据

### 示例

```sql
CREATE TABLE assets (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE,
    file_path VARCHAR(500) NOT NULL,
    
    -- JSONB 存储元数据
    metadata JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- JSONB 索引
CREATE INDEX idx_assets_metadata ON assets USING GIN (metadata);

-- 插入数据
INSERT INTO assets (uuid, file_path, metadata) VALUES (
    gen_random_uuid(),
    '/uploads/image.jpg',
    '{"width": 1920, "height": 1080, "size": 102400, "mime_type": "image/jpeg"}'::jsonb
);

-- 查询 JSONB
SELECT * FROM assets WHERE metadata->>'mime_type' = 'image/jpeg';
SELECT * FROM assets WHERE (metadata->>'size')::int > 100000;
SELECT * FROM assets WHERE metadata @> '{"mime_type": "image/jpeg"}';
```

## 逻辑删除

### 标准实现

```sql
CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    -- ... 其他字段
    
    -- 逻辑删除字段
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 部分索引 (只索引未删除记录)
CREATE INDEX idx_notes_active ON notes(user_id, created_at) WHERE is_deleted = FALSE;
```

### MyBatis-Plus 配置

```yaml
mybatis-plus:
  global-config:
    db-config:
      logic-delete-field: isDeleted
      logic-delete-value: true
      logic-not-delete-value: false
```

### 触发器自动更新 deleted_at

```sql
CREATE OR REPLACE FUNCTION update_deleted_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        NEW.deleted_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notes_deleted_at
BEFORE UPDATE ON notes
FOR EACH ROW
EXECUTE FUNCTION update_deleted_at();
```

## 时间戳自动更新

### 触发器实现

```sql
-- 创建通用更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为表添加触发器
CREATE TRIGGER trigger_notes_updated_at
BEFORE UPDATE ON notes
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();
```

### MyBatis-Plus 自动填充

```java
@Component
public class MyMetaObjectHandler implements MetaObjectHandler {
    
    @Override
    public void insertFill(MetaObject metaObject) {
        this.strictInsertFill(metaObject, "createTime", Instant.class, Instant.now());
        this.strictInsertFill(metaObject, "updateTime", Instant.class, Instant.now());
    }
    
    @Override
    public void updateFill(MetaObject metaObject) {
        this.strictUpdateFill(metaObject, "updateTime", Instant.class, Instant.now());
    }
}
```

## 性能优化

### 1. 查询优化

#### EXPLAIN 分析

```sql
-- 分析查询计划
EXPLAIN ANALYZE
SELECT * FROM notes
WHERE user_id = 1 AND is_deleted = FALSE
ORDER BY created_at DESC
LIMIT 20;
```

#### 索引覆盖

```sql
-- ❌ 错误 - 回表查询
SELECT id, title, created_at FROM notes WHERE user_id = 1;

-- ✅ 正确 - 覆盖索引
CREATE INDEX idx_notes_user_id_covering ON notes(user_id) INCLUDE (title, created_at);
```

#### 避免 SELECT *

```sql
-- ❌ 错误
SELECT * FROM notes WHERE user_id = 1;

-- ✅ 正确
SELECT id, uuid, title, created_at FROM notes WHERE user_id = 1;
```

### 2. 批量操作

#### 批量插入

```sql
-- ❌ 错误 - 逐条插入
INSERT INTO notes (user_id, title) VALUES (1, '笔记1');
INSERT INTO notes (user_id, title) VALUES (1, '笔记2');
INSERT INTO notes (user_id, title) VALUES (1, '笔记3');

-- ✅ 正确 - 批量插入
INSERT INTO notes (user_id, title) VALUES
    (1, '笔记1'),
    (1, '笔记2'),
    (1, '笔记3');
```

#### MyBatis-Plus 批量保存

```java
// ✅ 正确 - 使用 saveBatch
noteService.saveBatch(notes, 1000);  // 每批 1000 条
```

### 3. 连接池配置

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
```

## 数据迁移

### Flyway 配置

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
```

### 迁移脚本示例

```sql
-- V1__init_schema.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- V2__add_notes_table.sql
CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_notes_user_id ON notes(user_id);

-- V3__add_tags_table.sql
CREATE TABLE tags (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

CREATE TABLE note_tags (
    note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (note_id, tag_id)
);

CREATE INDEX idx_note_tags_tag_id ON note_tags(tag_id);
```

## 备份与恢复

### 备份

```bash
# 全库备份
pg_dump -h localhost -U postgres -d pocketmind > backup.sql

# 备份特定表
pg_dump -h localhost -U postgres -d pocketmind -t notes -t tags > backup_notes_tags.sql

# 压缩备份
pg_dump -h localhost -U postgres -d pocketmind | gzip > backup.sql.gz
```

### 恢复

```bash
# 恢复备份
psql -h localhost -U postgres -d pocketmind < backup.sql

# 恢复压缩备份
gunzip -c backup.sql.gz | psql -h localhost -U postgres -d pocketmind
```

## 监控与调优

### 慢查询监控

```sql
-- 开启慢查询日志
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- 记录超过 1 秒的查询
SELECT pg_reload_conf();

-- 查看慢查询统计
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

### 索引使用情况

```sql
-- 查看未使用的索引
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE 'pg_toast_%';
```

### 表膨胀检查

```sql
-- 检查表膨胀
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_dead_tup
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- 清理表膨胀
VACUUM ANALYZE notes;
```

## 最佳实践

### 1. 主键选择

- ✅ 使用 `BIGSERIAL` 作为主键 (自增 ID)
- ✅ 添加 `UUID` 字段用于跨系统引用
- ❌ 避免使用业务字段作为主键

### 2. 时间字段

- ✅ 使用 `TIMESTAMPTZ` 存储时间 (包含时区)
- ✅ 时间字段后缀 `_at`
- ❌ 避免使用 `TIMESTAMP` (不带时区)

### 3. 枚举类型

```sql
-- 方式一: ENUM (类型安全,但修改困难)
CREATE TYPE note_status AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    status note_status NOT NULL DEFAULT 'DRAFT'
);

-- 方式二: VARCHAR + CHECK (灵活,易于扩展)
CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED'))
);
```

### 4. 外键约束

```sql
-- ✅ 正确 - 添加外键约束
CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL
);

-- 级联删除选项
-- ON DELETE CASCADE    : 删除父记录时,删除子记录
-- ON DELETE SET NULL   : 删除父记录时,子记录外键设为 NULL
-- ON DELETE RESTRICT   : 如果有子记录,禁止删除父记录
-- ON DELETE NO ACTION  : 同 RESTRICT
```

## 相关文档

- [后端分层架构](./layered-architecture.md)
- [DDD 架构规范](./ddd-architecture.md)
- [后端编码规约](../../conventions/backend-coding-standards.md)
