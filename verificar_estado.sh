#!/bin/bash

# ============================================================
# Verificación automática de disponibilidad
# Taller de Alta Disponibilidad
# ============================================================

VIP="192.168.1.50"
URL="http://${VIP}"

WEB="/srv/datos/www"
LOG="/srv/datos/logs/verificacion_portal.log"

ESTADO_HTML="${WEB}/estado.html"
ESTADO_TXT="${WEB}/estado.txt"

TMP_HEADERS=$(mktemp)
TMP_HTML=$(mktemp)
TMP_TXT=$(mktemp)

cleanup() {
    rm -f "$TMP_HEADERS" "$TMP_HTML" "$TMP_TXT"
}

trap cleanup EXIT

FECHA=$(date '+%Y-%m-%d %H:%M:%S')

# ------------------------------------------------------------
# 1. Validar el portal mediante CURL
# ------------------------------------------------------------

HTTP_CODE=$(curl \
    --silent \
    --show-error \
    --connect-timeout 3 \
    --max-time 5 \
    --dump-header "$TMP_HEADERS" \
    --output /dev/null \
    --write-out "%{http_code}" \
    "$URL" 2>/dev/null)

CURL_RESULT=$?

if [ "$CURL_RESULT" -eq 0 ] && [ "$HTTP_CODE" = "200" ]; then
    ESTADO_PORTAL="OPERATIVO"
else
    ESTADO_PORTAL="NO DISPONIBLE"
fi

# ------------------------------------------------------------
# 2. Detectar nodo activo desde el header de Nginx
# ------------------------------------------------------------

NODO_ACTIVO=$(awk -F': ' '
tolower($1) == "x-active-node" {
    gsub("\r", "", $2)
    print $2
    exit
}' "$TMP_HEADERS")

if [ -z "$NODO_ACTIVO" ]; then
    NODO_ACTIVO="No detectado"
fi

# ------------------------------------------------------------
# 3. Obtener estado del RAID
# ------------------------------------------------------------

RAID_ESTADO=$(grep -A1 '^md0' /proc/mdstat \
    | tr '\n' ' ' \
    | sed 's/[[:space:]]\+/ /g')

if [ -z "$RAID_ESTADO" ]; then
    RAID_ESTADO="No se pudo obtener información de md0"
fi

# ------------------------------------------------------------
# 4. Obtener último respaldo TAR disponible
# ------------------------------------------------------------

ULTIMO_BACKUP=$(find /srv/datos/backups/tar \
    -maxdepth 1 \
    -type f \
    -name '*.tar.gz' \
    -printf '%T@ %TY-%Tm-%Td %TH:%TM %f\n' \
    2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-)

if [ -z "$ULTIMO_BACKUP" ]; then
    ULTIMO_BACKUP="No se encontró respaldo TAR"
fi

# ------------------------------------------------------------
# 5. Crear archivo TXT
# ------------------------------------------------------------

cat > "$TMP_TXT" <<EOF
ESTADO DE LA PLATAFORMA
=======================

Fecha de verificacion: $FECHA
VIP: $VIP
Estado del portal: $ESTADO_PORTAL
Codigo HTTP: $HTTP_CODE
Nodo activo: $NODO_ACTIVO

Estado RAID:
$RAID_ESTADO

Ultimo respaldo TAR:
$ULTIMO_BACKUP
EOF

# ------------------------------------------------------------
# 6. Crear archivo HTML visible desde el portal
# ------------------------------------------------------------

cat > "$TMP_HTML" <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="60">
    <title>Estado de la Plataforma</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 900px;
            margin: 40px auto;
            padding: 20px;
        }

        table {
            border-collapse: collapse;
            width: 100%;
        }

        th, td {
            border: 1px solid #999;
            padding: 10px;
            text-align: left;
        }

        pre {
            white-space: pre-wrap;
            background: #eee;
            padding: 15px;
        }
    </style>
</head>
<body>

<h1>Estado de la Plataforma de Alta Disponibilidad</h1>

<table>
<tr>
    <th>Fecha de verificación</th>
    <td>$FECHA</td>
</tr>
<tr>
    <th>IP virtual</th>
    <td>$VIP</td>
</tr>
<tr>
    <th>Estado del portal</th>
    <td>$ESTADO_PORTAL</td>
</tr>
<tr>
    <th>Código HTTP</th>
    <td>$HTTP_CODE</td>
</tr>
<tr>
    <th>Nodo activo</th>
    <td>$NODO_ACTIVO</td>
</tr>
<tr>
    <th>Último respaldo TAR</th>
    <td>$ULTIMO_BACKUP</td>
</tr>
</table>

<h2>Estado RAID 5</h2>

<pre>$RAID_ESTADO</pre>

<p>
Este archivo es generado automáticamente por
<strong>verificar_estado.sh</strong>.
</p>

</body>
</html>
EOF

# ------------------------------------------------------------
# 7. Publicar los archivos
# ------------------------------------------------------------

install -m 644 "$TMP_HTML" "$ESTADO_HTML"
install -m 644 "$TMP_TXT" "$ESTADO_TXT"

# ------------------------------------------------------------
# 8. Generar log
# ------------------------------------------------------------

echo "$FECHA | HTTP=$HTTP_CODE | PORTAL=$ESTADO_PORTAL | NODO=$NODO_ACTIVO" \
    >> "$LOG"

echo "============================================================"
echo "VERIFICACION COMPLETADA"
echo "Fecha: $FECHA"
echo "Portal: $ESTADO_PORTAL"
echo "HTTP: $HTTP_CODE"
echo "Nodo activo: $NODO_ACTIVO"
echo "HTML: $ESTADO_HTML"
echo "TXT: $ESTADO_TXT"
echo "Log: $LOG"
echo "============================================================"
