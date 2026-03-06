# ==============================================
# BedWars Server - Railway Pro Optimized
# Paper MC + Screaming BedWars (Hypixel-Style)
# Auth: AuthMe + FastLogin (cracked + premium)
# Perms: LuckPerms + Vault (Owner/Admin tags)
# Extras: FileBrowser + Auto Backups
# ==============================================
# Multi-stage build to strip VOLUME from base image (Railway bans VOLUME)
FROM eclipse-temurin:21-jre-alpine AS jre
FROM alpine:3.20

# Copy JRE from temurin (without VOLUME directive)
COPY --from=jre /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

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
RUN mkdir -p plugins

# ProtocolLib - required by FastLogin
RUN PROTO_URL=$(curl -s "https://api.github.com/repos/dmulloy2/ProtocolLib/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url') && \
    curl -L -o plugins/ProtocolLib.jar "$PROTO_URL" && \
    echo "ProtocolLib downloaded"

# AuthMe - login/register for cracked players
RUN AUTH_URL=$(curl -s "https://api.github.com/repos/AuthMe/AuthMeReloaded/releases/latest" | jq -r '[.assets[] | select(.name | endswith(".jar")) | select(.name | test("source|javadoc";"i") | not)][0].browser_download_url') && \
    if [ -n "$AUTH_URL" ] && [ "$AUTH_URL" != "null" ]; then \
        curl -L -o plugins/AuthMe.jar "$AUTH_URL"; \
    else \
        AUTH_URL=$(curl -s "https://api.github.com/repos/AuthMe/AuthMeReloaded/releases/latest" | jq -r '.assets[0].browser_download_url') && \
        curl -L -o plugins/AuthMe.jar "$AUTH_URL"; \
    fi && \
    echo "AuthMe downloaded"

# FastLogin - auto-login for premium players (TuxCoding fork)
RUN FAST_URL=$(curl -s "https://api.github.com/repos/TuxCoding/FastLogin/releases/latest" | jq -r '.assets[] | select(.name == "FastLoginBukkit.jar") | .browser_download_url') && \
    if [ -n "$FAST_URL" ] && [ "$FAST_URL" != "null" ]; then \
        curl -L -o plugins/FastLogin.jar "$FAST_URL"; \
    else \
        curl -L -o plugins/FastLogin.jar "https://github.com/TuxCoding/FastLogin/releases/download/1.12-kick-toggle/FastLoginBukkit.jar"; \
    fi && \
    echo "FastLogin downloaded"

# LuckPerms - permissions (owner/admin/vip ranks with tags)
RUN curl -L -o plugins/LuckPerms.jar \
    "https://download.luckperms.net/1624/bukkit/loader/LuckPerms-Bukkit-5.5.36.jar" && \
    ls -la plugins/LuckPerms.jar && \
    echo "LuckPerms downloaded"

# Vault - economy/permissions API bridge
RUN VAULT_URL=$(curl -s "https://api.github.com/repos/MilkBowl/Vault/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url') && \
    curl -L -o plugins/Vault.jar "$VAULT_URL" && \
    echo "Vault downloaded"

# ViaVersion + ViaBackwards + ViaRewind - allow 1.8.x to 1.20.x clients to join
RUN VIA_URL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url' | head -1) && \
    curl -L -o plugins/ViaVersion.jar "$VIA_URL" && \
    echo "ViaVersion downloaded"

RUN VIAB_URL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaBackwards/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url' | head -1) && \
    curl -L -o plugins/ViaBackwards.jar "$VIAB_URL" && \
    echo "ViaBackwards downloaded"

RUN VIAR_URL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaRewind/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url' | head -1) && \
    curl -L -o plugins/ViaRewind.jar "$VIAR_URL" && \
    echo "ViaRewind downloaded"

# SkinsRestorer - show skins in offline-mode server
RUN SR_URL=$(curl -s "https://api.github.com/repos/SkinsRestorer/SkinsRestorer/releases/latest" | jq -r '.assets[] | select(.name == "SkinsRestorer.jar") | .browser_download_url') && \
    if [ -n "$SR_URL" ] && [ "$SR_URL" != "null" ]; then \
        curl -L -o plugins/SkinsRestorer.jar "$SR_URL"; \
    else \
        curl -L -o plugins/SkinsRestorer.jar "https://github.com/SkinsRestorer/SkinsRestorer/releases/latest/download/SkinsRestorer.jar"; \
    fi && \
    echo "SkinsRestorer downloaded"

# TAB - tab list formatting with rank prefixes and nametags
RUN TAB_URL=$(curl -s "https://api.github.com/repos/NEZNAMY/TAB/releases/latest" | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url' | head -1) && \
    curl -L -o plugins/TAB.jar "$TAB_URL" && \
    echo "TAB downloaded"

# VaultChatFormatter - chat formatting with rank prefixes from LuckPerms/Vault
RUN VCF_URL=$(curl -s "https://api.github.com/repos/Vankka/VaultChatFormatter/releases/latest" | jq -r '.assets[]? | select(.name | endswith(".jar")) | .browser_download_url' | head -1) && \
    if [ -n "$VCF_URL" ] && [ "$VCF_URL" != "null" ]; then \
        curl -L -o plugins/VaultChatFormatter.jar "$VCF_URL"; \
    else \
        curl -L -o plugins/VaultChatFormatter.jar "https://github.com/Vankka/VaultChatFormatter/releases/download/v1.0.1/VaultChatFormatter-1.0.1.jar"; \
    fi && \
    echo "VaultChatFormatter downloaded"

RUN echo "eula=true" > eula.txt

# Copy all configs
COPY server.properties spigot.yml eula.txt ops.json ./
COPY config/ ./config/
COPY plugins/ ./plugins/
COPY world/ ./world/

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
