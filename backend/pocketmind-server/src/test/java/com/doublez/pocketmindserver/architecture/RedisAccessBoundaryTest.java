package com.doublez.pocketmindserver.architecture;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Redis 访问防回流架构测试：
 * server 模块禁止直接依赖 Spring Data Redis API，必须通过 framework-redis 提供的门面访问。
 */
class RedisAccessBoundaryTest {

    private static final String MAIN_JAVA_ROOT = "src/main/java";

    @Test
    void shouldNotUseSpringDataRedisDirectlyInServerModule() throws IOException {
        Path sourceRoot = Path.of(MAIN_JAVA_ROOT);
        List<String> violations = new ArrayList<>();

        try (Stream<Path> pathStream = Files.walk(sourceRoot)) {
            pathStream
                    .filter(Files::isRegularFile)
                    .filter(path -> path.toString().endsWith(".java"))
                    .forEach(path -> inspectFile(path, violations));
        }

        assertTrue(violations.isEmpty(), () -> "检测到 Redis 直连代码，请改为使用 framework-redis 的 RedisService。违规项:\n"
                + String.join("\n", violations));
    }

    private static void inspectFile(Path path, List<String> violations) {
        try {
            String content = Files.readString(path, StandardCharsets.UTF_8);
            if (content.contains("org.springframework.data.redis")
                    || content.contains("RedisTemplate<")
                    || content.contains("StringRedisTemplate")) {
                violations.add(path.toString());
            }
        } catch (IOException e) {
            violations.add(path + " (读取失败: " + e.getMessage() + ")");
        }
    }
}
