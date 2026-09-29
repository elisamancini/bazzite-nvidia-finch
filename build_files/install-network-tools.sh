#!/usr/bin/env bash
# Installa ProtonVPN + OpenSnitch da RPM locali (build_files/RPM -> /ctx/RPM)
# verificati con SHA256SUMS.
set -euo pipefail
set +x   # build.sh usa "set -x": qui non serve e sporca i log

RPM_DIR="/ctx/RPM"

die() { echo "ERROR: $*" >&2; exit 1; }

echo "======================================"
echo " Installing ProtonVPN + OpenSnitch"
echo "======================================"

echo
echo "Using RPM directory:"
echo "  ${RPM_DIR}"

[[ -d "${RPM_DIR}" ]] || die "${RPM_DIR} not found"
[[ -f "${RPM_DIR}/SHA256SUMS" ]] || die "${RPM_DIR}/SHA256SUMS not found"

cd "${RPM_DIR}"
shopt -s nullglob

#######################################
# Verifica integrita'
#######################################

echo
echo "==> Verifying RPM SHA256"

# 1) ogni file elencato deve esistere e avere l'hash corretto
sha256sum --strict -c SHA256SUMS \
    || die "RPM integrity verification failed"

# 2) ogni RPM presente deve essere elencato (nessun file "extra" installabile)
listed=$(awk '{sub(/^\*/, "", $2); print $2}' SHA256SUMS | grep -E '\.rpm$' | sort || true)
present=$(printf '%s\n' *.rpm | grep -E '\.rpm$' | sort || true)
[[ -n "${present}" ]] || die "no RPM found in ${RPM_DIR}"
[[ "${listed}" == "${present}" ]] \
    || die "RPM files and SHA256SUMS do not match (extra or missing files)"

echo "All RPM integrity checks passed."

echo
echo "Available RPMs:"
ls -lh -- *.rpm

#######################################
# Un solo file per pacchetto
#######################################

one() {
    [[ $# -eq 1 && -f "$1" ]] || die "expected exactly one file, got $#: $*"
    printf '%s/%s\n' "${RPM_DIR}" "$1"
}

check_name() {
    local file="$1" expected="$2" name
    name=$(rpm -qp --qf '%{NAME}\n' "${file}")
    [[ "${name}" == "${expected}" ]] || die "${file} is '${name}', expected '${expected}'"
}

PROTON_REPO_RPM=$(one protonvpn-stable-release-*.noarch.rpm)
OPENSNITCH_RPM=$(one opensnitch-[0-9]*.x86_64.rpm)
OPENSNITCH_UI_RPM=$(one opensnitch-ui-[0-9]*.noarch.rpm)

check_name "${PROTON_REPO_RPM}" "protonvpn-stable-release"
check_name "${OPENSNITCH_RPM}" "opensnitch"
check_name "${OPENSNITCH_UI_RPM}" "opensnitch-ui"

#######################################
# Install ProtonVPN
#######################################

echo
echo "==> Installing ProtonVPN repository"
dnf install -y "${PROTON_REPO_RPM}"

echo
echo "==> Installing ProtonVPN client"
dnf install -y proton-vpn-gnome-desktop

#######################################
# Install OpenSnitch
#######################################

echo
echo "==> Installing OpenSnitch"
dnf install -y "${OPENSNITCH_RPM}" "${OPENSNITCH_UI_RPM}"

#######################################
# Enable services
#######################################

echo
echo "==> Enabling services"
systemctl enable opensnitchd.service

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
