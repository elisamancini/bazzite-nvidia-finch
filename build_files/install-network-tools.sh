#!/usr/bin/env bash
set -euo pipefail

echo
echo "==> Verifying RPM SHA256"

if ! (
    cd "${RPM_DIR}"
    sha256sum -c SHA256SUMS
); then
    echo
    echo "ERROR: RPM integrity verification failed."
    exit 1
fi

echo "All RPM integrity checks passed."

echo "======================================"
echo " Installing ProtonVPN + OpenSnitch"
echo "======================================"

RPM_DIR="/ctx/RPM"

echo
echo "Using RPM directory:"
echo "  ${RPM_DIR}"

if [[ ! -d "${RPM_DIR}" ]]; then
    echo "ERROR: ${RPM_DIR} not found"
    exit 1
fi

echo
echo "Available RPMs:"
ls -lh "${RPM_DIR}"/*.rpm

#######################################
# Install ProtonVPN repository
#######################################

echo
echo "==> Installing ProtonVPN repository"

dnf install -y \
    "${RPM_DIR}"/protonvpn-stable-release-*.noarch.rpm

#######################################
# Install ProtonVPN client
#######################################

echo
echo "==> Installing ProtonVPN client"

dnf install -y proton-vpn-gnome-desktop

#######################################
# Install OpenSnitch
#######################################

echo
echo "==> Installing OpenSnitch"

dnf install -y \
    "${RPM_DIR}"/opensnitch-*.x86_64.rpm \
    "${RPM_DIR}"/opensnitch-ui-*.noarch.rpm

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
