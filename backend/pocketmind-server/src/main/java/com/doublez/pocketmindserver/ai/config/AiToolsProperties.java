package com.doublez.pocketmindserver.ai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * AI 工具配置（业务侧）。
 *
 * 说明：
 * - 这里参考 demo 注册 Skills/FileSystem/Shell 三类工具。
 * - 出于安全考虑默认关闭；仅在明确开启时才会把工具注册为 ToolCallback。
 */
@ConfigurationProperties(prefix = "pocketmind.ai.tools")
public record AiToolsProperties(
        boolean enabled,

        /**
         * skills 目录路径。
         *
         * 说明：默认从 backend 目录启动时，仓库根目录的 .claude/skills 在 ../.claude/skills。
         */
        String skillsPath,

        /**
         * 多租户 skills 根目录。
         *
         * <p>目录规范：</p>
         * <ul>
         *     <li>{tenantKey}/skills/** /SKILL.md</li>
         *     <li>{tenantKey}/agents/{agentKey}/skills/** /SKILL.md</li>
         * </ul>
         */
        String tenantSkillsBasePath
) {

    public AiToolsProperties {
        if (skillsPath == null || skillsPath.isBlank()) {
            skillsPath = "../.claude/skills";
        }
        if (tenantSkillsBasePath == null || tenantSkillsBasePath.isBlank()) {
            tenantSkillsBasePath = "../.claude/tenants";
        }
    }
}
