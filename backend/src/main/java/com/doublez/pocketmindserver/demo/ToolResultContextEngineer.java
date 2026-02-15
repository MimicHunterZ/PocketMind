package com.doublez.pocketmindserver.demo;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * 工具结果上下文工程处理器
 * 目标：降低工具回填中的噪声内容，保留对模型推理有用的信息
 */
public class ToolResultContextEngineer {

    private final boolean enabled;
    private final int maxLines;
    private final int maxChars;

    public ToolResultContextEngineer(boolean enabled, int maxLines, int maxChars) {
        this.enabled = enabled;
        this.maxLines = maxLines;
        this.maxChars = maxChars;
    }

    public String process(String toolName, String rawResult) {
        if (!enabled || rawResult == null || rawResult.isBlank()) {
            return rawResult;
        }

        List<String> lines = normalizeLines(rawResult);
        List<String> filtered = "Bash".equalsIgnoreCase(toolName)
                ? filterBashLines(lines)
                : filterGenericLines(lines);

        String merged = String.join("\n", filtered);
        if (merged.length() <= maxChars) {
            return merged;
        }
        return merged.substring(0, maxChars) + "\n...[context-engineering-truncated]";
    }

    private List<String> normalizeLines(String text) {
        String normalized = text.replace("\r\n", "\n").replace("\r", "\n");
        String[] split = normalized.split("\n");
        List<String> lines = new ArrayList<>(split.length);
        for (String line : split) {
            lines.add(line);
        }
        return lines;
    }

    private List<String> filterBashLines(List<String> lines) {
        List<String> importantLines = new ArrayList<>();
        List<String> normalLines = new ArrayList<>();
        Set<String> dedup = new HashSet<>();

        for (String line : lines) {
            String trimmed = line == null ? "" : line.trim();
            if (trimmed.isEmpty() || !dedup.add(trimmed)) {
                continue;
            }

            String lower = trimmed.toLowerCase(Locale.ROOT);
            boolean important = lower.contains("error")
                    || lower.contains("exception")
                    || lower.contains("exit code")
                    || lower.contains("stderr")
                    || lower.contains("file:")
                    || lower.startsWith("bash_id:")
                    || lower.endsWith(".java")
                    || lower.endsWith(".md");

            if (important) {
                importantLines.add(trimmed);
            } else {
                normalLines.add(trimmed);
            }
        }

        List<String> selected = new ArrayList<>(maxLines);
        for (String line : importantLines) {
            selected.add(line);
            if (selected.size() >= maxLines) {
                return selected;
            }
        }
        for (String line : normalLines) {
            selected.add(line);
            if (selected.size() >= maxLines) {
                return selected;
            }
        }

        if (selected.isEmpty()) {
            return lines.subList(0, Math.min(lines.size(), maxLines));
        }
        return selected;
    }

    private List<String> filterGenericLines(List<String> lines) {
        List<String> selected = new ArrayList<>();
        Set<String> dedup = new HashSet<>();

        for (String line : lines) {
            String trimmed = line == null ? "" : line.trim();
            if (trimmed.isEmpty() || !dedup.add(trimmed)) {
                continue;
            }
            selected.add(trimmed);
            if (selected.size() >= maxLines) {
                break;
            }
        }
        return selected;
    }
}
