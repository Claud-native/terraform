# ===================================
# EduCloud Backend - Production Dockerfile
# Clona código desde GitHub y construye
# ===================================

# Stage 1: Build
FROM gradle:8.14-jdk17-alpine AS builder
WORKDIR /build

# Instalar git
RUN apk add --no-cache git

# Clonar repositorio
RUN git clone https://github.com/Claud-native/educloudbackend.git app

# Cambiar al directorio de la app
WORKDIR /build/app

# Copiar .env.example a .env (para build)
RUN cp .env.example .env || echo "No .env.example found, skipping"

# Build JAR (sin tests para producción)
RUN chmod +x ./gradlew && ./gradlew clean bootJar --no-daemon -x test

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Instalar curl para health checks
RUN apk add --no-cache curl

# Crear usuario no-root para seguridad
RUN addgroup -g 1001 -S appuser && \
    adduser -u 1001 -S appuser -G appuser

# Copiar JAR desde stage builder
COPY --from=builder /build/app/build/libs/*.jar app.jar

# Cambiar ownership de archivos
RUN chown -R appuser:appuser /app

# Cambiar a usuario no-root
USER appuser

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/api/health || exit 1

# Ejecutar aplicación con configuración optimizada
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+UseG1GC", \
  "-XX:MaxGCPauseMillis=200", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", \
  "app.jar"]
