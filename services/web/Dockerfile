# Dockerfile
FROM node:22 AS builder
WORKDIR /app
RUN git clone https://github.com/Claud-native/educloud.git .

# Crear .env con las variables necesarias
RUN echo 'VITE_API_BASE_URL=__VITE_API_BASE_URL__' > .env && \
    echo 'VITE_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----' >> .env && \
    echo 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0QFwed5G4KLpGKa9a4GQ' >> .env && \
    echo 'RZrxRffPBF6yPNrNG5p6wg36CQM8IsoJ5Hwdgq82XPVk9jn1QR4zYbZMIw30TDeH' >> .env && \
    echo '+jAcGA2YO6YxPHpa0zvlaE/45wuXUNHhUM07uOP1xowbRyHAAuzYdV1jkTMdCjn9' >> .env && \
    echo 'fJPP0F796iF5aRs4nxXUF5cVqDUUIlJwBJMa3q2h4lQ+3FGILJBhJzUKk6oRaAvZ' >> .env && \
    echo 'uEs1ndz+ugLVC1kDwOLG5qRT/zcnPsITVLeWkJ0DXLWqQWlLqlugEJ0ncPON4CuU' >> .env && \
    echo 'n0yobbJ8aiL/Ymu8FF7DzN1GILL4kGD6Pc/iPvfWdBUDSuhMLGuXyR/CzLy304j1' >> .env && \
    echo 'fQIDAQAB' >> .env && \
    echo '-----END PUBLIC KEY-----"' >> .env && \
    echo 'VITE_AES_SECRET_KEY=almi-dev-key-2024' >> .env && \
    echo 'VITE_APP_NAME="EduCloud Platform"' >> .env && \
    echo 'VITE_APP_VERSION=1.0.0' >> .env && \
    echo 'VITE_APP_ENV=production' >> .env && \
    echo 'VITE_ENABLE_HEALTH_CHECK=true' >> .env && \
    echo 'VITE_DEBUG_MODE=false' >> .env

RUN npm install
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html

# Script para reemplazar la URL de la API en runtime
RUN printf '#!/bin/sh\n\
set -e\n\
echo "Replacing API URL with: ${VITE_API_BASE_URL}"\n\
find /usr/share/nginx/html -type f -name "*.js" -exec sed -i "s|__VITE_API_BASE_URL__|${VITE_API_BASE_URL}|g" {} \\;\n\
echo "API URL replacement completed"\n' > /docker-entrypoint.d/40-replace-api-url.sh && \
    chmod +x /docker-entrypoint.d/40-replace-api-url.sh

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]