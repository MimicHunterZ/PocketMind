package com.doublez.pocketmindserver.demo;

import io.opentelemetry.api.trace.Span;
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
 * 仅用于 demo：捕获 OpenAI-compatible（DeepSeek）HTTP 请求/响应 body，并写入 Langfuse 可展示字段。
 *
 * 说明：OTel 的 HTTP 客户端 span 默认不采集 body，所以 Langfuse 里的 "http post" 节点通常看不到 output。
 * 这里通过 RestClient interceptor 在 HTTP 调用时把 body 写到当前 span 的 langfuse.observation.input/output。
 */
public class LangfuseHttpBodyCaptureInterceptor implements ClientHttpRequestInterceptor {

    @Override
    public @NotNull ClientHttpResponse intercept(@NotNull HttpRequest request, byte @NotNull [] body, @NotNull ClientHttpRequestExecution execution) throws IOException {
        Span span = Span.current();
        if (span != null && span.getSpanContext().isValid()) {
            span.setAttribute("langfuse.observation.input", new String(body, StandardCharsets.UTF_8));
            request.getMethod();
            span.setAttribute("langfuse.observation.metadata.http_method", request.getMethod().name());
            span.setAttribute("langfuse.observation.metadata.http_url", String.valueOf(request.getURI()));
        }

        ClientHttpResponse response = execution.execute(request, body);
        CachingClientHttpResponse wrapped = new CachingClientHttpResponse(response);

        if (span != null && span.getSpanContext().isValid()) {
            byte[] responseBytes = wrapped.getBodyBytes();
            span.setAttribute("langfuse.observation.output", responseBytes.length == 0 ? "" : new String(responseBytes, StandardCharsets.UTF_8));
            span.setAttribute("langfuse.observation.metadata.http_status", wrapped.getStatusCode().value());
        }

        return wrapped;
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
