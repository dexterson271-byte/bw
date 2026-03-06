#!/bin/bash
# ==============================================
# BedWars Server Entrypoint - Railway Pro
# Handles: Volume sync, Backups, File Manager, MC Server
# ==============================================
set -e

VOLUME_DIR="/data"
SERVER_DIR="${VOLUME_DIR}/server"
BACKUP_DIR="${VOLUME_DIR}/backups"
FILEBROWSER_DIR="${VOLUME_DIR}/filebrowser"
FILEBROWSER_PORT=${FILEBROWSER_PORT:-8080}

echo "=============================================="
echo "  BedWars Server - Railway Pro"
echo "  Auth + Backups + File Manager"
echo "=============================================="

# --- Setup volume directories ---
mkdir -p "$SERVER_DIR" "$BACKUP_DIR" "$FILEBROWSER_DIR"

# --- Sync server files to volume on first run ---
# This copies the built image files into the persistent volume
# On subsequent runs, the volume already has the files
if [ ! -f "${SERVER_DIR}/server.jar" ]; then
    echo "[Init] First run detected - copying server files to volume..."
    cp -rn /server/* "${SERVER_DIR}/" 2>/dev/null || true
    cp -r /server/plugins "${SERVER_DIR}/" 2>/dev/null || true
    cp -r /server/config "${SERVER_DIR}/" 2>/dev/null || true
    echo "[Init] Server files copied to persistent volume"
else
    echo "[Init] Existing server detected on volume"
    # Always update configs from image
    echo "[Init] Updating plugin configs from image..."
    cp -r /server/config/* "${SERVER_DIR}/config/" 2>/dev/null || true
    # Force update all plugins from image
    echo "[Init] Updating plugins from image..."
    cp -f /server/plugins/*.jar "${SERVER_DIR}/plugins/" 2>/dev/null || true
    # Force update plugin configs (WorldGuard regions, TAB, etc.)
    cp -rf /server/plugins/WorldGuard "${SERVER_DIR}/plugins/" 2>/dev/null || true
    cp -rf /server/plugins/TAB "${SERVER_DIR}/plugins/" 2>/dev/null || true
    cp -rf /server/plugins/VaultChatFormatter "${SERVER_DIR}/plugins/" 2>/dev/null || true
    cp -rn /server/plugins/*/ "${SERVER_DIR}/plugins/" 2>/dev/null || true
fi

# Ensure eula is accepted
echo "eula=true" > "${SERVER_DIR}/eula.txt"

# Merge ops.json - preserve existing ops (admins etc) while ensuring HassanLegend stays opped
if [ -f "${SERVER_DIR}/ops.json" ]; then
    echo "[Init] Merging ops.json (preserving existing ops)..."
    jq -s 'flatten | unique_by(.uuid)' "${SERVER_DIR}/ops.json" /server/ops.json > /tmp/ops_merged.json 2>/dev/null && \
        mv /tmp/ops_merged.json "${SERVER_DIR}/ops.json" || \
        echo "[Init] ops.json merge failed, keeping existing"
else
    cp /server/ops.json "${SERVER_DIR}/ops.json"
fi

# Always update server.properties from image
cp -f /server/server.properties "${SERVER_DIR}/server.properties" 2>/dev/null || true

# Copy lobby world - preserve level.dat (gamerules) on restarts
if [ -d /server/world ]; then
    mkdir -p "${SERVER_DIR}/world"
    if [ ! -f "${SERVER_DIR}/world/level.dat" ]; then
        echo "[Init] First run - copying full lobby world..."
        cp -r /server/world/* "${SERVER_DIR}/world/" 2>/dev/null || true
    else
        echo "[Init] Updating lobby (preserving gamerules)..."
        cp -r /server/world/region "${SERVER_DIR}/world/" 2>/dev/null || true
        cp -r /server/world/entities "${SERVER_DIR}/world/" 2>/dev/null || true
        cp -r /server/world/poi "${SERVER_DIR}/world/" 2>/dev/null || true
    fi
    echo "[Init] Lobby world synced"
fi

# Copy arena maps (each map = separate world folder)
if [ -d /server/maps/arenas ]; then
    echo "[Init] Copying BedWars arena maps..."
    for MAP_DIR in /server/maps/arenas/*/; do
        MAP_NAME=$(basename "$MAP_DIR")
        if [ ! -d "${SERVER_DIR}/${MAP_NAME}" ]; then
            echo "[Init] Copying arena: ${MAP_NAME}"
            cp -r "$MAP_DIR" "${SERVER_DIR}/${MAP_NAME}"
        else
            echo "[Init] Arena ${MAP_NAME} already exists (skipping)"
        fi
    done
    echo "[Init] Arena maps synced"
