# Dockerfile
FROM node:22 AS builder
WORKDIR /app
RUN git clone https://github.com/Claud-native/educloud.git .
RUN cp .env.example .env
RUN npm install
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]