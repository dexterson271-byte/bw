# ==============================================
# BedWars Server - Railway Pro Optimized
# Purpur MC + BedWars1058 (Hypixel-Style)
# Auth: AuthMe + FastLogin (cracked + premium)
# Perms: LuckPerms + Vault (Owner/Admin tags)
# Extras: FileBrowser + Auto Backups
# ==============================================
# Stage 1: Get JRE
FROM eclipse-temurin:21-jre-alpine AS jre

# Stage 2: Main server
FROM alpine:3.20

# Copy JRE from temurin (without VOLUME directive)
COPY --from=jre /opt/java/openjdk /opt/java/openjdk

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

WORKDIR /server

# Install required packages (filebrowser for web file manager)
RUN apk add --no-cache curl bash jq tar gzip unzip && \
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Railway Pro: 8GB RAM, use 6G for Java (leave room for FileBrowser + OS)
ENV MINECRAFT_VERSION=1.20.4
ENV SERVER_PORT=25565
ENV MEMORY=6G
ENV MAX_MEMORY=6G
ENV FILEBROWSER_PORT=8080
ENV BACKUP_INTERVAL=30
ENV MAX_BACKUPS=10

# Download Purpur MC server (Paper fork with PvP/knockback tuning)
RUN PURPUR_URL="https://api.purpurmc.org/v2/purpur/${MINECRAFT_VERSION}/latest/download" && \
    curl -o server.jar "$PURPUR_URL" && \
    echo "Purpur downloaded for ${MINECRAFT_VERSION}"

# Create plugins directory
RUN mkdir -p plugins

# All plugins are pre-built JARs in the plugins/ folder (copied via COPY below)
# This avoids GitHub API rate limiting which previously caused corrupt downloads

# Validate all plugin JARs (remove corrupt/empty ones)
RUN echo "eula=true" > eula.txt

# Copy all configs
COPY server.properties spigot.yml bukkit.yml eula.txt ops.json ./
COPY config/ ./config/
COPY plugins/ ./plugins/
COPY world/ ./world/
COPY maps/arenas/ ./maps/arenas/

# Copy scripts
COPY entrypoint.sh backup.sh setup-permissions.sh ./
RUN chmod +x entrypoint.sh backup.sh setup-permissions.sh

# Expose Minecraft + FileBrowser ports
EXPOSE ${SERVER_PORT} ${FILEBROWSER_PORT}

# Railway volumes are configured in the dashboard (mount path: /data)
# Do NOT use VOLUME directive — Railway handles persistence via its own volume system

# Health check with generous startup time for Railway
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD bash -c 'echo > /dev/tcp/localhost/${SERVER_PORT}' || exit 1

# Use entrypoint script (handles backups + filebrowser + server)
ENTRYPOINT ["/server/entrypoint.sh"]
