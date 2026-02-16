package com.doublez.pocketmindserver.demo;

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
import org.springframework.core.Ordered;
import org.springframework.ai.tokenizer.JTokkitTokenCountEstimator;
import org.springframework.ai.tokenizer.TokenCountEstimator;

import java.util.ArrayList;
import java.util.List;

/**
 * 工具调用上下文剪枝版 ToolCallAdvisor。
 *
 * 目标：当上下文过长时，优先丢弃“早期工具结果（TOOL 消息）”，避免 Tool Result 把 token 预算吃光。
 *
 * 说明：
 * - Spring AI 2.0.0-M2 的 ToolCallAdvisor 在每轮工具执行后，会产出 ToolExecutionResult.conversationHistory()。
 * - 这里覆写 doGetNextInstructionsForToolCall(...)，在进入下一轮 LLM 调用前对 history 做剪枝。
 * - 注意：不能“只剪 TOOL 消息”。OpenAI 兼容协议要求：assistant(tool_calls) 后必须紧跟每个 tool_call_id 的 TOOL 响应。
 *   所以这里按「tool-call 块」成组剪枝：assistant(tool_calls) + 紧随其后的连续 TOOL messages 视为一个块。
 *   只丢弃早期块，保留最近 keepRecentToolResponses 个块，其余 system/user/assistant（非 tool-call 块部分）保留。
 */
@Slf4j
public class PruningToolCallAdvisor extends ToolCallAdvisor {

    /**
     * 当估算占用率 >= startRatio 时触发剪枝。
        * 这里的占用率是“近似估算”：用 Spring AI 的 JTokkitTokenCountEstimator 估算 token，再除以窗口大小。
     */
    private final double startRatio;

    /**
    * 保留最近多少个「tool-call 块」。
    *
    * 一个块的定义：assistant(tool_calls) + 紧随其后的连续 TOOL messages。
    * 这样可以保证 tool_call_id 的响应不被拆开（否则会触发 OpenAI 兼容校验 400）。
     */
    private final int keepRecentToolResponses;
    private final TrustedModelContextWindowResolver contextWindowResolver;
    private final String modelName;
    private final TokenCountEstimator tokenCountEstimator;

    public PruningToolCallAdvisor(ToolCallingManager toolCallingManager,
                                 double startRatio,
                                 int keepRecentToolResponses,
                                 TrustedModelContextWindowResolver contextWindowResolver,
                                 String modelName) {
        // ToolCallAdvisor 对 advisor order 有断言：必须介于 HIGHEST_PRECEDENCE 和 LOWEST_PRECEDENCE 之间。
        // 这里用和默认 builder 接近的值，确保其能作为 recursive advisor 正常工作。
        super(toolCallingManager, Ordered.HIGHEST_PRECEDENCE + 300);
        this.startRatio = startRatio;
        this.keepRecentToolResponses = Math.max(0, keepRecentToolResponses);
        this.contextWindowResolver = contextWindowResolver;
        this.modelName = modelName;
        // Spring AI 官方提供的 token 估算器（基于 JTokkit，默认 CL100K_BASE）。
        this.tokenCountEstimator = new JTokkitTokenCountEstimator();
    }

    @Override
    protected @NotNull List<Message> doGetNextInstructionsForToolCall(
            @NotNull ChatClientRequest chatClientRequest,
            @NotNull ChatClientResponse chatClientResponse,
            ToolExecutionResult toolExecutionResult) {
        // ToolCallAdvisor 已经执行完工具调用，这里拿到“下一轮要喂给模型”的完整对话历史。
        List<Message> fullHistory = toolExecutionResult.conversationHistory();
        int toolMessageCount = countToolMessages(fullHistory);
        log.debug("PruningToolCallAdvisor - fullHistory size: {}, toolMessages: {}",
            fullHistory.size(),
            toolMessageCount);
        if (fullHistory.isEmpty()) {
            return fullHistory;
        }

        int windowTokens = contextWindowResolver.resolveWindowTokens(modelName);
        int estimatedTokens = estimateTokens(fullHistory);
        double ratio = windowTokens <= 0 ? 1.0 : (double) estimatedTokens / windowTokens;

        // 触发判断日志：定位“为什么没触发”。
        log.debug("PruningToolCallAdvisor - estimatedTokens={}, windowTokens={}, ratio={}, startRatio={}, keepRecentToolResponses={}",
            estimatedTokens,
            windowTokens,
            String.format("%.6f", ratio),
            String.format("%.6f", startRatio),
            keepRecentToolResponses);

        if (ratio < startRatio) {
            return fullHistory;
        }

        // 达到阈值后：按「tool-call 块」剪枝（assistant(tool_calls)+TOOL responses）。
        List<Message> pruned = pruneToolCallBlocks(fullHistory);
        log.debug("PruningToolCallAdvisor - pruned history: {} -> {}, toolMessages: {} -> {}",
            fullHistory.size(),
            pruned.size(),
            toolMessageCount,
            countToolMessages(pruned));
        return pruned;
    }

    private List<Message> pruneToolCallBlocks(List<Message> history) {
        List<ToolCallBlock> blocks = findToolCallBlocks(history);
        if (blocks.isEmpty()) {
            return history;
        }

        // 重要：剪枝触发时，至少要保留“最新一个块”（也就是刚执行完工具的那一轮），否则会破坏 tool loop。
        int keepBlocks = Math.max(1, keepRecentToolResponses);
        if (blocks.size() <= keepBlocks) {
            return history;
        }

        int dropBlocks = blocks.size() - keepBlocks;
        log.debug("PruningToolCallAdvisor - toolCallBlocks total={}, keepBlocks={}, dropBlocks={}",
            blocks.size(),
            keepBlocks,
            dropBlocks);

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

    /**
     * 找出 history 里的「tool-call 块」。
     *
     * 规则：一段连续 TOOL messages 视为一个块的“TOOL 响应部分”。如果它前面紧挨着一个 ASSISTANT，
     * 则把该 ASSISTANT 一并纳入块（通常是 assistant(tool_calls)）。
     */
    private List<ToolCallBlock> findToolCallBlocks(List<Message> history) {
        List<ToolCallBlock> blocks = new ArrayList<>();

        for (int i = 0; i < history.size(); i++) {
            Message msg = history.get(i);
            if (msg.getMessageType() != MessageType.TOOL) {
                continue;
            }

            // 连续 TOOL messages 的起点。
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