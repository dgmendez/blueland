#!/bin/bash
set -ouex pipefail

log() {
    echo "=== $1 ==="
}

# Copy system files early
cp -avf "/ctx/system_files"/. /

#######################################################################
# AGGRESSIVE BASE CLEANUP
#######################################################################
log "Removing unnecessary base packages..."

rpm -e --nodeps \
    glibc-all-langpacks \
    ibus \
    ibus-libs \
    ibus-gtk3 \
    ibus-gtk4 \
    ibus-setup \
    ibus-panel \
    python3-ibus \
    ibus-anthy \
    ibus-anthy-python \
    ibus-hangul \
    ibus-libpinyin \
    ibus-m17n \
    ibus-typing-booster \
    ibus-chewing \
    cosign \
    python3-botocore \
    google-noto-sans-cjk-fonts \
    google-noto-serif-cjk-vf-fonts \
    google-noto-sans-mono-cjk-vf-fonts \
    default-fonts-cjk-serif \
    default-fonts-cjk-mono \
    cldr-emoji-annotation \
    cldr-emoji-annotation-dtd \
    2>/dev/null || true

#######################################################################
# REPOSITORIES
#######################################################################
log "Adding COPR repositories..."

# Download repos directly since rpm-ostree lacks a 'copr enable' command
wget https://copr.fedorainfracloud.org/coprs/ashbuk/Hyprland-Fedora/repo/fedora-$(rpm -E %fedora)/ashbuk-Hyprland-Fedora-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/hyprland.repo
wget https://copr.fedorainfracloud.org/coprs/ulysg/xwayland-satellite/repo/fedora-$(rpm -E %fedora)/ulysg-xwayland-satellite-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/xwayland-satellite.repo

#######################################################################
# PACKAGE DEFINITIONS
#######################################################################
LANGPACKS=(
    glibc-langpack-es
)

HYPR_PKGS=(
    hyprland
    hypridle
    hyprlock
    swaybg
    xdg-desktop-portal-hyprland
    xwayland-satellite
)

HYPR_DEPS=(
    kitty
    kitty-terminfo
    waybar
    wofi
    mako
    lxqt-policykit
    grim
    slurp
    brightnessctl
    playerctl
)

SDDM_PACKAGES=(
    sddm
    sddm-themes
    qt5-qtquickcontrols
    qt5-qtquickcontrols2
    qt5-qtgraphicaleffects
)

FONTS=(
    google-noto-sans-fonts
    google-noto-emoji-fonts
    jetbrains-mono-fonts
)

#######################################################################
# ATOMIC INSTALLATION
#######################################################################
log "Installing packages..."

rpm-ostree install \
    "${LANGPACKS[@]}" \
    "${HYPR_PKGS[@]}" \
    "${HYPR_DEPS[@]}" \
    "${SDDM_PACKAGES[@]}" \
    "${FONTS[@]}"

log "Cleaning up ostree metadata..."
rpm-ostree cleanup -m

#######################################################################
# CONFIGURATION & SERVICES
#######################################################################
log "Configuring system locale to es_MX.UTF-8..."
echo "LANG=es_MX.UTF-8" > /etc/locale.conf
echo "LC_ALL=es_MX.UTF-8" >> /etc/locale.conf

log "Configuring timezone..."
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime

log "Configuring services..."
systemctl enable sddm.service
systemctl enable podman.socket

log "Applying SDDM settings..."
mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/hyprland.conf << 'EOF'
[Users]
HideShells=/sbin/nologin,/usr/sbin/nologin,/bin/false,/usr/bin/false
HideUsers=root
EOF

log "Build finished successfully"
