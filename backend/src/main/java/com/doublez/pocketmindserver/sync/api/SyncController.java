package com.doublez.pocketmindserver.sync.api;

import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushRequest;
import com.doublez.pocketmindserver.sync.application.SyncService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 同步接口
 * POST /api/sync/push  客户端推送本地变更到服务端
 * GET  /api/sync/pull  客户端拉取服务端增量变更
 */
@RestController
@RequestMapping("/api/sync")
public class SyncController {

    private static final Logger log = LoggerFactory.getLogger(SyncController.class);

    private final SyncService syncService;

    public SyncController(SyncService syncService) {
        this.syncService = syncService;
    }

    /**
     * 推送本地变更
     */
    @PostMapping("/push")
    public ResponseEntity<Void> push(@Valid @RequestBody SyncPushRequest request) {
        long userId = Long.parseLong(UserContext.getRequiredUserId());
        log.info("接收到 push 请求: userId={}, changes={}", userId, request.changes().size());
        syncService.push(userId, request.changes());
        return ResponseEntity.ok().build();
    }

    /**
     * 拉取服务端增量变更
     *
     * @param cursor 上次拉取的游标（毫秒时间戳），首次传 0
     * @param limit  最多返回条数，默认 200，最大 1000
     */
    @GetMapping("/pull")
    public ResponseEntity<SyncPullResponse> pull(
            @RequestParam(defaultValue = "0") long cursor,
            @RequestParam(defaultValue = "200") int limit) {
        long userId = Long.parseLong(UserContext.getRequiredUserId());
        log.info("接收到 pull 请求: userId={}, cursor={}, limit={}", userId, cursor, limit);
        SyncPullResponse response = syncService.pull(userId, cursor, limit);
        return ResponseEntity.ok(response);
    }
}
