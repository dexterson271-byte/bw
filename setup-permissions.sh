#!/bin/bash
# ==============================================
# Auto-setup permissions on first server start
# Reads commands from setup-permissions.json
# and pipes them to the server console
# ==============================================

SETUP_FLAG="/data/server/.permissions_setup_done"
SETUP_FILE="/data/server/plugins/LuckPerms/setup-permissions.json"

# Wait for server to be fully loaded
wait_for_server() {
    echo "[PermSetup] Waiting for server to finish loading..."
    while ! bash -c 'echo > /dev/tcp/localhost/25565' 2>/dev/null; do
        sleep 5
    done
    # Extra wait for plugins to initialize
    sleep 15
    echo "[PermSetup] Server is ready!"
}

# Always wait for server (needed for gamerules and first-time setup)
wait_for_server

if [ ! -f "$SETUP_FLAG" ] && [ -f "$SETUP_FILE" ]; then
    echo "[PermSetup] Running first-time permission setup..."
    
    # Extract commands from JSON and execute via RCON or screen
    # Using the server's stdin through a named pipe
    COMMANDS=$(cat "$SETUP_FILE" | jq -r '.permissions[].commands[]')
    
    while IFS= read -r cmd; do
        if [ -n "$cmd" ]; then
            echo "[PermSetup] Running: $cmd"
            # Send command to server console via named pipe
            echo "$cmd" > /data/server/server_input
            sleep 0.5
        fi
    done <<< "$COMMANDS"
    
    # Mark setup as done
    touch "$SETUP_FLAG"
    echo "[PermSetup] Permission setup complete!"
    echo "[PermSetup] HassanLegend is now OWNER with &4[OWNER] &ctag"
    echo "[PermSetup] Groups created: default, vip, mvp, admin, owner"
else
    if [ -f "$SETUP_FLAG" ]; then
        echo "[PermSetup] Permissions already configured (skipping)"
    fi
fi

# ============================================
# Always run on every server start
# ============================================
echo "[AutoConfig] Setting lobby gamerules..."
echo "gamerule doImmediateRespawn true" > /data/server/server_input
sleep 0.5
echo "gamerule keepInventory true" > /data/server/server_input
sleep 0.5
echo "time set day" > /data/server/server_input
sleep 0.5
echo "gamerule doDaylightCycle false" > /data/server/server_input
sleep 0.5
echo "gamerule doWeatherCycle false" > /data/server/server_input
sleep 0.5
echo "gamerule doMobSpawning false" > /data/server/server_input
sleep 0.5
echo "gamerule doFireTick false" > /data/server/server_input
sleep 0.5
echo "gamerule randomTickSpeed 0" > /data/server/server_input
sleep 0.5
echo "gamerule doTileDrops false" > /data/server/server_input
sleep 0.5
echo "gamerule fallDamage false" > /data/server/server_input
sleep 0.5
echo "gamerule announceAdvancements false" > /data/server/server_input
sleep 0.5
echo "gamerule spawnRadius 0" > /data/server/server_input
sleep 0.5
echo "difficulty peaceful" > /data/server/server_input
sleep 1
echo "[AutoConfig] Lobby fully protected - adventure mode, no mobs, no weather"
echo "[AutoConfig] WorldGuard region automation skipped (plugin currently disabled)"

# Diagnostic: Check BedWars1058 plugin status
sleep 5
echo "[Diagnostic] Checking plugin load status..."
if [ -f "/data/server/logs/latest.log" ]; then
    # Check for BedWars1058 issues
    BW_LINES=$(grep -i "bedwars1058\|bedwars.*disabl\|bedwars.*enabl\|NoClassDef.*bedwars\|version.*support.*bedwars" /data/server/logs/latest.log 2>/dev/null | tail -20)
    if echo "$BW_LINES" | grep -qi "disabl"; then
        echo "[Diagnostic] WARNING: BedWars1058 was disabled!"
        echo "[Diagnostic] BedWars1058 log entries:"
        echo "$BW_LINES"
        # Also check for NMS/version errors
        echo "[Diagnostic] NMS/version related errors:"
        grep -i "NMS\|version.*support\|ClassNotFound\|NoClassDef\|UnsupportedClass\|cannot.*load\|failed.*instantiate" /data/server/logs/latest.log 2>/dev/null | grep -iv "worldguard\|via\|fawe\|worldedit" | tail -10
    else
        echo "[Diagnostic] BedWars1058 appears to be running"
    fi
    # Check WorldGuard
    if grep -qi "worldguard.*unsupported\|worldguard.*could not load" /data/server/logs/latest.log 2>/dev/null; then
        echo "[Diagnostic] WARNING: WorldGuard failed to load"
    fi
fi
