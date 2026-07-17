package com.mxh.auth.service;

import com.mxh.auth.dto.UserProfileResponse;

import java.util.UUID;

public interface UserService {

    UserProfileResponse getProfileById(UUID userId);

    UserProfileResponse getProfileByUsername(String username);
}
