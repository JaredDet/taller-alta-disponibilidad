#!/bin/bash

# ============================================================
# Respaldo incremental con RSYNC
# Taller de Alta Disponibilidad
# ============================================================

set -u

ORIGEN_WEB="/var/www/html/"
ORIGEN_SCRIPTS="$HOME/scripts-backup/"

BASE="/mnt/backups/rsync"
SNAPSHOTS="$BASE/snapshots"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DESTINO="$SNAPSHOTS/$TIMESTAMP"

LOG="$BASE/backup_rsync.log"

mkdir -p "$SNAPSHOTS"
mkdir -p "$DESTINO/www"
mkdir -p "$DESTINO/scripts"

exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "INICIO RESPALDO RSYNC"
echo "Fecha: $(date)"
echo "Servidor: $(hostname)"
echo "Snapshot: $DESTINO"
echo "============================================================"

# Buscar snapshot anterior, excluyendo el que acabamos de crear
ANTERIOR=$(find "$SNAPSHOTS" \
    -mindepth 1 -maxdepth 1 -type d \
    ! -path "$DESTINO" \
    | sort | tail -n 1)

if [ -n "$ANTERIOR" ]; then
    echo "Tipo: INCREMENTAL"
    echo "Snapshot anterior: $ANTERIOR"

    LINK_WEB=(--link-dest="$ANTERIOR/www")
    LINK_SCRIPTS=(--link-dest="$ANTERIOR/scripts")
else
    echo "Tipo: RESPALDO INICIAL"
    echo "No existe snapshot anterior."

    LINK_WEB=()
    LINK_SCRIPTS=()
fi

echo
echo "[1/2] Sincronizando contenido web..."

rsync -avh \
    --itemize-changes \
    --stats \
    --exclude='*.tmp' \
    --exclude='*.swp' \
    --exclude='*.log' \
    "${LINK_WEB[@]}" \
    "$ORIGEN_WEB" \
    "$DESTINO/www/"

echo
echo "[2/2] Sincronizando scripts..."

rsync -avh \
    --itemize-changes \
    --stats \
    --exclude='*.tmp' \
    --exclude='*.swp' \
    --exclude='*.log' \
    "${LINK_SCRIPTS[@]}" \
    "$ORIGEN_SCRIPTS" \
    "$DESTINO/scripts/"

echo
echo "RESPALDO RSYNC COMPLETADO CORRECTAMENTE"
echo "Snapshot generado: $DESTINO"
echo "Fecha de finalización: $(date)"
echo "============================================================"
