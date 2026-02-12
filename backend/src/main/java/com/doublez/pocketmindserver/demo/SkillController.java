package com.doublez.pocketmindserver.demo;

import org.springaicommunity.agent.tools.FileSystemTools;
import org.springaicommunity.agent.tools.ShellTools;
import org.springaicommunity.agent.tools.SkillsTool;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/demo")
public class SkillController {
    private final ChatClient chatClient;

    public SkillController(ChatClient.Builder chatClientBuilder) {
        this.chatClient = chatClientBuilder
                .defaultToolCallbacks(SkillsTool.builder()
                        .addSkillsDirectory(".claude/skills")
                        .build())
                .defaultTools(FileSystemTools.builder().build())
                .defaultTools(ShellTools.builder().build())
                .defaultToolContext(Map.of("foo", "bar"))
                .build();
    }


    /**
     * 测试 skill 流程
     * @param message 用户的输入
     * @return
     */
    @GetMapping("/skill")
    public String chat(@RequestBody String message) {
        return chatClient.prompt()
                .user(message)
                .call()
                .content();
    }
}
