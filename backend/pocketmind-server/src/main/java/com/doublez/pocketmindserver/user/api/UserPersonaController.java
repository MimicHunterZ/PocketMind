package com.doublez.pocketmindserver.user.api;

import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.user.api.dto.CreatePersonaReq;
import com.doublez.pocketmindserver.user.api.dto.UpdatePersonaReq;
import com.doublez.pocketmindserver.user.api.dto.UserPersonaDto;
import com.doublez.pocketmindserver.user.application.UserPersonaService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/user-personas")
@RequiredArgsConstructor
public class UserPersonaController {

    private final UserPersonaService userPersonaService;

    private long parseUserId() {
        return Long.parseLong(UserContext.getRequiredUserId());
    }

    @PostMapping
    public ResponseEntity<UserPersonaDto> createPersona(@Validated @RequestBody CreatePersonaReq req) {
        return ResponseEntity.ok(userPersonaService.createPersona(parseUserId(), req));
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserPersonaDto> updatePersona(@PathVariable long id, @Validated @RequestBody UpdatePersonaReq req) {
        return ResponseEntity.ok(userPersonaService.updatePersona(parseUserId(), id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePersona(@PathVariable long id) {
        userPersonaService.deletePersona(parseUserId(), id);
        return ResponseEntity.ok().build();
    }

    @GetMapping
    public ResponseEntity<List<UserPersonaDto>> listPersonas() {
        return ResponseEntity.ok(userPersonaService.listPersonas(parseUserId()));
    }

    @PutMapping("/{id}/active")
    public ResponseEntity<Void> setActivePersona(@PathVariable long id) {
        userPersonaService.setActivePersona(parseUserId(), id);
        return ResponseEntity.ok().build();
    }
}