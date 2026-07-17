package com.mxh.auth.service;

import com.mxh.auth.dto.*;

public interface AuthService {

    AuthResponse register(RegisterRequest request);

    AuthResponse login(LoginRequest request);

    AuthResponse refreshToken(TokenRefreshRequest request);

    void logout(String refreshToken);

    TokenValidationResponse validateToken(String bearerToken);
}
