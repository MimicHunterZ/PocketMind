package com.doublez.pocketmindserver.demo.a2ui.application;

import com.doublez.pocketmindserver.ai.application.stream.ChatSseEventFactory;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
public class A2uiStreamServiceImpl implements A2uiStreamService {

    private static final String SURFACE_ID = "main";
    private static final String CATALOG_ID = "https://a2ui.org/specification/v0_9/standard_catalog.json";
    private static final String STREAM_MESSAGE_ID = "streamMessage";

    private final ChatSseEventFactory sse;
    private final AiFailoverRouter aiFailoverRouter;
    private final ObjectMapper objectMapper;
    private final Resource streamSystemTemplateOverride;
    private final Resource streamUserTemplateOverride;

    @Value("classpath:prompts/demo/a2ui/option_c_stream_system.md")
    private Resource streamSystemTemplate;

    @Value("classpath:prompts/demo/a2ui/option_c_stream_user.md")
    private Resource streamUserTemplate;

    @Autowired
    public A2uiStreamServiceImpl(ChatSseEventFactory sse, AiFailoverRouter aiFailoverRouter) {
        this(sse, aiFailoverRouter, null, null);
    }

    public A2uiStreamServiceImpl(ChatSseEventFactory sse,
                                 AiFailoverRouter aiFailoverRouter,
                                 Resource streamSystemTemplateOverride,
                                 Resource streamUserTemplateOverride) {
        this.sse = sse;
        this.aiFailoverRouter = aiFailoverRouter;
        this.objectMapper = new ObjectMapper();
        this.streamSystemTemplateOverride = streamSystemTemplateOverride;
        this.streamUserTemplateOverride = streamUserTemplateOverride;
    }

    @Override
    public Flux<ServerSentEvent<String>> stream(long userId,
                                                String query,
                                                String requestId) {
        String safeQuery = safe(query);
        String reqId = (requestId == null || requestId.isBlank())
                ? UUID.randomUUID().toString()
                : requestId;

        List<ServerSentEvent<String>> bootstrap = buildBootstrapEvents(safeQuery);

        return Flux.defer(() -> {
            State state = new State();

            Flux<ServerSentEvent<String>> streamAndParse = buildTokenFlux(safeQuery, reqId)
                    .concatMapIterable(chunk -> processChunk(chunk, state));

            Flux<ServerSentEvent<String>> terminal = Flux.defer(() -> {
                List<ServerSentEvent<String>> tail = new ArrayList<>();
                if (state.inJsonBlock && state.jsonBuffer.length() > 0) {
                    state.markdownBuffer.append("\n```a2ui\n").append(state.jsonBuffer);
                    tail.add(markdownUpdateEvent(state.markdownBuffer.toString()));
                }
                tail.add(streamLoadingEvent(false));
                tail.add(sse.done(reqId, UUID.randomUUID()));
                return Flux.fromIterable(tail);
            });

            return Flux.concat(
                    Flux.fromIterable(bootstrap),
                    streamAndParse,
                    terminal
            ).onErrorResume(ex -> {
                log.error("A2UI Demo 流式输出失败: requestId={}", reqId, ex);
                return Flux.just(
                        streamLoadingEvent(false),
                        sse.error(reqId, "A2UI_STREAM_FAILED")
                );
            });
        });
    }

    private static class State {
        StringBuilder markdownBuffer = new StringBuilder();
        StringBuilder jsonBuffer = new StringBuilder();
        boolean inJsonBlock = false;
        List<String> childrenIds = new ArrayList<>(List.of("questionEcho", STREAM_MESSAGE_ID));
    }

