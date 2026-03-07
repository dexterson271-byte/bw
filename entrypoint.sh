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
# Remove old Screaming BedWars from volume if it exists (replaced by BedWars1058)
rm -f "${SERVER_DIR}/plugins/BedWars-"*.jar 2>/dev/null || true
# Remove old BedWars data folder (Screaming BedWars uses "BedWars" folder, BedWars1058 uses "BedWars1058")
rm -rf "${SERVER_DIR}/plugins/BedWars" 2>/dev/null || true
# Remove BedWarsProxy (incompatible with MULTIARENA mode)
rm -f "${SERVER_DIR}/plugins/BedWarsProxy.jar" 2>/dev/null || true
rm -rf "${SERVER_DIR}/plugins/BedWarsProxy" 2>/dev/null || true
# Remove all Citizens JARs from volume (Citizens crashes the server on 1.20.4)
rm -f "${SERVER_DIR}/plugins/Citizens"*.jar 2>/dev/null || true
# Remove stale FAWE from volume (we use standard WorldEdit now)
rm -f "${SERVER_DIR}/plugins/FastAsyncWorldEdit.jar" 2>/dev/null || true
# Remove TAB plugin from volume (intentionally disabled)
rm -f "${SERVER_DIR}/plugins/TAB.jar" 2>/dev/null || true
rm -rf "${SERVER_DIR}/plugins/TAB" 2>/dev/null || true

# Always force-update server.jar from image (ensures version upgrades take effect)
cp -f /server/server.jar "${SERVER_DIR}/server.jar" 2>/dev/null || true
echo "[Init] server.jar updated from image"

# On subsequent runs, the volume already has the files
if [ ! -f "${SERVER_DIR}/eula.txt" ]; then
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
    # Remove old Screaming BedWars plugin (replaced by BedWars1058)
    rm -f "${SERVER_DIR}/plugins/BedWars-"*.jar 2>/dev/null || true
    rm -f "${SERVER_DIR}/plugins/BedWars1058-"*.jar 2>/dev/null || true
    # Remove corrupt/empty JARs from volume before copying new ones
    echo "[Init] Validating existing plugin JARs on volume..."
    for jar in "${SERVER_DIR}/plugins/"*.jar; do
        [ -f "$jar" ] || continue
        if [ ! -s "$jar" ]; then
            echo "[Init] Removing empty JAR: $(basename "$jar")"
            rm -f "$jar"
        elif ! unzip -tq "$jar" > /dev/null 2>&1; then
            echo "[Init] Removing corrupt JAR: $(basename "$jar")"
            rm -f "$jar"
        fi
    done
    # Force update all plugins from image
    echo "[Init] Updating plugins from image..."
    cp -f /server/plugins/*.jar "${SERVER_DIR}/plugins/" 2>/dev/null || true
    # Force update plugin configs
    cp -rf /server/plugins/WorldGuard "${SERVER_DIR}/plugins/" 2>/dev/null || true
    cp -rf /server/plugins/VaultChatFormatter "${SERVER_DIR}/plugins/" 2>/dev/null || true
    cp -rf /server/plugins/BedWars1058 "${SERVER_DIR}/plugins/" 2>/dev/null || true
    cp -rn /server/plugins/*/ "${SERVER_DIR}/plugins/" 2>/dev/null || true
    # Re-enforce TAB removal in case stale data exists on volume.
    rm -f "${SERVER_DIR}/plugins/TAB.jar" 2>/dev/null || true
    rm -rf "${SERVER_DIR}/plugins/TAB" 2>/dev/null || true
fi

# Clear Paper's plugin remapping cache (force fresh remap after version/jar changes)
rm -rf "${SERVER_DIR}/plugins/.paper-remapped" 2>/dev/null || true
echo "[Init] Paper plugin remap cache cleared"

