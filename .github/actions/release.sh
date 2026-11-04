#!/usr/bin/env bash

# Version aliases identify published releases; only primary tags publish images.
if [[ "${GITHUB_REF:-}" =~ ^refs/tags/.+-r[0-9]+$ ]]; then
    exit 0
fi

set -exo pipefail

if [[ "${GITHUB_REF}" == refs/heads/main || "${GITHUB_REF}" == refs/tags/* ]]; then
  # ODOO_VER is the series and Odoo's build date, such as 20.0.20261102. Every major has a single series.
  minor_ver="${ODOO_VER%.*}"
  major_ver="${minor_ver%.*}"

  tags=("${minor_ver}" "${major_ver}")

  if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    image_revision="${GITHUB_REF##*/}"
    tags=("${minor_ver}-${image_revision}" "${major_ver}-${image_revision}")
  elif [[ -n "${LATEST}" ]]; then
    tags+=("latest")
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create IMAGETOOLS_TAG=${tag}
  done
fi
