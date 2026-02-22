-- ============================================================
-- PocketMind Database Schema v2
-- 公共列约定（每张业务表都有）：
--   id         BIGSERIAL PRIMARY KEY
--   uuid       UUID UNIQUE NOT NULL  （业务键，API 对外暴露）
--   user_id    BIGINT NOT NULL       （多租户隔离，FK → users.id）
--   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
--   updated_at BIGINT NOT NULL DEFAULT 0  （毫秒时间戳，LWW 冲突依据 & pull cursor）
--   is_deleted BOOLEAN NOT NULL DEFAULT FALSE
-- ============================================================

-- pgvector 扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- gen_random_uuid() 依赖 pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    uuid                UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          BIGINT        NOT NULL DEFAULT 0,
    is_deleted          BOOLEAN      NOT NULL DEFAULT FALSE
);


-- ============================================================
-- 1. notes（对齐客户端 Note 模型全部字段）
-- ============================================================
CREATE TABLE IF NOT EXISTS notes (
    id                  BIGSERIAL    PRIMARY KEY,
    uuid                UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id             BIGINT       NOT NULL,

    -- 用户自己写的内容
    title               TEXT,
    content             TEXT,

    -- 来源 URL（对应 note.url）
    source_url          TEXT,

    -- 分类（对应 note.categoryId，默认 1）
    category_id         BIGINT       NOT NULL DEFAULT 1,

    -- 创建时间（对应 note.time）
    note_time           TIMESTAMPTZ,

    -- 抓取/爬虫结果（对应 previewXxx 字段）
    preview_title       TEXT,
    preview_description TEXT,
    preview_content     TEXT,
    resource_status     VARCHAR(20)  NOT NULL DEFAULT 'NONE',
    -- NONE / PENDING / FETCHING / DONE / FAILED

    -- AI 分析（轮询模式）：总结
    summary             TEXT,

    -- 预留：持久记忆系统扩展（暂不实现）
    memory_path         TEXT,

    -- 公共列
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          BIGINT       NOT NULL DEFAULT 0,
    is_deleted          BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_notes_user_id        ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_user_updated   ON notes(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_user_uuid      ON notes(user_id, uuid);
-- 全文搜索索引（title + content + preview_content）
CREATE INDEX IF NOT EXISTS idx_notes_fts ON notes USING GIN (
    to_tsvector('simple',
        COALESCE(title, '') || ' ' ||
        COALESCE(content, '') || ' ' ||
        COALESCE(preview_title, '') || ' ' ||
        COALESCE(preview_content, ''))
);

-- ============================================================
-- 2. categories（笔记分类目录）
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
    id         BIGSERIAL    PRIMARY KEY,
    uuid       UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id    BIGINT       NOT NULL,
    name       VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at BIGINT       NOT NULL DEFAULT 0,
    is_deleted BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_user_updated ON categories(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_categories_user_uuid ON categories(user_id, uuid);
-- 软删除场景：仅约束未删除的 name 唯一
CREATE UNIQUE INDEX IF NOT EXISTS ux_categories_user_name_active
    ON categories(user_id, name)
    WHERE is_deleted = FALSE;

-- ============================================================
-- 3. tags（标签字典，可由用户或 AI 生成）
-- ============================================================
CREATE TABLE IF NOT EXISTS tags (
    id         BIGSERIAL    PRIMARY KEY,
    uuid       UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id    BIGINT       NOT NULL,
    name       VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at BIGINT       NOT NULL DEFAULT 0,
    is_deleted BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_tags_user ON tags(user_id);
CREATE INDEX IF NOT EXISTS idx_tags_user_updated ON tags(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tags_user_uuid ON tags(user_id, uuid);
-- 软删除场景：仅约束未删除的 name 唯一
CREATE UNIQUE INDEX IF NOT EXISTS ux_tags_user_name_active
    ON tags(user_id, name)
    WHERE is_deleted = FALSE;

-- ============================================================
-- 4. note_tag_relation（笔记-标签核心中间表）
-- ============================================================
CREATE TABLE IF NOT EXISTS note_tag_relation (
    note_uuid  UUID         NOT NULL,
    tag_id     BIGINT       NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (note_uuid, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_note_tag_relation_tag ON note_tag_relation(tag_id);

-- ============================================================
-- 5. note_attachments（图片/PDF/文件元数据）
-- ============================================================
CREATE TABLE IF NOT EXISTS note_attachments (
    id           BIGSERIAL   PRIMARY KEY,
    uuid         UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id      BIGINT      NOT NULL,
    note_uuid    UUID        NOT NULL,

    type         VARCHAR(20) NOT NULL,   -- 'image' | 'pdf' | 'file'
    mime         VARCHAR(100),
    -- storage_key 可能是本地相对路径(pocket_images/xxx.jpg)，也可能是 OSS key
    storage_key  TEXT        NOT NULL,
    storage_type VARCHAR(20) NOT NULL DEFAULT 'local',  -- 'local' | 'server' | 'oss'
    sha256       CHAR(64),        -- 内容去重，相同 hash 复用同一文件
    width        INT,             -- 图片宽（px）
    height       INT,             -- 图片高（px）
    source       VARCHAR(20) NOT NULL DEFAULT 'user',  -- 'user' | 'scrape'

    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   BIGINT      NOT NULL DEFAULT 0,
    is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_attachments_user_note  ON note_attachments(user_id, note_uuid);
CREATE INDEX IF NOT EXISTS idx_attachments_sha256     ON note_attachments(user_id, sha256);
CREATE INDEX IF NOT EXISTS idx_attachments_user_uuid  ON note_attachments(user_id, uuid);

-- 兼容旧库：为 note_attachments 添加图片资产子系统所需新列（幂等，可重复执行）
-- size：文件字节数，供前端展示和磁盘统计
ALTER TABLE note_attachments ADD COLUMN IF NOT EXISTS size             BIGINT NOT NULL DEFAULT 0;
-- original_file_name：上传时客户端提供的原始文件名
ALTER TABLE note_attachments ADD COLUMN IF NOT EXISTS original_file_name  TEXT;
-- note_uuid 改为允许 NULL（独立上传时先不绑定笔记）
ALTER TABLE note_attachments ALTER COLUMN note_uuid DROP NOT NULL;

-- ============================================================
-- 6. attachment_visions（图片 AI 识别结果，使图片内容可被文本检索）
-- ============================================================
CREATE TABLE IF NOT EXISTS attachment_visions (
    id               BIGSERIAL   PRIMARY KEY,
    uuid             UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT      NOT NULL,
    attachment_uuid  UUID        NOT NULL,   -- FK → note_attachments.uuid

    model            VARCHAR(100) NOT NULL,  -- 识别所用模型名（溯源）
    vision_text      TEXT        NOT NULL,   -- AI 图片描述，用于 FTS 检索
    prompt_used      TEXT,
    status           VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING/DONE/FAILED

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       BIGINT      NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_visions_attachment  ON attachment_visions(attachment_uuid);
CREATE INDEX IF NOT EXISTS idx_visions_user        ON attachment_visions(user_id, status);
-- 图片描述全文搜索
CREATE INDEX IF NOT EXISTS idx_visions_fts ON attachment_visions USING GIN (
    to_tsvector('simple', COALESCE(vision_text, ''))
);

-- ============================================================
-- 7. chat_sessions
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id               BIGSERIAL   PRIMARY KEY,
    uuid             UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT      NOT NULL,
    scope_note_uuid  UUID,                   -- 关联某条笔记，NULL = 全局会话
    title            TEXT,
    -- 预留：会话记忆快照（持久记忆系统，暂不实现）
    memory_snapshot  TEXT,

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       BIGINT      NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user          ON chat_sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_user_uuid     ON chat_sessions(user_id, uuid);
CREATE INDEX IF NOT EXISTS idx_sessions_scope_note    ON chat_sessions(user_id, scope_note_uuid);

-- ============================================================
-- 8. chat_messages
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
    id               BIGSERIAL   PRIMARY KEY,
    uuid             UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT      NOT NULL,
    session_uuid     UUID        NOT NULL,   -- FK → chat_sessions.uuid

    -- 链表结构：指向上一条消息的 uuid，NULL = 链头（第一条用户消息）
    parent_uuid      UUID,
    -- 消息类型：TEXT | TOOL_CALL | TOOL_RESULT
    message_type     VARCHAR(30) NOT NULL DEFAULT 'TEXT',

    role             VARCHAR(20) NOT NULL,   -- 'USER' | 'ASSISTANT' | 'SYSTEM' | 'TOOL_CALL' | 'TOOL_RESULT'
    content          TEXT        NOT NULL DEFAULT '',
    -- 消息中引用的附件（图片等），存 UUIDs 数组
    attachment_uuids UUID[]      NOT NULL DEFAULT '{}',

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       BIGINT      NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_messages_session_time  ON chat_messages(session_uuid, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_user_uuid     ON chat_messages(user_id, uuid);
CREATE INDEX IF NOT EXISTS idx_messages_parent        ON chat_messages(parent_uuid);

-- 兼容旧库：为已存在的 chat_messages 表添加新列（IF NOT EXISTS 保证幂等）
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS parent_uuid  UUID;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(30) NOT NULL DEFAULT 'TEXT';
-- content 列旧版为 NOT NULL 但无 DEFAULT，补充 DEFAULT 值（DDL 不可重复执行跳过）
CREATE INDEX IF NOT EXISTS idx_messages_parent ON chat_messages(parent_uuid);

-- ============================================================
-- 9. sync_change_log（后端增量 pull 使用，不存内容只存变更事件）
-- ============================================================
CREATE TABLE IF NOT EXISTS sync_change_log (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      BIGINT      NOT NULL,
    entity_type  VARCHAR(30) NOT NULL,   -- 'note'|'attachment'|'vision'|'chat_message'...
    entity_uuid  UUID        NOT NULL,
    op           VARCHAR(10) NOT NULL,   -- 'upsert' | 'delete'
    updated_at   BIGINT      NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sync_log_user_time  ON sync_change_log(user_id, updated_at DESC);