# Keep BedWars1058 runtime data on volume to preserve lobby/arena config.
if [ ! -d "${SERVER_DIR}/plugins/BedWars1058" ] && [ -d /server/plugins/BedWars1058 ]; then
    cp -rf /server/plugins/BedWars1058 "${SERVER_DIR}/plugins/" 2>/dev/null || true
    echo "[Init] BedWars1058 base data copied (first run only)"
fi

# Ensure BedWars1058 uses MULTIARENA mode (not BUNGEE)
if [ -f "${SERVER_DIR}/plugins/BedWars1058/config.yml" ]; then
    sed -i 's/^serverType:.*/serverType: MULTIARENA/' "${SERVER_DIR}/plugins/BedWars1058/config.yml"
    echo "[Init] BedWars1058 serverType forced to MULTIARENA"
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
cp -f /server/bukkit.yml "${SERVER_DIR}/bukkit.yml" 2>/dev/null || true
cp -f /server/spigot.yml "${SERVER_DIR}/spigot.yml" 2>/dev/null || true

# Enforce single-lobby world mode on every boot
sed -i 's/^allow-nether=.*/allow-nether=false/' "${SERVER_DIR}/server.properties" 2>/dev/null || true
sed -i 's/^level-name=.*/level-name=world/' "${SERVER_DIR}/server.properties" 2>/dev/null || true
sed -i 's/^  allow-end:.*/  allow-end: false/' "${SERVER_DIR}/bukkit.yml" 2>/dev/null || true

# One-time safe migration to lobby template with backup.
# Afterwards preserve lobby world and only remove nether/end folders.
if [ -d /server/world ]; then
    LOBBY_MIGRATION_FLAG="${SERVER_DIR}/.lobby_world_migrated"
    if [ ! -f "${LOBBY_MIGRATION_FLAG}" ]; then
        TS=$(date +%Y%m%d-%H%M%S)
        mkdir -p "${BACKUP_DIR}/world-migration-${TS}"
        cp -r "${SERVER_DIR}/world" "${BACKUP_DIR}/world-migration-${TS}/" 2>/dev/null || true
        cp -r "${SERVER_DIR}/world_nether" "${BACKUP_DIR}/world-migration-${TS}/" 2>/dev/null || true
        cp -r "${SERVER_DIR}/world_the_end" "${BACKUP_DIR}/world-migration-${TS}/" 2>/dev/null || true
        rm -rf "${SERVER_DIR}/world" "${SERVER_DIR}/world_nether" "${SERVER_DIR}/world_the_end" 2>/dev/null || true
        mkdir -p "${SERVER_DIR}/world"
        cp -r /server/world/* "${SERVER_DIR}/world/" 2>/dev/null || true
        rm -f "${SERVER_DIR}/world/paper-world"*.yml 2>/dev/null || true
        touch "${LOBBY_MIGRATION_FLAG}"
        echo "[Init] Lobby world migrated from image with backup: world-migration-${TS}"
    else
        rm -rf "${SERVER_DIR}/world_nether" "${SERVER_DIR}/world_the_end" 2>/dev/null || true
        echo "[Init] Lobby world preserved (nether/end removed)"
    fi
fi

# Disable accidentally imported worlds on the volume (e.g. /mv import).
# Keep only lobby world and configured BedWars arena worlds.
ALLOWED_WORLDS=" world "
if [ -d /server/maps/arenas ]; then
    for MAP_DIR in /server/maps/arenas/*/; do
        [ -d "$MAP_DIR" ] || continue
        ALLOWED_WORLDS="${ALLOWED_WORLDS}$(basename "$MAP_DIR") "
    done
