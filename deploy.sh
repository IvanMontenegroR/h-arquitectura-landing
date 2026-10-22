#!/usr/bin/env bash
# Publica la landing en HostGator (https://harqmascons.com).
#
#   ./deploy.sh             arma dist/ y lo sube
#   ./deploy.sh --dry-run   arma dist/ y muestra qué subiría, sin subir nada
#   ./deploy.sh --build-only  solo arma dist/ (sin conectarse al servidor)
#
# GitHub Pages sigue siendo la vista previa (con noindex). Este script arma la
# versión de producción: sin noindex y con las URLs apuntando al dominio real.
set -euo pipefail

DOMAIN="harqmascons.com"
REMOTE_HOST="hostgator-harq"     # alias en ~/.ssh/config
REMOTE_DIR="public_html/"       # SFTP entra en /home4/harqmasc
PREVIEW_URL="https://ivanmontenegror.github.io/h-arquitectura-landing/"

cd "$(dirname "$0")"
rm -rf dist && mkdir dist

# Solo lo que forma parte del sitio (nada de git, server local ni este script).
rsync -a \
  --exclude '.git' --exclude '.gitignore' --exclude '.nojekyll' \
  --exclude '.DS_Store' --exclude 'dist' \
  --exclude 'serve.mjs' --exclude 'deploy.sh' \
  ./ dist/

# Producción: sacar noindex (y su comentario) y apuntar las URLs al dominio.
sed -i '' \
  -e '/Preview para el cliente: quitar noindex/d' \
  -e '/<meta name="robots" content="noindex/d' \
  -e "s#${PREVIEW_URL}#https://${DOMAIN}/#g" \
  dist/index.html

if grep -q 'noindex\|github.io' dist/index.html; then
  echo "ERROR: dist/index.html todavía tiene noindex o URLs de github.io" >&2
  exit 1
fi

[[ "${1:-}" == "--build-only" ]] && { echo "dist/ listo, no se subió nada"; exit 0; }

# HostGator no da terminal en esta cuenta (solo SFTP), así que se sube con sftp.
# Solo se agregan/reemplazan archivos: nunca se borra nada en public_html
# (ahí viven cosas de cPanel como cgi-bin y .well-known).
VIDEO="assets/video-presentacion.mp4"

# El video pesa ~56MB: se sube solo si en el servidor no está o cambió de tamaño.
remote_size() {
  printf 'ls -l %s\n' "${REMOTE_DIR}$1" | sftp -q -b - "$REMOTE_HOST" 2>/dev/null \
    | awk -v f="$1" '$0 ~ f {print $5}' | tail -1
}
UPLOAD_VIDEO=0
if [[ -f "dist/$VIDEO" ]]; then
  local_size=$(stat -f%z "dist/$VIDEO")
  [[ "$(remote_size "$VIDEO")" == "$local_size" ]] || UPLOAD_VIDEO=1
fi

BATCH=$(mktemp)
trap 'rm -f "$BATCH"' EXIT
{
  echo "lcd dist"
  echo "cd ${REMOTE_DIR}"
  echo "-mkdir assets"
  echo "-mkdir assets/fonts"
  find dist -type f ! -name "$(basename "$VIDEO")" | sed 's#^dist/##' | sort \
    | while read -r f; do echo "put \"$f\" \"$f\""; done
  [[ $UPLOAD_VIDEO == 1 ]] && echo "put \"$VIDEO\" \"$VIDEO\""
} > "$BATCH"

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "Se subiría a ${REMOTE_HOST}:${REMOTE_DIR}"
  grep '^put' "$BATCH" | awk '{print "  " $2}' | tr -d '"'
  [[ $UPLOAD_VIDEO == 1 ]] || echo "  (video sin cambios, no se sube)"
  exit 0
fi

sftp -b "$BATCH" "$REMOTE_HOST"
echo "Publicado en https://${DOMAIN}/"
