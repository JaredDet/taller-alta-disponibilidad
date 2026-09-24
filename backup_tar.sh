#!/bin/bash

# ============================================================
# Respaldo completo con TAR
# Taller de Alta Disponibilidad
# ============================================================

set -u

DESTINO="/mnt/backups/tar"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HOST=$(hostname)

ARCHIVO="backup_completo_${HOST}_${TIMESTAMP}.tar.gz"
ARCHIVO_FINAL="${DESTINO}/${ARCHIVO}"
ARCHIVO_TEMP="/tmp/${ARCHIVO}"

LOG="${DESTINO}/backup_tar.log"
TMP_CONFIG=$(mktemp -d)

# Limpiar archivos temporales al finalizar
cleanup() {
    rm -rf "$TMP_CONFIG"
    rm -f "$ARCHIVO_TEMP"
}
trap cleanup EXIT

mkdir -p "$DESTINO"

# Toda la ejecución queda registrada en el log
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "INICIO RESPALDO TAR"
echo "Fecha: $(date)"
echo "Servidor: $HOST"
echo "Destino: $ARCHIVO_FINAL"
echo "============================================================"

# Guardar también la configuración actual de Pacemaker/PCS
echo "[1/4] Guardando configuración del clúster..."
sudo pcs config > "$TMP_CONFIG/pcs-config.txt"

# Crear respaldo completo temporal
echo "[2/4] Generando archivo TAR comprimido..."

sudo tar -czpf "$ARCHIVO_TEMP" \
    -C / \
    var/www/html \
    etc/nginx \
    etc/corosync \
    etc/hosts \
    home/node1/scripts-backup \
    -C "$TMP_CONFIG" \
    pcs-config.txt

# Como el archivo temporal fue creado por root, devolverlo a node1
sudo chown "$(id -u):$(id -g)" "$ARCHIVO_TEMP"

# Trasladarlo al almacenamiento NFS/RAID
echo "[3/4] Copiando respaldo al almacenamiento RAID..."
mv "$ARCHIVO_TEMP" "$ARCHIVO_FINAL"

echo "[4/4] Verificando respaldo..."

if tar -tzf "$ARCHIVO_FINAL" > /dev/null 2>&1; then
    echo "RESPALDO COMPLETADO CORRECTAMENTE"
    echo "Archivo: $ARCHIVO_FINAL"
    echo "Tamaño: $(du -h "$ARCHIVO_FINAL" | cut -f1)"
else
    echo "ERROR: el archivo generado no pudo ser validado."
    exit 1
fi

echo "Fecha de finalización: $(date)"
echo "============================================================"