fi
TS=$(date +%Y%m%d-%H%M%S)
DISABLED_WORLDS_DIR="${BACKUP_DIR}/disabled-worlds-${TS}"
for CANDIDATE in "${SERVER_DIR}"/*; do
    [ -d "$CANDIDATE" ] || continue
    WORLD_NAME=$(basename "$CANDIDATE")
    if [ -f "$CANDIDATE/level.dat" ]; then
        case " ${ALLOWED_WORLDS} " in
            *" ${WORLD_NAME} "*) ;;
            *)
                mkdir -p "$DISABLED_WORLDS_DIR"
                mv "$CANDIDATE" "$DISABLED_WORLDS_DIR/" 2>/dev/null || true
                echo "[Init] Disabled unexpected world: ${WORLD_NAME}"
                ;;
        esac
    fi
done

# Reset Multiverse world registry on boot so only the lobby world is auto-loaded.
# This prevents stale imports (e.g. older/newer-version maps) from forcing chunk loads at startup.
MV_WORLD_FILE="${SERVER_DIR}/plugins/Multiverse-Core/worlds.yml"
if [ -f "${MV_WORLD_FILE}" ]; then
    TS=$(date +%Y%m%d-%H%M%S)
    cp "${MV_WORLD_FILE}" "${BACKUP_DIR}/multiverse-worlds-${TS}.yml" 2>/dev/null || true
    rm -f "${MV_WORLD_FILE}" 2>/dev/null || true
    echo "[Init] Multiverse worlds.yml reset (backup: multiverse-worlds-${TS}.yml)"
fi

# Copy arena maps (each map = separate world folder)
# BedWars1058 requires lowercase folder names
if [ -d /server/maps/arenas ]; then
    echo "[Init] Copying BedWars arena maps..."
    # Remove old uppercase arena folders from volume (replaced by lowercase)
    for OLD_DIR in "${SERVER_DIR}"/*/; do
        DIR_NAME=$(basename "$OLD_DIR")
        LOWER_NAME=$(echo "$DIR_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_')
        if [ "$DIR_NAME" != "$LOWER_NAME" ] && [ -d "/server/maps/arenas/${LOWER_NAME}" ]; then
            echo "[Init] Removing old uppercase arena: ${DIR_NAME} (replaced by ${LOWER_NAME})"
            rm -rf "$OLD_DIR"
        fi
    done
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

# Always recreate filebrowser DB to ensure correct credentials
rm -f "${FILEBROWSER_DIR}/filebrowser.db"
echo "[FileBrowser] Creating fresh admin account..."
filebrowser config init --database "${FILEBROWSER_DIR}/filebrowser.db" > /dev/null 2>&1 || true
filebrowser config set \
    --database "${FILEBROWSER_DIR}/filebrowser.db" \
    --address "0.0.0.0" \
    --port "${FILEBROWSER_PORT}" \
    --root "${VOLUME_DIR}" \
    --auth.method=json \
    --branding.name="BedWars Server Files" > /dev/null 2>&1 || true
filebrowser users add admin adminadmin123 \
    --database "${FILEBROWSER_DIR}/filebrowser.db" \
    --perm.admin || echo "[FileBrowser] WARNING: Failed to create admin user"
echo "[FileBrowser] Admin account created (user: admin, pass: adminadmin123)"

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

# --- Graceful Shutdown Handler ---
# When Railway sends SIGTERM (redeploy/restart), tell the MC server to stop
# so all plugins (Citizens NPCs, etc.) save their data before exiting
graceful_shutdown() {
    echo "[Server] Received shutdown signal, stopping server gracefully..."
    echo "stop" > "$SERVER_INPUT"
    # Wait up to 25 seconds for the server to save and exit
    local count=0
    while kill -0 $SERVER_PID 2>/dev/null && [ $count -lt 25 ]; do
        sleep 1
        count=$((count + 1))
    done
    echo "[Server] Cleanup complete, exiting"
    kill $FILEBROWSER_PID $BACKUP_PID 2>/dev/null || true
    exit 0
}

# --- Start Minecraft Server ---
cd "${SERVER_DIR}"
echo "[Server] Starting BedWars server with ${MEMORY} RAM..."

# Start tail feeder + Java server as a pipeline in background
(tail -f "$SERVER_INPUT" | java \
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
    --port ${SERVER_PORT}) &
SERVER_PID=$!

trap graceful_shutdown SIGTERM SIGINT

echo "[Server] PID: ${SERVER_PID}, waiting for exit..."
wait $SERVER_PID
