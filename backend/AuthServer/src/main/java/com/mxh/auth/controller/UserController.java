package com.mxh.auth.controller;

import com.mxh.auth.dto.ApiResponse;
import com.mxh.auth.dto.UserProfileResponse;
import com.mxh.auth.security.CustomUserDetails;
import com.mxh.auth.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<UserProfileResponse>> getCurrentUserProfile(
            @AuthenticationPrincipal CustomUserDetails currentUser) {
        UserProfileResponse profile = userService.getProfileById(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Lấy profile cá nhân thành công", profile));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserProfileResponse>> getUserProfileById(@PathVariable UUID id) {
        UserProfileResponse profile = userService.getProfileById(id);
        return ResponseEntity.ok(ApiResponse.success("Lấy thông tin user thành công", profile));
    }

    @GetMapping("/username/{username}")
    public ResponseEntity<ApiResponse<UserProfileResponse>> getUserProfileByUsername(@PathVariable String username) {
        UserProfileResponse profile = userService.getProfileByUsername(username);
        return ResponseEntity.ok(ApiResponse.success("Lấy thông tin user theo username thành công", profile));
    }
}