fi

# --- Start File Manager (FileBrowser) ---
echo "[FileBrowser] Starting web file manager on port ${FILEBROWSER_PORT}..."
mkdir -p "${FILEBROWSER_DIR}"

# Create filebrowser config if it doesn't exist
if [ ! -f "${FILEBROWSER_DIR}/filebrowser.db" ]; then
    echo "[FileBrowser] First run - creating admin account..."
    filebrowser config init --database "${FILEBROWSER_DIR}/filebrowser.db" 2>/dev/null || true
    filebrowser config set \
        --database "${FILEBROWSER_DIR}/filebrowser.db" \
        --address "0.0.0.0" \
        --port "${FILEBROWSER_PORT}" \
        --root "${VOLUME_DIR}" \
        --auth.method=json \
        --branding.name="BedWars Server Files" 2>/dev/null || true
    filebrowser users add admin admin \
        --database "${FILEBROWSER_DIR}/filebrowser.db" \
        --perm.admin 2>/dev/null || true
    echo "[FileBrowser] Admin account created (user: admin, pass: admin)"
    echo "[FileBrowser] CHANGE THE PASSWORD after first login!"
fi

filebrowser \
    --database "${FILEBROWSER_DIR}/filebrowser.db" \
    --address "0.0.0.0" \
    --port "${FILEBROWSER_PORT}" \
    --root "${VOLUME_DIR}" &
FILEBROWSER_PID=$!
echo "[FileBrowser] Running (PID: ${FILEBROWSER_PID})"

# --- Start Backup Daemon ---
echo "[Backup] Starting backup daemon..."
/server/backup.sh &
BACKUP_PID=$!
echo "[Backup] Running (PID: ${BACKUP_PID})"

# --- Create named pipe for server console input ---
SERVER_INPUT="${SERVER_DIR}/server_input"
rm -f "$SERVER_INPUT"
mkfifo "$SERVER_INPUT"

# --- Start Permission Setup (runs after server loads) ---
echo "[PermSetup] Scheduling permission setup..."
/server/setup-permissions.sh &
PERM_PID=$!
echo "[PermSetup] Scheduled (PID: ${PERM_PID})"

# --- Start Minecraft Server ---
cd "${SERVER_DIR}"
echo "[Server] Starting BedWars server with ${MEMORY} RAM..."

# Use tail to keep the pipe open, feed both pipe and stdin to the server
tail -f "$SERVER_INPUT" | java \
    -Xms${MEMORY} \
    -Xmx${MAX_MEMORY} \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UnlockDiagnosticVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=40 \
    -XX:G1MaxNewSizePercent=50 \
    -XX:G1HeapRegionSize=16M \
    -XX:G1ReservePercent=15 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=20 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -XX:+UseCompressedOops \
    -XX:+OptimizeStringConcat \
    -XX:+UseStringDeduplication \
    -XX:+UseNUMA \
    -XX:+ExitOnOutOfMemoryError \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -Dpaper.playerconnection.keepalive=120 \
    -Dpaper.maxCustomChannelName=64 \
    -Dio.netty.allocator.maxOrder=9 \
    -Dio.netty.selectorAutoRebuildThreshold=0 \
    -jar server.jar \
    --nogui \
    --port ${SERVER_PORT}
