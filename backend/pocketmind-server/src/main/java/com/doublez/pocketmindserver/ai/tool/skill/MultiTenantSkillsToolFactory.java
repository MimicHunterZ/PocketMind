package com.doublez.pocketmindserver.ai.tool.skill;

import lombok.extern.slf4j.Slf4j;
import org.springaicommunity.agent.tools.SkillsTool;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

/**
 * 多租户技能工具工厂。
 *
 * 按 shared -> tenant shared -> tenant agent overlay 的顺序组装技能目录。
 */
@Slf4j
@Component
public class MultiTenantSkillsToolFactory {

    /**
     * 构建技能工具回调。
     */
    public Optional<ToolCallback> build(String sharedSkillsPath,
                                        String tenantSkillsBasePath,
                                        String tenantKey,
                                        String agentKey) {
        return resolve(sharedSkillsPath, tenantSkillsBasePath, tenantKey, agentKey).callback();
    }

    /**
     * 解析技能目录并按需要构建工具回调。
     */
    public ResolvedSkillTool resolve(String sharedSkillsPath,
                                     String tenantSkillsBasePath,
                                     String tenantKey,
                                     String agentKey) {
        String normalizedTenantKey = sanitizeSegment(tenantKey);
        String normalizedAgentKey = sanitizeSegment(agentKey);

        List<String> directories = new ArrayList<>();
        addIfDirectory(directories, sharedSkillsPath);
        addIfDirectory(directories, resolveTenantSharedPath(tenantSkillsBasePath, normalizedTenantKey));
        if (normalizedAgentKey != null) {
            addIfDirectory(directories, resolveTenantAgentPath(tenantSkillsBasePath, normalizedTenantKey, normalizedAgentKey));
        }

        if (directories.isEmpty()) {
            log.info("[skill] 未发现可用技能目录: sharedSkillsPath={}, tenantSkillsBasePath={}, tenantKey={}, agentKey={}",
                    sharedSkillsPath, tenantSkillsBasePath, normalizedTenantKey, normalizedAgentKey);
            return new ResolvedSkillTool(List.of(), Optional.empty());
        }

        ToolCallback callback = SkillsTool.builder()
                .addSkillsDirectories(directories)
                .build();
        log.info("[skill] 已解析技能目录: tenantKey={}, agentKey={}, directories={}",
                normalizedTenantKey, normalizedAgentKey, directories);
        return new ResolvedSkillTool(List.copyOf(directories), Optional.of(callback));
    }

    private void addIfDirectory(List<String> directories, String candidatePath) {
        if (candidatePath == null || candidatePath.isBlank()) {
            return;
        }
        Path path = Path.of(candidatePath).normalize();
        if (Files.isDirectory(path)) {
            directories.add(path.toString());
        }
    }

    private String resolveTenantSharedPath(String tenantSkillsBasePath, String tenantKey) {
        if (tenantSkillsBasePath == null || tenantSkillsBasePath.isBlank() || tenantKey == null) {
            return null;
        }
        return Path.of(tenantSkillsBasePath, tenantKey, "skills").toString();
    }

    private String resolveTenantAgentPath(String tenantSkillsBasePath, String tenantKey, String agentKey) {
        if (tenantSkillsBasePath == null || tenantSkillsBasePath.isBlank() || tenantKey == null || agentKey == null) {
            return null;
        }
        return Path.of(tenantSkillsBasePath, tenantKey, "agents", agentKey, "skills").toString();
    }

    private String sanitizeSegment(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String normalized = value.trim().replace('\\', '/');
        if (normalized.contains("..")) {
            throw new IllegalArgumentException("技能目录参数非法");
        }
        return normalized;
    }

    public record ResolvedSkillTool(List<String> directories, Optional<ToolCallback> callback) {
        public ResolvedSkillTool {
            directories = List.copyOf(Objects.requireNonNullElse(directories, List.of()));
            callback = Objects.requireNonNullElse(callback, Optional.empty());
        }
    }
}
