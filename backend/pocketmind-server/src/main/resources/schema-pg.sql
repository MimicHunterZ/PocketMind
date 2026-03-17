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

    -- 同步版本号（服务端写入）
    server_version      BIGINT,

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
    id              BIGSERIAL    PRIMARY KEY,
    uuid            UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id         BIGINT       NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    icon_path       TEXT,

    -- 同步版本号（服务端写入）
    server_version  BIGINT,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      BIGINT       NOT NULL DEFAULT 0,
    is_deleted      BOOLEAN      NOT NULL DEFAULT FALSE
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
-- 5. assets（物理资产表：图片/PDF/视频/文件等任意格式）
-- ============================================================
CREATE TABLE IF NOT EXISTS assets (
    id               BIGSERIAL   PRIMARY KEY,
    uuid             UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT      NOT NULL,
    -- 归属笔记（允许为 NULL：上传中尚未绑定笔记）
    note_uuid        UUID,

    -- 格式分类：'image' | 'pdf' | 'video' | 'audio' | 'file'
    type             VARCHAR(20) NOT NULL,
    -- 来源：'user'（用户上传）| 'scrape'（爬虫抓取）| 'system_gen'（系统生成）
    source           VARCHAR(20) NOT NULL DEFAULT 'user',

    -- 物理属性
    mime             VARCHAR(100) NOT NULL,
    size             BIGINT       NOT NULL DEFAULT 0,
    file_name        TEXT,                   -- 上传时的原始文件名
    sha256           CHAR(64),               -- 内容指纹，存储层去重

    -- 存储路径
    storage_key      TEXT         NOT NULL,
    storage_type     VARCHAR(20)  NOT NULL DEFAULT 'local',  -- 'local' | 'server' | 'oss'

    -- 物理元数据（存放: {"width":1920,"height":1080,"duration_seconds":120,"page_count":50}）
    metadata         JSONB        NOT NULL DEFAULT '{}'::jsonb,
    -- 业务/排版元数据预留（存放: {"caption":"小猫","layout":"full-width"}）
    business_metadata JSONB       NOT NULL DEFAULT '{}'::jsonb,

    -- 画廊排序（0 = 无序/默认；同笔记下按 sort_order ASC 排列）
    sort_order        INTEGER      NOT NULL DEFAULT 0,

    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       BIGINT       NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_assets_user_note  ON assets(user_id, note_uuid);
CREATE INDEX IF NOT EXISTS idx_assets_sha256     ON assets(user_id, sha256);
CREATE INDEX IF NOT EXISTS idx_assets_user_uuid  ON assets(user_id, uuid);
CREATE INDEX IF NOT EXISTS idx_assets_type       ON assets(user_id, type);
CREATE INDEX IF NOT EXISTS idx_assets_note_order ON assets(note_uuid, sort_order ASC);

-- ============================================================
-- 6. asset_extractions（异步内容提取结果：AI描述/PDF全文/视频转录）
-- ============================================================
CREATE TABLE IF NOT EXISTS asset_extractions (
    id               BIGSERIAL   PRIMARY KEY,
    uuid             UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT      NOT NULL,
    asset_uuid       UUID        NOT NULL,   -- FK → assets.uuid
    note_uuid        UUID,                   -- 冗余，便于按笔记关联查询

    -- 提取方式：'vision'（AI图片描述）| 'ocr' | 'pdf_text' | 'transcript'（视频转录）
    content_type     VARCHAR(20) NOT NULL DEFAULT 'vision',
    -- 提取出的文本内容（PENDING/FAILED 允许为 NULL），用于全文检索和 AI RAG
    content          TEXT,
    -- 识别所用模型名（溯源）
    model            VARCHAR(100),
    status           VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING/DONE/FAILED

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       BIGINT      NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_extractions_asset   ON asset_extractions(asset_uuid);
CREATE INDEX IF NOT EXISTS idx_extractions_user    ON asset_extractions(user_id, status);
-- 提取内容全文搜索
CREATE INDEX IF NOT EXISTS idx_extractions_fts ON asset_extractions USING GIN (
    to_tsvector('simple', COALESCE(content, ''))
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

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       BIGINT      NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user          ON chat_sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_user_uuid     ON chat_sessions(user_id, uuid);
CREATE INDEX IF NOT EXISTS idx_sessions_scope_note    ON chat_sessions(user_id, scope_note_uuid);

-- ============================================================
-- 8. context_catalog（上下文统一目录索引）
-- ============================================================
CREATE TABLE IF NOT EXISTS context_catalog (
    id               BIGSERIAL    PRIMARY KEY,
    uuid             UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT,
    context_type     VARCHAR(20)  NOT NULL,
    sub_type         VARCHAR(50),
    uri              TEXT         NOT NULL UNIQUE,
    parent_uri       TEXT,
    name             TEXT,
    abstract_text    TEXT,           -- L0 摘要 (~100 token)
    layer            VARCHAR(20)  NOT NULL DEFAULT 'L2_DETAIL',
    status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    is_leaf          BOOLEAN      NOT NULL DEFAULT TRUE,
    active_count     BIGINT       NOT NULL DEFAULT 0,
    embedding        vector(1024),            -- pgvector 语义向量
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       BIGINT       NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_context_catalog_user_type ON context_catalog(user_id, context_type, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_context_catalog_parent    ON context_catalog(parent_uri);
CREATE INDEX IF NOT EXISTS idx_context_catalog_embedding ON context_catalog
    USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;


-- ============================================================
-- 10. resource_records（AI 可读资源记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS resource_records (
    id               BIGSERIAL    PRIMARY KEY,
    uuid             UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id          BIGINT       NOT NULL,
    source_type      VARCHAR(30)  NOT NULL,
    root_uri         TEXT         NOT NULL,
    title            TEXT,
    abstract_text    TEXT,           -- L0 摘要 (~100 token)
    summary_text     TEXT,           -- L1 结构化概览 (~2k token)
    content          TEXT,           -- L2 完整正文
    source_url       TEXT,
    note_uuid        UUID,
    session_uuid     UUID,
    asset_uuid       UUID,
    status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       BIGINT       NOT NULL DEFAULT 0,
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_resource_records_user_source ON resource_records(user_id, source_type, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_resource_records_note_uuid   ON resource_records(note_uuid);
CREATE INDEX IF NOT EXISTS idx_resource_records_session     ON resource_records(session_uuid);
CREATE INDEX IF NOT EXISTS idx_resource_records_asset       ON resource_records(asset_uuid);

-- ============================================================
-- 11. memory_records（用户长期记忆记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_records (
    id                 BIGSERIAL    PRIMARY KEY,
    uuid               UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id            BIGINT       NOT NULL,
    tenant_id          BIGINT,
    space_type         VARCHAR(20)  NOT NULL DEFAULT 'USER',
    memory_type        VARCHAR(30)  NOT NULL,
    root_uri           TEXT         NOT NULL,
    title              TEXT,
    abstract_text      TEXT,           -- L0 摘要 (~100 token)
    summary_text       TEXT,           -- L1 结构化概览 (~2k token)
    content            TEXT,           -- L2 完整内容
    source_context_uri TEXT,
    evidence_refs      JSONB,          -- [{sourceUri, snippetRange, capturedAt}]
    merge_key          VARCHAR(128),   -- 去重合并键
    confidence_score   DECIMAL(5,4) NOT NULL DEFAULT 1.0,
    active_count       BIGINT       NOT NULL DEFAULT 0,
    last_validated_at  BIGINT,
    embedding          vector(1024),            -- pgvector 语义向量
    status             VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at         BIGINT       NOT NULL DEFAULT 0,
    is_deleted         BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_memory_records_user_type  ON memory_records(user_id, memory_type, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_memory_records_merge_key  ON memory_records(user_id, memory_type, merge_key);
CREATE INDEX IF NOT EXISTS idx_memory_records_space      ON memory_records(space_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_memory_records_embedding  ON memory_records
    USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;

-- ============================================================
-- 12. chat_messages
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
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE,
    -- 消息评分：1=点赞，0=未评价，-1=点踩
    rating           INT         NOT NULL DEFAULT 0,
    -- 分支别名：AI 自动生成的 4-8 字命名，仅命名分支叶节点有值
    branch_alias     VARCHAR(20)
);

CREATE INDEX IF NOT EXISTS idx_messages_session_time  ON chat_messages(session_uuid, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_user_uuid     ON chat_messages(user_id, uuid);
CREATE INDEX IF NOT EXISTS idx_messages_parent        ON chat_messages(parent_uuid);
-- 覆盖 findBySessionUuid 主查询路径：(user_id, session_uuid, is_deleted, created_at)
CREATE INDEX IF NOT EXISTS idx_messages_user_session   ON chat_messages(user_id, session_uuid, is_deleted, created_at ASC);

-- ============================================================
-- 13. sync_change_log（V3 同步架构：change_log.id 即 serverVersion 游标）
-- ============================================================
CREATE TABLE IF NOT EXISTS sync_change_log (
    id                   BIGSERIAL    PRIMARY KEY,  -- 服务端版本号，全局严格单调递增，即 serverVersion
    user_id              BIGINT       NOT NULL,
    entity_type          VARCHAR(30)  NOT NULL,     -- 'note' | 'category'
    entity_uuid          UUID         NOT NULL,
    operation            VARCHAR(8)   NOT NULL,     -- 'create' | 'update' | 'delete'
    updated_at           BIGINT       NOT NULL DEFAULT 0,  -- 业务实体 updatedAt 毫秒时间戳，LWW 裁决依据
    client_mutation_id   VARCHAR(36)  NULL UNIQUE,  -- Push 幂等键（UUID v4）；AI 后端触发时为 NULL
    payload              TEXT         NULL,         -- 实体完整 JSON 快照；delete 时为 NULL
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- (user_id, id) 复合索引：Pull 查询 WHERE user_id=? AND id > sinceVersion ORDER BY id 直接命中
CREATE INDEX IF NOT EXISTS idx_sync_log_user_version ON sync_change_log(user_id, id);
