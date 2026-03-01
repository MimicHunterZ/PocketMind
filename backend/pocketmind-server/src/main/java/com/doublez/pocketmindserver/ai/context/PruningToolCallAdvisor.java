package com.doublez.pocketmindserver.ai.context;

import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.client.advisor.ToolCallAdvisor;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.MessageType;
import org.springframework.ai.chat.messages.ToolResponseMessage;
import org.springframework.ai.model.tool.ToolExecutionResult;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.ai.tokenizer.JTokkitTokenCountEstimator;
import org.springframework.ai.tokenizer.TokenCountEstimator;
import org.springframework.core.Ordered;

import java.util.ArrayList;
import java.util.List;

/**
 * 工具调用上下文剪枝版 ToolCallAdvisor。
 * 当上下文过长时，优先丢弃“早期工具结果（TOOL 消息）”
 * 注意：OpenAI 兼容协议要求：assistant(tool_calls) 后必须紧跟每个 tool_call_id 的 TOOL 响应。
 * 因此这里按「tool-call 块」成组剪枝：assistant(tool_calls) + 紧随其后的连续 TOOL messages 视为一个块。
 */
@Slf4j
public class PruningToolCallAdvisor extends ToolCallAdvisor {

    private final double startRatio;
    private final int keepRecentToolResponses;
    private final TrustedModelContextWindowResolver contextWindowResolver;
    private final String modelName;
    private final TokenCountEstimator tokenCountEstimator;

    public PruningToolCallAdvisor(ToolCallingManager toolCallingManager,
                                 double startRatio,
                                 int keepRecentToolResponses,
                                 TrustedModelContextWindowResolver contextWindowResolver,
                                 String modelName) {
        super(toolCallingManager, Ordered.HIGHEST_PRECEDENCE + 300);
        this.startRatio = startRatio;
        this.keepRecentToolResponses = Math.max(0, keepRecentToolResponses);
        this.contextWindowResolver = contextWindowResolver;
        this.modelName = modelName;
        this.tokenCountEstimator = new JTokkitTokenCountEstimator();
    }

    @Override
    protected @NotNull List<Message> doGetNextInstructionsForToolCall(
            @NotNull ChatClientRequest chatClientRequest,
            @NotNull ChatClientResponse chatClientResponse,
            ToolExecutionResult toolExecutionResult) {
        List<Message> fullHistory = toolExecutionResult.conversationHistory();
        if (fullHistory.isEmpty()) {
            return fullHistory;
        }

        int windowTokens = contextWindowResolver.resolveWindowTokens(modelName);
        int estimatedTokens = estimateTokens(fullHistory);
        double ratio = windowTokens <= 0 ? 1.0 : (double) estimatedTokens / windowTokens;

        log.debug("PruningToolCallAdvisor - estimatedTokens={}, windowTokens={}, ratio={}, startRatio={}, keepRecentToolResponses={}",
                estimatedTokens,
                windowTokens,
                String.format("%.6f", ratio),
                String.format("%.6f", startRatio),
                keepRecentToolResponses);

        if (ratio < startRatio) {
            return fullHistory;
        }

        List<Message> pruned = pruneToolCallBlocks(fullHistory);
        log.debug("PruningToolCallAdvisor - pruned history: {} -> {}, toolMessages: {} -> {}",
                fullHistory.size(),
                pruned.size(),
                countToolMessages(fullHistory),
                countToolMessages(pruned));
        return pruned;
    }

    private List<Message> pruneToolCallBlocks(List<Message> history) {
        List<ToolCallBlock> blocks = findToolCallBlocks(history);
        if (blocks.isEmpty()) {
            return history;
        }

        int keepBlocks = Math.max(1, keepRecentToolResponses);
        if (blocks.size() <= keepBlocks) {
            return history;
        }

        int dropBlocks = blocks.size() - keepBlocks;
        boolean[] keep = new boolean[history.size()];
        for (int i = 0; i < keep.length; i++) {
            keep[i] = true;
        }

        for (int i = 0; i < dropBlocks; i++) {
            ToolCallBlock block = blocks.get(i);
            for (int idx = block.startIndex; idx <= block.endIndex && idx < keep.length; idx++) {
                if (idx >= 0) {
                    keep[idx] = false;
                }
            }
        }

        List<Message> pruned = new ArrayList<>(history.size());
        for (int i = 0; i < history.size(); i++) {
            if (keep[i]) {
                pruned.add(history.get(i));
            }
        }
        return pruned;
    }

    private List<ToolCallBlock> findToolCallBlocks(List<Message> history) {
        List<ToolCallBlock> blocks = new ArrayList<>();

        for (int i = 0; i < history.size(); i++) {
            Message msg = history.get(i);
            if (msg.getMessageType() != MessageType.TOOL) {
                continue;
            }

            boolean isFirstToolInRun = (i == 0) || history.get(i - 1).getMessageType() != MessageType.TOOL;
            if (!isFirstToolInRun) {
                continue;
            }

            int start = i;
            if (i > 0 && history.get(i - 1).getMessageType() == MessageType.ASSISTANT) {
                start = i - 1;
            }

            int end = i;
            while (end + 1 < history.size() && history.get(end + 1).getMessageType() == MessageType.TOOL) {
                end++;
            }

            blocks.add(new ToolCallBlock(start, end));
            i = end;
        }

        return blocks;
    }

    private record ToolCallBlock(int startIndex, int endIndex) {
    }

    private int estimateTokens(List<Message> messages) {
        int tokens = 0;
        for (Message message : messages) {
            if (message instanceof ToolResponseMessage toolResponseMessage) {
                for (ToolResponseMessage.ToolResponse response : toolResponseMessage.getResponses()) {
                    tokens += tokenCountEstimator.estimate(response.responseData());
                }
                continue;
            }
            tokens += tokenCountEstimator.estimate(message.getText());
        }
        return tokens;
    }

    private int countToolMessages(List<Message> messages) {
        int count = 0;
        for (Message message : messages) {
            if (message.getMessageType() == MessageType.TOOL) {
                count++;
            }
        }
        return count;
    }
}
