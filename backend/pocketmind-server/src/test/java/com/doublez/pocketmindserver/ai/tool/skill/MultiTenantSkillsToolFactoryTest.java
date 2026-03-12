package com.doublez.pocketmindserver.ai.tool.skill;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.ai.tool.ToolCallback;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 多租户 SkillsTool 工厂测试。
 */
class MultiTenantSkillsToolFactoryTest {

    private final MultiTenantSkillsToolFactory factory = new MultiTenantSkillsToolFactory();

    @TempDir
    Path tempDir;

    @Test
    void shouldBuildSkillCallbackFromSharedTenantAndAgentDirectories() throws IOException {
        Path sharedRoot = tempDir.resolve("shared-skills");
        Path tenantSharedRoot = tempDir.resolve("tenants").resolve("user-1").resolve("skills");
        Path tenantAgentRoot = tempDir.resolve("tenants").resolve("user-1").resolve("agents").resolve("claude").resolve("skills");
        writeSkill(sharedRoot.resolve("shared").resolve("SKILL.md"), "shared-skill", "shared-desc", "共享技能正文");
        writeSkill(tenantSharedRoot.resolve("tenant-shared").resolve("SKILL.md"), "tenant-shared-skill", "tenant-shared-desc", "租户共享技能正文");
        writeSkill(tenantAgentRoot.resolve("tenant-agent").resolve("SKILL.md"), "tenant-agent-skill", "tenant-agent-desc", "租户 agent 技能正文");

        MultiTenantSkillsToolFactory.ResolvedSkillTool resolved = factory.resolve(
                sharedRoot.toString(),
                tempDir.resolve("tenants").toString(),
                "user-1",
                "claude"
        );
        Optional<ToolCallback> callback = resolved.callback();

        assertTrue(callback.isPresent());
        assertEquals(3, resolved.directories().size());
        String description = callback.get().getToolDefinition().description();
        assertTrue(description.contains("shared-skill"));
        assertTrue(description.contains("tenant-shared-skill"));
        assertTrue(description.contains("tenant-agent-skill"));
    }

    @Test
    void shouldReturnEmptyWhenNoSkillDirectoryExists() {
        Optional<ToolCallback> callback = factory.build(
                tempDir.resolve("missing-shared").toString(),
                tempDir.resolve("missing-tenants").toString(),
                "user-2",
                "claude"
        );

        assertFalse(callback.isPresent());
    }

    @Test
    void shouldNotFailWhenSkillFrontMatterIsInvalid() throws IOException {
        Path sharedRoot = tempDir.resolve("shared-skills");
        Path brokenSkill = sharedRoot.resolve("broken").resolve("SKILL.md");
        Files.createDirectories(brokenSkill.getParent());
        // 缺少 description，触发第三方 SkillsTool 的元数据解析异常。
        Files.writeString(brokenSkill, "---\nname: broken-skill\n---\n\ninvalid meta");

        MultiTenantSkillsToolFactory.ResolvedSkillTool resolved = factory.resolve(
                sharedRoot.toString(),
                tempDir.resolve("tenants").toString(),
                "user-1",
                "claude"
        );

        assertEquals(1, resolved.directories().size());
        assertNotNull(resolved.callback());
    }

    private void writeSkill(Path file, String name, String description, String body) throws IOException {
        Files.createDirectories(file.getParent());
        Files.writeString(file, "---\nname: " + name + "\ndescription: " + description + "\n---\n\n" + body);
    }
}