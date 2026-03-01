package com.doublez.pocketmindserver.ai.observability.langfuse;

import org.jetbrains.annotations.NotNull;
import org.springframework.http.HttpRequest;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.util.StreamUtils;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/**
 * 业务侧：捕获 OpenAI-compatible HTTP 请求/响应 body，并写入 Langfuse 可展示字段。
 *
 * 说明：
 * - OTel 的 HTTP 客户端 span 默认不采集 body，因此 Langfuse 里 "http post" 节点通常看不到 output。
 * - 这里通过 RestClient interceptor 在 HTTP 调用时把 body 写到当前 span 的 langfuse.observation.input/output。
 * - 该类仅服务于主项目 ai 模块，不与 demo 互相影响。
 */
public class AiLangfuseHttpBodyCaptureInterceptor implements ClientHttpRequestInterceptor {

    private final boolean logFullPayload;
    private final int maxPayloadLength;

    public AiLangfuseHttpBodyCaptureInterceptor(boolean logFullPayload, int maxPayloadLength) {
        this.logFullPayload = logFullPayload;
        this.maxPayloadLength = Math.max(0, maxPayloadLength);
    }

    @Override
    public @NotNull ClientHttpResponse intercept(@NotNull HttpRequest request,
                                                 byte @NotNull [] body,
                                                 @NotNull ClientHttpRequestExecution execution) throws IOException {

        LangfuseSpanWriter.trySetObservationInput(truncate(new String(body, StandardCharsets.UTF_8)));
        if (request.getMethod() != null) {
            LangfuseSpanWriter.trySetMetadata("http_method", request.getMethod().name());
        }
        LangfuseSpanWriter.trySetMetadata("http_url", String.valueOf(request.getURI()));

        ClientHttpResponse response = execution.execute(request, body);
        CachingClientHttpResponse wrapped = new CachingClientHttpResponse(response);

        byte[] responseBytes = wrapped.getBodyBytes();
        String output = responseBytes.length == 0 ? "" : new String(responseBytes, StandardCharsets.UTF_8);
        LangfuseSpanWriter.trySetObservationOutput(truncate(output));
        try {
            LangfuseSpanWriter.trySetMetadata("http_status", wrapped.getStatusCode().value());
        } catch (Exception ignored) {
        }

        return wrapped;
    }

    private String truncate(String raw) {
        if (raw == null) {
            return "";
        }
        if (logFullPayload || maxPayloadLength <= 0) {
            return raw;
        }
        if (raw.length() <= maxPayloadLength) {
            return raw;
        }
        return raw.substring(0, maxPayloadLength) + "...";
    }

    /**
     * RestClient 的响应 body 是 InputStream，只能读取一次。
     * 为了既能记录 body，又不影响后续 JSON 解析，这里把 body 缓存到 byte[] 并提供可重复读取的 getBody()。
     */
    private static final class CachingClientHttpResponse implements ClientHttpResponse {
        private final ClientHttpResponse delegate;
        private final byte[] bodyBytes;

        private CachingClientHttpResponse(ClientHttpResponse delegate) throws IOException {
            this.delegate = delegate;
            InputStream in = delegate.getBody();
            this.bodyBytes = in == null ? new byte[0] : StreamUtils.copyToByteArray(in);
        }

        private byte[] getBodyBytes() {
            return this.bodyBytes;
        }

        @Override
        public org.springframework.http.@NotNull HttpStatusCode getStatusCode() throws IOException {
            return delegate.getStatusCode();
        }

        @Override
        public @NotNull String getStatusText() throws IOException {
            return delegate.getStatusText();
        }

        @Override
        public void close() {
            delegate.close();
        }

        @Override
        public InputStream getBody() {
            return new ByteArrayInputStream(bodyBytes);
        }

        @Override
        public org.springframework.http.HttpHeaders getHeaders() {
            return delegate.getHeaders();
        }
    }
}
