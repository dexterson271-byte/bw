#!/bin/bash
# ==============================================
# Automated Backup Script for BedWars Server
# Runs every BACKUP_INTERVAL minutes
# Stores backups in /data/backups/
# ==============================================

BACKUP_DIR="/data/backups"
SERVER_DIR="/data/server"
MAX_BACKUPS=${MAX_BACKUPS:-10}
BACKUP_INTERVAL=${BACKUP_INTERVAL:-30}

mkdir -p "$BACKUP_DIR"

echo "[Backup] Starting backup daemon (every ${BACKUP_INTERVAL} minutes, keeping ${MAX_BACKUPS} backups)"

while true; do
    sleep "${BACKUP_INTERVAL}m"
    
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.tar.gz"
    
    echo "[Backup] Creating backup: ${BACKUP_FILE}"
    
    # Backup important server data (not jars or cache)
    tar -czf "$BACKUP_FILE" \
        -C "$SERVER_DIR" \
        --exclude='*.jar' \
        --exclude='cache' \
        --exclude='libraries' \
        --exclude='versions' \
        --exclude='logs/*.log.gz' \
        --exclude='bundler' \
        plugins/ \
        world/ \
        server.properties \
        spigot.yml \
        config/ \
        eula.txt \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        echo "[Backup] Backup created successfully (${SIZE})"
    else
        echo "[Backup] Warning: Some files may not exist yet, partial backup saved"
    fi
    
    # Rotate old backups - keep only MAX_BACKUPS most recent
    BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        DELETE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
        echo "[Backup] Rotating: removing ${DELETE_COUNT} old backup(s)"
        ls -1t "${BACKUP_DIR}"/backup_*.tar.gz | tail -n "$DELETE_COUNT" | xargs rm -f
    fi
    
    echo "[Backup] Next backup in ${BACKUP_INTERVAL} minutes"
done
