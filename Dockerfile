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
ENV MINECRAFT_VERSION=1.20.6
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

# ViaVersion + ViaBackwards + ViaRewind - pre-built JARs in plugins/ folder
# Citizens, BedWars1058, Multiverse-Core, OldCombatMechanics - pre-built JARs in plugins/ folder
# WorldGuard, VaultChatFormatter, ChatFormatter - pre-built JARs in plugins/ folder

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

# spark - bundled with Purpur 1.20.6, no separate download needed

# FastAsyncWorldEdit (FAWE) - required by WorldGuard
RUN FAWE_URL=$(curl -s "https://api.github.com/repos/IntellectualSites/FastAsyncWorldEdit/releases/latest" | jq -r '.assets[] | select(.name | test("Bukkit")) | select(.name | endswith(".jar")) | .browser_download_url' | head -1) && \
    if [ -n "$FAWE_URL" ] && [ "$FAWE_URL" != "null" ]; then \
        curl -L -o plugins/FastAsyncWorldEdit.jar "$FAWE_URL"; \
    else \
        curl -L -o plugins/FastAsyncWorldEdit.jar "https://ci.athion.net/job/FastAsyncWorldEdit/lastSuccessfulBuild/artifact/artifacts/FastAsyncWorldEdit-Bukkit.jar"; \
    fi && \
    echo "FAWE downloaded"

# WorldGuard, VaultChatFormatter, Citizens - all pre-built JARs in plugins/ folder

# Validate all plugin JARs (remove corrupt/empty ones)
RUN for jar in plugins/*.jar; do \
        if [ ! -s "$jar" ]; then \
            echo "WARNING: Empty JAR detected, removing: $jar" && rm -f "$jar"; \
        elif ! unzip -tq "$jar" > /dev/null 2>&1; then \
            echo "WARNING: Corrupt JAR detected, removing: $jar" && rm -f "$jar"; \
        fi; \
    done && echo "All plugin JARs validated"

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
