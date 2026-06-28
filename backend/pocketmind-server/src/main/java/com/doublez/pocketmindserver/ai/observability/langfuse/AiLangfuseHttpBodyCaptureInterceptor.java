package com.doublez.pocketmindserver.ai.observability.langfuse;

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
 * 业务侧：捕获 OpenAI-compatible HTTP 请求/响应 body，并写入 Langfuse 可展示字段。
 *
 * 说明：
 * - OTel 的 HTTP 客户端 span 默认不采集 body，因此 Langfuse 里 "http post" 节点通常看不到 output。
 * - Spring AI 2.0 使用 OpenAI Java SDK + OkHttp，这里通过 OkHttp interceptor 写入当前 span。
 * - 该类仅服务于主项目 ai 模块，不与 demo 互相影响。
 */
public class AiLangfuseHttpBodyCaptureInterceptor implements Interceptor {

    private final boolean logFullPayload;
    private final int maxPayloadLength;

    public AiLangfuseHttpBodyCaptureInterceptor(boolean logFullPayload, int maxPayloadLength) {
        this.logFullPayload = logFullPayload;
        this.maxPayloadLength = Math.max(0, maxPayloadLength);
    }

    @Override
    public Response intercept(Chain chain) throws IOException {
        Request request = chain.request();

        LangfuseSpanWriter.trySetObservationInput(truncate(readRequestBody(request.body())));
        LangfuseSpanWriter.trySetMetadata("http_method", request.method());
        LangfuseSpanWriter.trySetMetadata("http_url", request.url().toString());

        Response response = chain.proceed(request);
        ResponseBody responseBody = response.body();
        if (responseBody == null) {
            LangfuseSpanWriter.trySetMetadata("http_status", response.code());
            return response;
        }

        MediaType contentType = responseBody.contentType();
        LangfuseSpanWriter.trySetMetadata("http_status", response.code());
        if (isEventStream(contentType)) {
            return response;
        }

        byte[] responseBytes = responseBody.bytes();
        String output = responseBytes.length == 0 ? "" : new String(responseBytes, StandardCharsets.UTF_8);
        LangfuseSpanWriter.trySetObservationOutput(truncate(output));

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
}
