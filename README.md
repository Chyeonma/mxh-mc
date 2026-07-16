# mxh-mc
# mxh-mc

[ Web App (React) ]             [ Mobile App (Android) ]
                 \                               /
                  \                             /  (HTTP/REST)
                   \                           /
                    v                         v
       +---------------------------------------------------+
       |          API Gateway (Nginx / Ocelot)             |
       +---------------------------------------------------+
                  |                               |
          (/auth/* request)               (/posts/* request)
                  |                               |
                  v                               v
       +--------------------+          +--------------------+        +--------------------+
       |    Auth Service    |          |    Post Service    | - - -> |     AI Service     |
       |    (Spring Boot)   |          |   (ASP.NET Core)   | (HTTP) |  (Python Dummy API)|
       +--------------------+          +--------------------+        +--------------------+
                  |                               |          \
                  |                               |           \ (Upload ảnh)
                  v                               v            v
       +---------------------------------------------------+ +--------------------+
       |              PostgreSQL (Central DB)              | |       MinIO        |
       |  [Bảng Users] | [Bảng Posts] | [Bảng Comments]    | |  (Object Storage)  |
       +---------------------------------------------------+ +--------------------+