graph TD
    %% Khai báo các phân hệ (Subgraphs)
    subgraph ClientLayer [Lớp Giao Diện - Frontend]
        W[Web App - React]
        M[Mobile App - Android]
    end

    subgraph GatewayLayer [Lớp Cửa Ngõ - Định Tuyến]
        GW(API Gateway - Nginx / Ocelot)
    end

    subgraph LogicLayer [Lớp Nghiệp Vụ - Backend]
        AUTH[Auth Service - Spring Boot]
        POST[Post Service - ASP.NET Core]
        AI[AI Service - Python Dummy API]
    end

    subgraph DataLayer [Lớp Lưu Trữ - Database & Storage]
        DB[(PostgreSQL - Central DB)]
        S3[(MinIO - Object Storage)]
    end

    %% Định nghĩa luồng dữ liệu (Connections)
    W -->|HTTP/REST| GW
    M -->|HTTP/REST| GW

    GW -->|Định tuyến: /auth/*| AUTH
    GW -->|Định tuyến: /posts/*| POST

    %% Liên kết giữa các service
    POST -.->|Gọi API lấy ID bài viết gợi ý| AI

    %% Liên kết xuống DB
    AUTH -->|Truy vấn User| DB
    POST -->|Lưu/Đọc nội dung bài viết| DB
    POST -->|Lưu file ảnh, lấy URL| S3

    %% Tùy chỉnh màu sắc cơ bản (Tùy chọn)
    classDef client fill:#3498db,stroke:#2980b9,stroke-width:2px,color:#fff;
    classDef gateway fill:#f39c12,stroke:#e67e22,stroke-width:2px,color:#fff;
    classDef service fill:#2ecc71,stroke:#27ae60,stroke-width:2px,color:#fff;
    classDef storage fill:#9b59b6,stroke:#8e44ad,stroke-width:2px,color:#fff;

    class W,M client;
    class GW gateway;
    class AUTH,POST,AI service;
    class DB,S3 storage;