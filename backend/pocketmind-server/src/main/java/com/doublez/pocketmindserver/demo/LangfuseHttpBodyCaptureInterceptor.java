package com.doublez.pocketmindserver.demo;

import io.opentelemetry.api.trace.Span;
import okhttp3.Interceptor;
import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;
import okio.Buffer;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * 仅用于 demo：捕获 OpenAI-compatible（DeepSeek）HTTP 请求/响应 body，并写入 Langfuse 可展示字段。
 *
 * 说明：OTel 的 HTTP 客户端 span 默认不采集 body，所以 Langfuse 里的 "http post" 节点通常看不到 output。
 * 这里通过 Spring AI 2.0 的 OkHttp interceptor 把 body 写到当前 span。
 */
public class LangfuseHttpBodyCaptureInterceptor implements Interceptor {

    @Override
    public Response intercept(Chain chain) throws IOException {
        Request request = chain.request();
        Span span = Span.current();
        if (span != null && span.getSpanContext().isValid()) {
            span.setAttribute("langfuse.observation.input", readRequestBody(request.body()));
            span.setAttribute("langfuse.observation.metadata.http_method", request.method());
            span.setAttribute("langfuse.observation.metadata.http_url", request.url().toString());
        }

        Response response = chain.proceed(request);
        ResponseBody responseBody = response.body();

        if (span != null && span.getSpanContext().isValid()) {
            span.setAttribute("langfuse.observation.metadata.http_status", response.code());
        }
        if (responseBody == null || isEventStream(responseBody.contentType())) {
            return response;
        }

        MediaType contentType = responseBody.contentType();
        byte[] responseBytes = responseBody.bytes();
        if (span != null && span.getSpanContext().isValid()) {
            span.setAttribute("langfuse.observation.output",
                    responseBytes.length == 0 ? "" : new String(responseBytes, StandardCharsets.UTF_8));
        }

        return response.newBuilder()
                .body(ResponseBody.create(contentType, responseBytes))
                .build();
    }

    private String readRequestBody(RequestBody requestBody) throws IOException {
        if (requestBody == null || requestBody.isDuplex() || requestBody.isOneShot()) {
            return "";
        }
        Buffer buffer = new Buffer();
        requestBody.writeTo(buffer);
        return buffer.readString(StandardCharsets.UTF_8);
    }

    private boolean isEventStream(MediaType contentType) {
        return contentType != null
                && "text".equalsIgnoreCase(contentType.type())
                && "event-stream".equalsIgnoreCase(contentType.subtype());
    }
}