    private List<ServerSentEvent<String>> processChunk(String chunk, State state) {
        if (chunk == null || chunk.isEmpty()) {
            return List.of();
        }

        List<ServerSentEvent<String>> events = new ArrayList<>();

        if (!state.inJsonBlock) {
            state.markdownBuffer.append(chunk);
            String fullMd = state.markdownBuffer.toString();
            int startIndex = fullMd.indexOf("```a2ui");

            if (startIndex >= 0) {
                state.inJsonBlock = true;
                String before = fullMd.substring(0, startIndex);
                if (!before.isEmpty()) {
                    events.add(markdownUpdateEvent(before));
                }
                state.markdownBuffer = new StringBuilder(before);

                String afterTag = fullMd.substring(startIndex + "```a2ui".length());
                state.jsonBuffer.append(afterTag);
            } else {
                events.add(markdownUpdateEvent(fullMd));
            }
        } else {
            state.jsonBuffer.append(chunk);
        }

        if (state.inJsonBlock) {
            String fullJson = state.jsonBuffer.toString();
            int endIndex = fullJson.indexOf("```");
            if (endIndex >= 0) {
                String jsonContent = fullJson.substring(0, endIndex).trim();

                try {
                    List<Map<String, Object>> components = objectMapper.readValue(jsonContent, new TypeReference<>() {
                    });
                    events.add(delta(Map.of(
                            "version", "v0.9",
                            "updateComponents", Map.of(
                                    "surfaceId", SURFACE_ID,
                                    "components", components
                            )
                    )));

                    for (Map<String, Object> comp : components) {
                        String id = (String) comp.get("id");
                        if (id != null && !state.childrenIds.contains(id)) {
                            state.childrenIds.add(state.childrenIds.size() - 1, id);
                        }
                    }

                    events.add(delta(Map.of(
                            "version", "v0.9",
                            "updateComponents", Map.of(
                                    "surfaceId", SURFACE_ID,
                                    "components", List.of(
                                            Map.of(
                                                    "id", "root",
                                                    "component", "Column",
                                                    "children", new ArrayList<>(state.childrenIds)
                                            )
                                    )
                            )
                    )));
                } catch (Exception e) {
                    log.warn("解析 A2UI JSON 块失败", e);
                }

                state.inJsonBlock = false;
                state.jsonBuffer = new StringBuilder();
                String after = fullJson.substring(endIndex + "```".length());
                state.markdownBuffer.append(after);

                if (!after.isEmpty()) {
                    events.add(markdownUpdateEvent(state.markdownBuffer.toString()));
                }
            }
        }

        return events;
    }

    private Flux<String> buildTokenFlux(String query, String requestId) {
        Resource streamSystem = streamSystemTemplateOverride != null ? streamSystemTemplateOverride : streamSystemTemplate;
        Resource streamUser = streamUserTemplateOverride != null ? streamUserTemplateOverride : streamUserTemplate;
        if (aiFailoverRouter == null || streamSystem == null || streamUser == null) {
            return Flux.error(new IllegalStateException("A2UI_STREAM_NOT_CONFIGURED"));
        }
        try {
            Prompt prompt = PromptBuilder.build(
                    streamSystem,
                    streamUser,
                    Map.of(
                            "query", query,
                            "requestId", requestId
                    )
            );
            return aiFailoverRouter.executeChatStream(
                            "demo-a2ui-stream",
                            client -> client.prompt(prompt).stream().content()
                    )
                    .switchIfEmpty(Flux.error(new IllegalStateException("A2UI_EMPTY_STREAM")));
        } catch (Exception ex) {
            log.warn("构建 A2UI Demo 流式 prompt 失败: requestId={}", requestId, ex);
            return Flux.error(new IllegalStateException("A2UI_PROMPT_BUILD_FAILED", ex));
        }
    }

    private List<ServerSentEvent<String>> buildBootstrapEvents(String query) {
        return List.of(
                delta(Map.of(
                        "version", "v0.9",
                        "createSurface", Map.of(
                                "surfaceId", SURFACE_ID,
                                "catalogId", CATALOG_ID
                        )
                )),
                delta(Map.of(
                        "version", "v0.9",
                        "updateComponents", Map.of(
                                "surfaceId", SURFACE_ID,
                                "components", List.of(
                                        Map.of(
                                                "id", STREAM_MESSAGE_ID,
                                                "component", "StreamingMarkdownMessage",
                                                "path", "/md/content",
                                                "isLoading", true
                                        ),
                                        Map.of(
                                                "id", "questionEcho",
                                                "component", "Text",
                                                "variant", "body",
                                                "text", "用户问题：" + query
                                        ),
                                        Map.of(
                                                "id", "root",
                                                "component", "Column",
                                                "children", List.of("questionEcho", STREAM_MESSAGE_ID)
                                        )
                                )
                        )
                ))
        );
    }

    private ServerSentEvent<String> markdownUpdateEvent(String markdown) {
        return delta(Map.of(
                "version", "v0.9",
                "updateDataModel", Map.of(
                        "surfaceId", SURFACE_ID,
                        "path", "/md/content",
                        "value", markdown
                )
        ));
    }

    private ServerSentEvent<String> streamLoadingEvent(boolean loading) {
        return delta(Map.of(
                "version", "v0.9",
                "updateComponents", Map.of(
                        "surfaceId", SURFACE_ID,
                        "components", List.of(
                                Map.of(
                                        "id", STREAM_MESSAGE_ID,
                                        "component", "StreamingMarkdownMessage",
                                        "path", "/md/content",
                                        "isLoading", loading
                                )
                        )
                )
        ));
    }

    private ServerSentEvent<String> delta(Map<String, Object> payload) {
        return sse.event("delta", payload);
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }
}
