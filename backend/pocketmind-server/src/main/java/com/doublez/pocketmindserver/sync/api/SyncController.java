package com.doublez.pocketmindserver.sync.api;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushRequest;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushResult;
import com.doublez.pocketmindserver.sync.application.SyncService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 同步 API 控制器。
 *
 * <p>路由规划：
 * <ul>
 *   <li>{@code GET  /api/sync/pull?sinceVersion={long}&pageSize={int}} — 增量拉取</li>
 *   <li>{@code POST /api/sync/push} — 批量推送变更</li>
 * </ul>
 * </p>
 */
@Validated
@RestController
@RequestMapping("/api/sync")
@RequiredArgsConstructor
public class SyncController {

    /** 单次 Pull 最大页大小，防止超量查询 */
    private static final int MAX_PAGE_SIZE = 500;
    /** 单次 Pull 默认页大小 */
    private static final int DEFAULT_PAGE_SIZE = 200;

    private final SyncService syncService;

    /**
     * 增量拉取服务端变更。
     *
     * @param sinceVersion 客户端游标（上次返回的 serverVersion），首次传 0
     * @param pageSize     每页条目数，默认 200，上限 500
     */
    @GetMapping("/pull")
    public SyncPullResponse pull(
            @RequestParam(value = "sinceVersion", defaultValue = "0") long sinceVersion,
            @RequestParam(value = "pageSize", defaultValue = "" + DEFAULT_PAGE_SIZE)
            @Min(1) @Max(MAX_PAGE_SIZE) int pageSize
    ) {
        long userId = requireUserId();
        return syncService.pull(userId, sinceVersion, pageSize);
    }

    /**
     * 批量推送客户端本地变更。
     *
     * @param request 变更批次（有序）
     * @return 每条 mutation 的处理结果，长度与请求列表一致
     */
    @PostMapping("/push")
    public List<SyncPushResult> push(@Valid @RequestBody SyncPushRequest request) {
        long userId = requireUserId();
        return syncService.push(userId, request);
    }

    /** 从 SecurityContext 中解析必要的 userId，失败则抛 401 */
    private long requireUserId() {
        String raw = UserContext.getRequiredUserId();
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException e) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "非法 userId");
        }
    }
}
