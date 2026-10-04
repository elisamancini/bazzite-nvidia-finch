#!/usr/bin/env bash
# Configura la verifica delle firme cosign per la propria immagine, dentro l'immagine stessa.
# Richiede build_files/cosign.pub (chiave PUBBLICA) -> /ctx/cosign.pub
set -euo pipefail

IMAGE_REPO="ghcr.io/elisamancini/bazzite-nvidia-finch"
KEY_NAME="elisamancini-bazzite-nvidia-finch"
SRC_KEY="/ctx/cosign.pub"
KEY_DST="/etc/pki/containers/${KEY_NAME}.pub"
POLICY="/etc/containers/policy.json"
REG_DIR="/etc/containers/registries.d"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v jq >/dev/null || die "jq non disponibile nell'immagine base"
[[ -f "${SRC_KEY}" ]] || die "${SRC_KEY} non trovato (copia cosign.pub in build_files/)"
grep -q "BEGIN PUBLIC KEY" "${SRC_KEY}" || die "${SRC_KEY} non sembra una chiave pubblica"
[[ -f "${POLICY}" ]] || die "${POLICY} non trovato"
jq -e '.transports.docker | type == "object"' "${POLICY}" >/dev/null \
    || die "${POLICY} non ha la struttura attesa (transports.docker)"
KEYS_BEFORE=$(jq -c '.transports.docker | keys' "${POLICY}")

echo "==> Installing cosign public key"
install -Dm644 "${SRC_KEY}" "${KEY_DST}"

echo "==> Telling containers/image to fetch sigstore signatures for ${IMAGE_REPO}"
install -d "${REG_DIR}"
cat > "${REG_DIR}/${KEY_NAME}.yaml" <<EOF
docker:
  ${IMAGE_REPO}:
    use-sigstore-attachments: true
EOF

echo "==> Adding signature requirement to ${POLICY}"
tmp=$(mktemp)
jq --arg repo "${IMAGE_REPO}" --arg key "${KEY_DST}" \
    '.transports.docker[$repo] = [{
        "type": "sigstoreSigned",
        "keyPath": $key,
        "signedIdentity": { "type": "matchRepository" }
     }]' "${POLICY}" > "${tmp}"
install -m644 "${tmp}" "${POLICY}"
rm -f "${tmp}"

# controllo finale: la nostra voce c'e' e nessuna voce preesistente e' sparita
jq -e --arg repo "${IMAGE_REPO}" \
    '.transports.docker[$repo][0].type == "sigstoreSigned"' "${POLICY}" >/dev/null \
    || die "voce di policy non presente dopo la modifica"
jq -e --argjson before "${KEYS_BEFORE}" \
    '($before - (.transports.docker | keys)) | length == 0' "${POLICY}" >/dev/null \
    || die "una voce preesistente di policy.json e' sparita"

echo "Signature policy installed for ${IMAGE_REPO}"
