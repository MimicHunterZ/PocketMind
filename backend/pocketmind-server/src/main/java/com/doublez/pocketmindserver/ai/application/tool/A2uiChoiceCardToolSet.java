package com.doublez.pocketmindserver.ai.application.tool;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * A2UI 选择卡片渲染工具——把模型给出的候选项渲染成一张可点击单选的卡片。
 *
 * <p>组件怎么摆放（用 Column/Card/ChoicePicker/Button 拼出什么样的界面）完全写死在
 * 这个类里，模型调用时只传业务数据（标题 + 候选项列表），不会接触任何组件 schema。
 * 这样既不占用模型上下文，也不会因为模型拼错组件结构而产出前端无法渲染的卡片。
 *
 * <p>卡片渲染本身不需要按用户维度查数据，但为了跟同类请求级工具集（记忆/资源）保持
 * 同样的接入方式，仍然走 Factory + 按请求创建实例这一套，方便调用方统一处理。
 */
@Slf4j
public class A2uiChoiceCardToolSet {

    /**
     * 前端 A2UI 客户端内置识别的标准 catalog id，必须和移动端 genui 包导出的
     * {@code basicCatalogId} 常量字符串完全一致，否则客户端 SurfaceController
     * 找不到匹配的 catalog，卡片会渲染失败。genui 曾在 0.9.0 把这个 URL 从
     * standard_catalog.json 改成 basic_catalog.json（未在 CHANGELOG 提及），
     * 升级 mobile 端 genui 版本时要顺带核对这个值有没有变。
     */
    private static final String STANDARD_CATALOG_ID = "https://a2ui.org/specification/v0_9/basic_catalog.json";

    private final ObjectMapper objectMapper;

    public A2uiChoiceCardToolSet(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Tool(description = "生成一张选择卡片，把若干候选项（如推荐的笔记、资源或方向）渲染成可点击的" +
            "单选列表展示给用户，用户选择后会提交确认。调用前请先想好具体的候选内容（标题+一句话说明），" +
            "本工具只负责按固定样式渲染卡片，不会自己检索或生成候选内容。适合“给我推荐几个选项让我选”" +
            "这类需要用户从多个选项里做单选决定的场景。")
    public String renderChoiceCard(
            @ToolParam(description = "卡片标题，一句话说明这次要选什么") String title,
            @ToolParam(description = "候选项列表，建议 2-6 条，每条包含标题和一句话说明") List<ChoiceCardItem> items) {
        if (items == null || items.isEmpty()) {
            return "候选项不能为空，请至少提供一个选项。";
        }

        String surfaceId = "choice-card-" + UUID.randomUUID();
        List<Map<String, Object>> operations = List.of(
                createSurfaceMessage(surfaceId),
                updateComponentsMessage(surfaceId, title, items));

        try {
            return objectMapper.writeValueAsString(operations);
        } catch (Exception e) {
            log.warn("[a2ui-tool] 选择卡片序列化失败: {}", e.getMessage());
            return "卡片生成失败。";
        }
    }

    private Map<String, Object> createSurfaceMessage(String surfaceId) {
        Map<String, Object> createSurface = new LinkedHashMap<>();
        createSurface.put("surfaceId", surfaceId);
        createSurface.put("catalogId", STANDARD_CATALOG_ID);

        Map<String, Object> message = new LinkedHashMap<>();
        message.put("version", "v0.9");
        message.put("createSurface", createSurface);
        return message;
    }

    /**
     * 只用 createSurface 开不出实际界面（它只声明 surfaceId/catalogId），
     * 真正的组件树要靠紧跟着的 updateComponents 一起发，两条消息合起来才是
     * 一张能渲染出内容的卡片——这也是前端 mock 场景里验证过的写法。
     */
    private Map<String, Object> updateComponentsMessage(String surfaceId, String title, List<ChoiceCardItem> items) {
        List<Map<String, Object>> components = new ArrayList<>();
        components.add(component("root", "Column", Map.of("children", List.of("card"))));
        components.add(component("card", "Card", Map.of("child", "column")));
        components.add(component("column", "Column", Map.of(
                "children", List.of("title", "picker", "submitButton"),
                "align", "stretch")));
        components.add(component("title", "Text", Map.of("text", title, "variant", "h4")));

        List<Map<String, Object>> options = new ArrayList<>();
        for (int i = 0; i < items.size(); i++) {
            ChoiceCardItem item = items.get(i);
            String label = item.description() == null || item.description().isBlank()
                    ? item.title()
                    : item.title() + "：" + item.description();
            // value 用标题本身而不是 option-N 索引：用户选完提交回来的 dataModel 会随消息
            // 喂回模型，索引对模型无意义，标题才让模型知道用户到底选了什么（D7）。
            options.add(Map.of("label", label, "value", item.title()));
        }
        components.add(component("picker", "ChoicePicker", Map.of(
                "label", "请选择",
                "variant", "mutuallyExclusive",
                "options", options,
                "value", Map.of("path", "/choice/selected"))));

        components.add(component("submitButton", "Button", Map.of(
                "variant", "primary",
                "child", "submitLabel",
                "action", Map.of("event", Map.of(
                        "name", "submit_choice",
                        "context", Map.of("selected", Map.of("path", "/choice/selected")))))));
        components.add(component("submitLabel", "Text", Map.of("text", "确认选择")));

        Map<String, Object> updateComponents = new LinkedHashMap<>();
        updateComponents.put("surfaceId", surfaceId);
        updateComponents.put("components", components);

        Map<String, Object> message = new LinkedHashMap<>();
        message.put("version", "v0.9");
        message.put("updateComponents", updateComponents);
        return message;
    }

    private Map<String, Object> component(String id, String type, Map<String, Object> props) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", id);
        map.put("component", type);
        map.putAll(props);
        return map;
    }

    /** 一个候选项：标题 + 一句话说明。组件布局不受此结构影响，模型只填业务内容。 */
    public record ChoiceCardItem(String title, String description) {
    }

    public ToolCallback[] toToolCallbacks() {
        return ToolCallbacks.from(this);
    }

    @Component
    public static class A2uiChoiceCardToolSetFactory {

        private final ObjectMapper objectMapper;

        public A2uiChoiceCardToolSetFactory(ObjectMapper objectMapper) {
            this.objectMapper = objectMapper;
        }

        /**
         * userId 目前不参与卡片渲染逻辑，保留这个参数只是为了跟其它请求级
         * 工具集（记忆/资源）用同一种创建方式，方便调用方统一处理。
         */
        public A2uiChoiceCardToolSet createForUser(long userId) {
            return new A2uiChoiceCardToolSet(objectMapper);
        }
    }
}
