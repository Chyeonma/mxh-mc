-- ==============================================================================
-- DATABASE SCHEMA: Mạng Xã Hội Polyglot Microservices (mxh_db)
-- Hỗ trợ: Spring Boot (Auth/Users), ASP.NET Core (Posts/Comments), Python (AI)
-- ==============================================================================

-- Enable extension pgcrypto để tạo UUID v4 (`gen_random_uuid()`)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. BẢNG USERS (Quản lý tài khoản & thông tin cá nhân - Spring Boot Auth Service)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(500) DEFAULT NULL,
    bio TEXT DEFAULT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'ROLE_USER', -- ROLE_USER, ROLE_ADMIN
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE, BANNED, PENDING
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS 'Bảng lưu thông tin tài khoản người dùng do Spring Boot Auth Service quản lý';
COMMENT ON COLUMN users.avatar_url IS 'URL hình ảnh đại diện lưu trên MinIO/S3';

-- ==============================================================================
-- 2. BẢNG REFRESH_TOKENS (Lưu trữ Refresh Token dài hạn cho Spring Boot Security)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);

-- ==============================================================================
-- 3. BẢNG FOLLOWS (Quan hệ theo dõi giữa các người dùng)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS follows (
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, following_id),
    CONSTRAINT chk_not_self_follow CHECK (follower_id <> following_id)
);

CREATE INDEX idx_follows_following_id ON follows(following_id);
COMMENT ON TABLE follows IS 'Bảng lưu quan hệ follow giữa các user, dùng cho New Feed và AI Service';

-- ==============================================================================
-- 4. BẢNG POSTS (Bài viết - ASP.NET Core Post Service)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT DEFAULT NULL,
    privacy VARCHAR(20) NOT NULL DEFAULT 'PUBLIC', -- PUBLIC, FRIENDS, PRIVATE
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    shares_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index quan trọng cho việc truy vấn feed mới nhất của 1 user
CREATE INDEX idx_posts_user_id_created_at ON posts(user_id, created_at DESC);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
COMMENT ON TABLE posts IS 'Bảng lưu nội dung bài viết, không bao gồm BLOB hình ảnh/video';

-- ==============================================================================
-- 5. BẢNG POST_MEDIA (Lưu đường dẫn hình ảnh/video của bài viết từ MinIO/S3)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS post_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    media_url VARCHAR(500) NOT NULL,
    media_type VARCHAR(20) NOT NULL, -- IMAGE, VIDEO
    display_order INTEGER NOT NULL DEFAULT 0,
    width INTEGER DEFAULT NULL,
    height INTEGER DEFAULT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_post_media_post_id ON post_media(post_id);
COMMENT ON TABLE post_media IS 'Lưu danh sách media (ảnh/video) của từng bài viết. Chỉ lưu URL từ MinIO/S3';

-- ==============================================================================
-- 6. BẢNG LIKES (Lượt yêu thích bài viết)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS likes (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX idx_likes_post_id ON likes(post_id);

-- ==============================================================================
-- 7. BẢNG COMMENTS (Bình luận bài viết, hỗ trợ nested comments/reply)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id UUID DEFAULT NULL REFERENCES comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    likes_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comments_post_id_created_at ON comments(post_id, created_at ASC);
CREATE INDEX idx_comments_parent_id ON comments(parent_comment_id);

-- ==============================================================================
-- 8. BẢNG AI_USER_PREFERENCES / RECOMMENDATION CACHE (Dành riêng cho Python AI)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS ai_recommendation_cache (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    recommended_post_ids UUID[] NOT NULL DEFAULT '{}',
    score_metadata JSONB DEFAULT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE ai_recommendation_cache IS 'Bảng đệm lưu kết quả phân tích gợi ý bài viết từ Python AI Service';

-- ==============================================================================
-- 9. SEED DATA MẪU (Dữ liệu ban đầu để kiểm tra hệ thống ngay sau khi boot)
-- ==============================================================================

-- Chèn 2 user mẫu (Mật khẩu mẫu đã hash bcrypt cho '123456' là: $2a$10$7Qx.H5v9g7u8E9.r7yYxue/T1.j5h6a7b8c9d0e1f2g3h4i5j6k7l)
INSERT INTO users (id, username, email, password_hash, full_name, bio, role)
VALUES 
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin_user', 'admin@mxh.local', '$2a$10$7Qx.H5v9g7u8E9.r7yYxue/T1.j5h6a7b8c9d0e1f2g3h4i5j6k7l', 'Quản Trị Viên', 'Hệ thống Admin MXH', 'ROLE_ADMIN'),
('b1ffcd00-ad1c-5fa9-cc7e-7cc0ce491b22', 'nguyenvana', 'vana@mxh.local', '$2a$10$7Qx.H5v9g7u8E9.r7yYxue/T1.j5h6a7b8c9d0e1f2g3h4i5j6k7l', 'Nguyễn Văn A', 'Yêu công nghệ và lập trình Polyglot', 'ROLE_USER')
ON CONFLICT (username) DO NOTHING;

-- Chèn 1 bài viết mẫu từ nguyen_van_a
INSERT INTO posts (id, user_id, content, privacy, likes_count, comments_count)
VALUES 
('c211de33-be2d-6ab0-dd8f-8dd1df502c33', 'b1ffcd00-ad1c-5fa9-cc7e-7cc0ce491b22', 'Chào mừng mọi người đến với Mạng Xã Hội Polyglot Microservices! Kiến trúc kết hợp Spring Boot, ASP.NET Core và Python AI.', 'PUBLIC', 1, 0)
ON CONFLICT (id) DO NOTHING;

-- Chèn 1 media mẫu cho bài viết
INSERT INTO post_media (id, post_id, media_url, media_type, display_order)
VALUES 
('d322ef44-cf3e-7bc1-ee9a-9ee2ef613d44', 'c211de33-be2d-6ab0-dd8f-8dd1df502c33', 'http://localhost:9000/mxh-media/sample-banner.jpg', 'IMAGE', 1)
ON CONFLICT (id) DO NOTHING;

-- Chèn 1 lượt like mẫu từ admin cho bài viết của nguyen_van_a
INSERT INTO likes (user_id, post_id)
VALUES 
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c211de33-be2d-6ab0-dd8f-8dd1df502c33')
ON CONFLICT DO NOTHING;
