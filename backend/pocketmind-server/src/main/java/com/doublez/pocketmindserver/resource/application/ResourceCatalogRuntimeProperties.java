package com.doublez.pocketmindserver.resource.application;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Resource/Catalog 运行时配置。
 */
@ConfigurationProperties(prefix = "pocketmind.resource.catalog")
public class ResourceCatalogRuntimeProperties {

    private boolean retrievalFallbackEnabled = true;
    private int projectorBatchSize = 100;
    private long projectorRetryIntervalMillis = 5000L;
    private int hintListenerConcurrency = 2;
    private long hintDebounceMillis = 300L;
    private int hintMaxRetry = 3;
    private int hintDlqMaxReplay = 3;
    private long outboxProcessingLeaseMillis = 60000L;
    private boolean metricsEnabled = true;

    public ResourceCatalogRuntimeProperties() {
    }

    public ResourceCatalogRuntimeProperties(boolean retrievalFallbackEnabled,
                                            int projectorBatchSize,
                                            long projectorRetryIntervalMillis,
                                            boolean metricsEnabled) {
        this.retrievalFallbackEnabled = retrievalFallbackEnabled;
        setProjectorBatchSize(projectorBatchSize);
        setProjectorRetryIntervalMillis(projectorRetryIntervalMillis);
        this.metricsEnabled = metricsEnabled;
    }

    public boolean isRetrievalFallbackEnabled() {
        return retrievalFallbackEnabled;
    }

    public void setRetrievalFallbackEnabled(boolean retrievalFallbackEnabled) {
        this.retrievalFallbackEnabled = retrievalFallbackEnabled;
    }

    public int getProjectorBatchSize() {
        return projectorBatchSize;
    }

    public void setProjectorBatchSize(int projectorBatchSize) {
        this.projectorBatchSize = projectorBatchSize > 0 ? projectorBatchSize : 100;
    }

    public long getProjectorRetryIntervalMillis() {
        return projectorRetryIntervalMillis;
    }

    public void setProjectorRetryIntervalMillis(long projectorRetryIntervalMillis) {
        this.projectorRetryIntervalMillis = projectorRetryIntervalMillis > 0 ? projectorRetryIntervalMillis : 5000L;
    }

    public int getHintListenerConcurrency() {
        return hintListenerConcurrency;
    }

    public void setHintListenerConcurrency(int hintListenerConcurrency) {
        this.hintListenerConcurrency = hintListenerConcurrency > 0 ? hintListenerConcurrency : 2;
    }

    public long getHintDebounceMillis() {
        return hintDebounceMillis;
    }

    public void setHintDebounceMillis(long hintDebounceMillis) {
        this.hintDebounceMillis = hintDebounceMillis >= 0 ? hintDebounceMillis : 300L;
    }

    public int getHintMaxRetry() {
        return hintMaxRetry;
    }

    public void setHintMaxRetry(int hintMaxRetry) {
        this.hintMaxRetry = hintMaxRetry > 0 ? hintMaxRetry : 3;
    }

    public int getHintDlqMaxReplay() {
        return hintDlqMaxReplay;
    }

    public void setHintDlqMaxReplay(int hintDlqMaxReplay) {
        this.hintDlqMaxReplay = hintDlqMaxReplay > 0 ? hintDlqMaxReplay : 3;
    }

    public boolean isMetricsEnabled() {
        return metricsEnabled;
    }

    public void setMetricsEnabled(boolean metricsEnabled) {
        this.metricsEnabled = metricsEnabled;
    }

    public long getOutboxProcessingLeaseMillis() {
        return outboxProcessingLeaseMillis;
    }

    public void setOutboxProcessingLeaseMillis(long outboxProcessingLeaseMillis) {
        this.outboxProcessingLeaseMillis = outboxProcessingLeaseMillis > 0 ? outboxProcessingLeaseMillis : 60000L;
    }
}
