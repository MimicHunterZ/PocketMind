package com.doublez.pocketmindserver.ai.tool.skill;

import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 租户技能解析器。
 *
 * 按用户租户范围解析共享技能与可选 agent overlay，返回请求级注入所需上下文。
 */
@Slf4j
@Component
public class TenantSkillToolResolver {

    private final MultiTenantSkillsToolFactory multiTenantSkillsToolFactory;
    private final String sharedSkillsPath;
    private final String tenantSkillsBasePath;

    public TenantSkillToolResolver(@Value("${pocketmind.ai.tools.skills-path:../.claude/skills}") String sharedSkillsPath,
                                   @Value("${pocketmind.ai.tools.tenant-skills-base-path:../.claude/tenants}") String tenantSkillsBasePath,
                                   MultiTenantSkillsToolFactory multiTenantSkillsToolFactory) {
        this.multiTenantSkillsToolFactory = multiTenantSkillsToolFactory;
        this.sharedSkillsPath = sharedSkillsPath;
        this.tenantSkillsBasePath = tenantSkillsBasePath;
    }

    /**
     * 为指定用户解析请求级技能工具。
     */
    public ResolvedTenantSkillTool resolveForUser(long userId, String agentKey) {
        String tenantKey = "user-" + userId;
        String normalizedAgentKey = normalizeAgentKey(agentKey);

        MultiTenantSkillsToolFactory.ResolvedSkillTool resolved = multiTenantSkillsToolFactory.resolve(
            sharedSkillsPath,
            tenantSkillsBasePath,
                tenantKey,
                normalizedAgentKey
        );

        Map<String, Object> toolContext = new LinkedHashMap<>();
        toolContext.put("tenantKey", tenantKey);
        toolContext.put("agentKey", normalizedAgentKey);
        toolContext.put("skillDirectories", resolved.directories());

        ToolCallback skillCallback = resolved.callback().orElse(null);
        if (skillCallback == null) {
            log.info("[skill] 未命中租户技能: tenantKey={}, agentKey={}", tenantKey, normalizedAgentKey);
        }
        return new ResolvedTenantSkillTool(tenantKey, normalizedAgentKey, skillCallback, Map.copyOf(toolContext));
    }

    private String normalizeAgentKey(String agentKey) {
        if (agentKey == null || agentKey.isBlank()) {
            return "shared";
        }
        return agentKey.trim();
    }

    public record ResolvedTenantSkillTool(String tenantKey,
                                          String agentKey,
                                          ToolCallback skillCallback,
                                          Map<String, Object> toolContext) {
    }
}
