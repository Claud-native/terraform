# Usa una imagen base de Debian
FROM debian:bullseye-slim

# Establece el directorio de trabajo
WORKDIR /root

# Instala las dependencias necesarias
RUN apt-get update && \
    apt-get install -y \
    curl \
    iproute2 \
    iputils-ping \
    lsb-release \
    sudo \
    wireguard-tools \
    && rm -rf /var/lib/apt/lists/*

# Descarga el script de instalación de WireGuard
RUN curl -O https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh \
    && chmod +x wireguard-install.sh

# Establece el punto de entrada para ejecutar el script
ENTRYPOINT ["./wireguard-install.sh"]
