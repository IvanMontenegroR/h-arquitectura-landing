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
REMOTE_DIR="public_html/"
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

# Sin --delete: en public_html conviven cosas de cPanel (.well-known, cgi-bin)
# que no hay que borrar.
DRY=""
[[ "${1:-}" == "--dry-run" ]] && DRY="--dry-run"
rsync -avz $DRY dist/ "${REMOTE_HOST}:${REMOTE_DIR}"

[[ -z "$DRY" ]] && echo "Publicado en https://${DOMAIN}/"
