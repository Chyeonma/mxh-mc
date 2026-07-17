package com.mxh.auth.service;

import com.mxh.auth.domain.RefreshToken;
import com.mxh.auth.domain.RefreshTokenRepository;
import com.mxh.auth.domain.User;
import com.mxh.auth.domain.UserRepository;
import com.mxh.auth.dto.*;
import com.mxh.auth.security.CustomUserDetails;
import com.mxh.auth.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.ZonedDateTime;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider tokenProvider;
    private final StringRedisTemplate redisTemplate;

    private static final String REDIS_REFRESH_PREFIX = "refresh_token:";
    private static final String REDIS_BLACKLIST_PREFIX = "blacklist_token:";

    @Override
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new IllegalArgumentException("Username đã tồn tại: " + request.getUsername());
        }
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Email đã tồn tại: " + request.getEmail());
        }

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .role("ROLE_USER")
                .status("ACTIVE")
                .build();

        user = userRepository.save(user);

        CustomUserDetails userDetails = CustomUserDetails.fromUser(user);
        String accessToken = tokenProvider.generateAccessToken(userDetails);
        String refreshTokenStr = createAndSaveRefreshToken(user);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshTokenStr)
                .userId(user.getId())
                .username(user.getUsername())
                .fullName(user.getFullName())
                .role(user.getRole())
                .build();
    }

    @Override
    @Transactional
    public AuthResponse login(LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsernameOrEmail(), request.getPassword())
        );

        CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new IllegalStateException("User không tồn tại"));

        String accessToken = tokenProvider.generateAccessToken(userDetails);
        String refreshTokenStr = createAndSaveRefreshToken(user);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshTokenStr)
                .userId(user.getId())
                .username(user.getUsername())
                .fullName(user.getFullName())
                .role(user.getRole())
                .build();
    }

    @Override
    @Transactional
    public AuthResponse refreshToken(TokenRefreshRequest request) {
        String requestRefreshToken = request.getRefreshToken();

        // Kiểm tra trong Redis trước hoặc trong DB
        String redisKey = REDIS_REFRESH_PREFIX + requestRefreshToken;
        String userIdStr = redisTemplate.opsForValue().get(redisKey);

        RefreshToken refreshToken = refreshTokenRepository.findByToken(requestRefreshToken)
                .orElseThrow(() -> new IllegalArgumentException("Refresh token không tồn tại trong hệ thống"));

        if (refreshToken.getExpiresAt().isBefore(ZonedDateTime.now())) {
            refreshTokenRepository.delete(refreshToken);
            redisTemplate.delete(redisKey);
            throw new IllegalArgumentException("Refresh token đã hết hạn, vui lòng đăng nhập lại");
        }

        User user = refreshToken.getUser();
        CustomUserDetails userDetails = CustomUserDetails.fromUser(user);
        String newAccessToken = tokenProvider.generateAccessToken(userDetails);

        return AuthResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(requestRefreshToken)
                .userId(user.getId())
                .username(user.getUsername())
                .fullName(user.getFullName())
                .role(user.getRole())
                .build();
    }

    @Override
    @Transactional
    public void logout(String refreshToken) {
        refreshTokenRepository.findByToken(refreshToken).ifPresent(token -> {
            refreshTokenRepository.delete(token);
            redisTemplate.delete(REDIS_REFRESH_PREFIX + refreshToken);
        });
    }

    @Override
    public TokenValidationResponse validateToken(String bearerToken) {
        if (bearerToken == null || !bearerToken.startsWith("Bearer ")) {
            return TokenValidationResponse.builder().valid(false).build();
        }

        String token = bearerToken.substring(7);
        if (!tokenProvider.validateToken(token)) {
            return TokenValidationResponse.builder().valid(false).build();
        }

        UUID userId = tokenProvider.getUserIdFromToken(token);
        String username = tokenProvider.getUsernameFromToken(token);
        String role = tokenProvider.getRoleFromToken(token);

        return TokenValidationResponse.builder()
                .valid(true)
                .userId(userId)
                .username(username)
                .role(role)
                .build();
    }

    private String createAndSaveRefreshToken(User user) {
        // Xóa các refresh token cũ của user để giữ gọn hệ thống
        refreshTokenRepository.deleteByUser(user);

        String tokenStr = tokenProvider.generateRefreshToken(user.getId());
        ZonedDateTime expiresAt = ZonedDateTime.now().plus(Duration.ofMillis(tokenProvider.getRefreshExpirationMs()));

        RefreshToken refreshToken = RefreshToken.builder()
                .user(user)
                .token(tokenStr)
                .expiresAt(expiresAt)
                .build();

        refreshTokenRepository.save(refreshToken);

        // Lưu vào Redis cache nóng
        try {
            redisTemplate.opsForValue().set(
                    REDIS_REFRESH_PREFIX + tokenStr,
                    user.getId().toString(),
                    tokenProvider.getRefreshExpirationMs(),
                    TimeUnit.MILLISECONDS
            );
        } catch (Exception ex) {
            log.warn("Không thể lưu refresh token vào Redis (Có thể Redis chưa bật), vẫn tiếp tục với DB. Error: {}", ex.getMessage());
        }

        return tokenStr;
    }
}
