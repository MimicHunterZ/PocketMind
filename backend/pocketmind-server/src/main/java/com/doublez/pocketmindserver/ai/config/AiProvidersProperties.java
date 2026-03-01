package com.doublez.pocketmindserver.ai.config;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.HashMap;
import java.util.Map;

/**
 * 澶氬巶鍟?澶氳鑹?AI Provider 閰嶇疆銆?
 * 璇存槑锛?
 * - 缁熶竴鐢?OpenAI Compatible API锛坆ase-url + api-key + model锛夈€?
 * - 閫氳繃 routes 灏嗕笉鍚屼笟鍔″満鏅矾鐢卞埌涓嶅悓 provider銆?
 */
@ConfigurationProperties(prefix = "pocketmind.ai.providers")
public record AiProvidersProperties(
        Routes routes,
        Map<String, ProviderConfig> configs
) {

    public AiProvidersProperties {
        if (configs == null) {
            configs = new HashMap<>();
        }
    }

    /**
     * 瑙掕壊璺敱锛氭瘡涓鑹叉寚瀹氫竴涓?provider key锛堝搴?configs 鐨?key锛夈€?
     */
    public record Routes(
            /**
             * 瀵硅瘽涓绘ā鍨嬭矾鐢憋紙chat-primary锛夈€?
             */
            String chatPrimary,

            /**
             * 瀵硅瘽鍓ā鍨嬭矾鐢憋紙chat-secondary锛夈€?
             */
            String chatSecondary,

            /**
             * 瀵硅瘽鍏滃簳妯″瀷璺敱锛坈hat-fallback锛夈€?
             */
            String chatFallback,

            /**
             * 瑙嗚涓绘ā鍨嬭矾鐢憋紙vision-primary锛夈€?
             */
            String visionPrimary,

            /**
             * vision 涓撶敤闄嶇骇閾捐矾锛堝彲閫夛級锛氬綋 vision 澶辫触鏃朵娇鐢ㄧ殑鈥滅浜屽€欓€夆€濄€?
             */
            String visionSecondary,

            /**
             * vision 涓撶敤闄嶇骇閾捐矾锛堝彲閫夛級锛氬綋 vision 涓?visionSecondary 閮藉け璐ユ椂浣跨敤鐨勫厹搴曘€?
             */
            String visionFallback,
            String image,
            String audio
    ) {
    }

    /**
     * OpenAI Compatible 閰嶇疆銆?
     */
    public record ProviderConfig(
            String apiKey,
            String baseUrl,
            String model,

            /**
             * 妯″瀷鏈€澶т笂涓嬫枃绐楀彛銆?
             *
             * 璇存槑锛氱敤浜庡伐鍏风粨鏋滃壀鏋?涓婁笅鏂囧伐绋嬬瓑鍦烘櫙锛?=0 琛ㄧず鏈厤缃€?
             */
            int windowTokens
    ) {
    }

    public String resolveProviderKey(AiClientId clientId) {
        String byRoute = routes == null ? null : switch (clientId) {
            case CHAT_PRIMARY -> routes.chatPrimary();
            case CHAT_SECONDARY -> routes.chatSecondary();
            case CHAT_FALLBACK -> routes.chatFallback();
            case VISION_PRIMARY -> routes.visionPrimary();
            case VISION_SECONDARY -> routes.visionSecondary();
            case VISION_FALLBACK -> routes.visionFallback();
            case IMAGE -> routes.image();
            case AUDIO -> routes.audio();
        };

        if (byRoute != null && !byRoute.isBlank()) {
            return byRoute.trim();
        }
        return "";
    }

    public ProviderConfig resolveConfig(AiClientId clientId) {
        String providerKey = resolveProviderKey(clientId);
        if (providerKey.isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "鏈厤缃?provider 璺敱锛歝lientId=" + clientId);
        }

        ProviderConfig config = configs.get(providerKey);
        if (config == null) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "鏈壘鍒?provider 閰嶇疆锛歱roviderKey=" + providerKey + ", clientId=" + clientId);
        }
        validateConfig(config, providerKey, "clientId=" + clientId);
        return config;
    }

    private void validateConfig(ProviderConfig config, String providerKey, String purpose) {
        if (config.baseUrl() == null || config.baseUrl().isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "provider.base-url 涓嶈兘涓虹┖锛歱roviderKey=" + providerKey + ", " + purpose);
        }
        if (config.apiKey() == null || config.apiKey().isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "provider.api-key 涓嶈兘涓虹┖锛歱roviderKey=" + providerKey + ", " + purpose);
        }
        if (config.model() == null || config.model().isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "provider.model 涓嶈兘涓虹┖锛歱roviderKey=" + providerKey + ", " + purpose);
        }
    }
}

