# ==============================================
# BedWars Server - Railway Pro Optimized
# Paper MC + Screaming BedWars (Hypixel-Style)
# Auth: AuthMe + FastLogin (cracked + premium)
# Perms: LuckPerms + Vault (Owner/Admin tags)
# Extras: FileBrowser + Auto Backups
# ==============================================
FROM eclipse-temurin:21-jre-alpine

WORKDIR /server

# Install required packages (filebrowser for web file manager)
RUN apk add --no-cache curl bash jq tar gzip && \
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Railway Pro: 8GB RAM, use 6G for Java (leave room for FileBrowser + OS)
ENV MINECRAFT_VERSION=1.20.4
ENV SERVER_PORT=25565
ENV MEMORY=6G
ENV MAX_MEMORY=6G
ENV FILEBROWSER_PORT=8080
ENV BACKUP_INTERVAL=30
ENV MAX_BACKUPS=10

# Download Paper MC server (latest stable build)
RUN PAPER_BUILDS_URL="https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" && \
    LATEST_BUILD=$(curl -s "$PAPER_BUILDS_URL" | jq -r '.builds[-1].build') && \
    PAPER_JAR="paper-${MINECRAFT_VERSION}-${LATEST_BUILD}.jar" && \
    curl -o server.jar "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${LATEST_BUILD}/downloads/${PAPER_JAR}"

# Download required plugins automatically
# ProtocolLib - required by FastLogin
RUN PROTO_URL=$(curl -s "https://api.github.com/repos/dmulloy2/ProtocolLib/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url') && \
    curl -L -o plugins/ProtocolLib.jar "$PROTO_URL" && \
    echo "ProtocolLib downloaded"

# AuthMe - login/register for cracked players
RUN AUTH_URL=$(curl -s "https://api.github.com/repos/AuthMe/AuthMeReloaded/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url') && \
    curl -L -o plugins/AuthMe.jar "$AUTH_URL" && \
    echo "AuthMe downloaded"

# FastLogin - auto-login for premium players  
RUN FAST_URL=$(curl -s "https://api.github.com/repos/games647/FastLogin/releases/latest" | jq -r '.assets[] | select(.name | contains("bukkit") or contains("Bukkit")) | .browser_download_url' | head -1) && \
    if [ -n "$FAST_URL" ] && [ "$FAST_URL" != "null" ]; then \
        curl -L -o plugins/FastLogin.jar "$FAST_URL"; \
    else \
        FAST_URL=$(curl -s "https://api.github.com/repos/games647/FastLogin/releases/latest" | jq -r '.assets[0].browser_download_url') && \
        curl -L -o plugins/FastLogin.jar "$FAST_URL"; \
    fi && \
    echo "FastLogin downloaded"

# LuckPerms - permissions (owner/admin/vip ranks with tags)
RUN curl -L -o plugins/LuckPerms.jar \
    "https://download.luckperms.net/1549/bukkit/loader/LuckPerms-Bukkit-5.4.137.jar" && \
    echo "LuckPerms downloaded"

# Vault - economy/permissions API bridge
RUN VAULT_URL=$(curl -s "https://api.github.com/repos/MilkBowl/Vault/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url') && \
    curl -L -o plugins/Vault.jar "$VAULT_URL" && \
    echo "Vault downloaded"

RUN echo "eula=true" > eula.txt

# Copy all configs
COPY server.properties spigot.yml eula.txt ./
COPY config/ ./config/
COPY plugins/ ./plugins/

# Copy scripts
COPY entrypoint.sh backup.sh setup-permissions.sh ./
RUN chmod +x entrypoint.sh backup.sh setup-permissions.sh

# Expose Minecraft + FileBrowser ports
EXPOSE ${SERVER_PORT} ${FILEBROWSER_PORT}

# Volume for persistent data (backups, worlds, configs)
VOLUME ["/data"]

# Health check with generous startup time for Railway
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD bash -c 'echo > /dev/tcp/localhost/${SERVER_PORT}' || exit 1

# Use entrypoint script (handles backups + filebrowser + server)
ENTRYPOINT ["/server/entrypoint.sh"]
