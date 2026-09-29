#!/bin/bash

set -ouex pipefail

#######################################
# Temporary systemctl wrapper
# Prevent services starting during image build
#######################################

echo "==> Installing temporary systemctl wrapper"

if [ -x /usr/bin/systemctl ] && [ ! -e /usr/bin/systemctl.real ]; then
    mv /usr/bin/systemctl /usr/bin/systemctl.real

    cat >/usr/bin/systemctl <<'EOF'
#!/bin/sh

case "$1" in
    start|restart|try-restart|reload|daemon-reload)
        exit 0
        ;;
    *)
        exec /usr/bin/systemctl.real "$@"
        ;;
esac
EOF

    chmod 755 /usr/bin/systemctl
fi

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

bash /ctx/build_files/install-network-tools.sh

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

#######################################
# Restore systemctl
#######################################

echo "==> Restoring systemctl"

if [ -e /usr/bin/systemctl.real ]; then
    rm -f /usr/bin/systemctl
    mv /usr/bin/systemctl.real /usr/bin/systemctl
fi
