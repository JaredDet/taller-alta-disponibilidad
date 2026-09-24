# Taller de Alta Disponibilidad

Scripts de automatización para respaldos y monitoreo en clúster de alta disponibilidad (Pacemaker/Corosync).

## Estructura y Ubicación de Scripts

### 1. Nodos del Clúster (`cluster-node1`, etc.)

**Ubicación recomendada:** `/home/node1/scripts-backup/`

- **`backup_tar.sh`**: Realiza un respaldo completo comprimido (`.tar.gz`) de las rutas críticas del sistema (`/var/www/html`, `/etc/nginx`, `/etc/corosync`, `/etc/hosts`) junto con la configuración actual del clúster (`pcs config`). Envía el resultado al almacenamiento central NFS/RAID.
- **`backup_rsync.sh`**: Ejecuta un respaldo incremental inteligente utilizando enlaces duros (`--link-dest`) para optimizar espacio, sincronizando el contenido web y los scripts locales hacia el almacenamiento compartido.

### 2. Servidor de Almacenamiento / Monitoreo (`storage-server2`)

**Ubicación recomendada:** `/home/felipe/scripts-monitor/`

- **`verificar_estado.sh`**: Monitorea de manera automática la disponibilidad del portal web mediante la IP Virtual (VIP), detecta qué nodo está activo respondiendo el tráfico (`X-Active-Node`), revisa el estado del RAID (`/md0`) y genera un reporte dual en formato texto y HTML (`estado.html`) para el portal.
