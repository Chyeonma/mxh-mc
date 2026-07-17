# Multi-stage build cho Spring Boot AuthServer
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
# Cài maven wrapper hoặc dùng mvn (nếu có trong image) - ở đây dùng image có maven hoặc build bằng maven image
FROM maven:3.9.6-eclipse-temurin-17-alpine AS maven_builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Run stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=maven_builder /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
