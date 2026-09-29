#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo " Installing ProtonVPN + OpenSnitch"
echo "======================================"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"


#######################################
# Detect Fedora version
#######################################

FEDORA_VERSION=$(rpm -E %fedora)

if [[ "$FEDORA_VERSION" == "%fedora" ]]; then
    echo "ERROR: Cannot detect Fedora version"
    exit 1
fi

echo "Fedora version detected: ${FEDORA_VERSION}"


#######################################
# ProtonVPN repository
#######################################

echo
echo "==> Searching ProtonVPN repository RPM"

PROTON_URL="https://repo.protonvpn.com/fedora-${FEDORA_VERSION}-stable/protonvpn-stable-release/"

echo "Repository:"
echo "$PROTON_URL"


PROTON_RPM=$(curl -fsSL "$PROTON_URL" \
    | grep -oE 'href="[^"]+\.rpm"' \
    | sed 's/href="//;s/"//' \
    | grep -E 'protonvpn-stable-release.*noarch\.rpm' \
    | sort -V \
    | tail -n1)


if [[ -z "$PROTON_RPM" ]]; then
    echo "ERROR: ProtonVPN repository RPM not found"
    exit 1
fi


echo "Downloading:"
echo "$PROTON_RPM"

curl -fLO "${PROTON_URL}${PROTON_RPM}"


echo "Installing ProtonVPN repository"

dnf install -y ./"$(basename "$PROTON_RPM")"



#######################################
# Install ProtonVPN client
#######################################

echo
echo "==> Installing ProtonVPN client"

dnf install -y proton-vpn-gnome-desktop



#######################################
# OpenSnitch
#######################################

echo
echo "==> Searching latest OpenSnitch release"


OPEN_RELEASE_URLS=$(curl -fsSL \
    https://api.github.com/repos/evilsocket/opensnitch/releases/latest \
    | grep browser_download_url \
    | cut -d '"' -f4 \
    | grep -E 'opensnitch(-ui)?-.*\.rpm$')


if [[ -z "$OPEN_RELEASE_URLS" ]]; then
    echo "ERROR: OpenSnitch RPMs not found"
    exit 1
fi


echo "$OPEN_RELEASE_URLS"



echo
echo "Downloading OpenSnitch RPMs"


while read -r url; do
    curl -fLO "$url"
done <<< "$OPEN_RELEASE_URLS"



#######################################
# Install OpenSnitch
#######################################

echo
echo "==> Installing OpenSnitch"

dnf install -y ./*.rpm



#######################################
# Enable services
#######################################

echo
echo "==> Enabling services"


systemctl enable opensnitchd.service 2>/dev/null || true
systemctl enable opensnitch.service 2>/dev/null || true


#######################################
# Cleanup
#######################################

echo
echo "Cleaning cache"

dnf clean all


echo
echo "======================================"
echo " ProtonVPN + OpenSnitch installed"
echo "======================================"
