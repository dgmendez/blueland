#!/bin/bash
set -ouex pipefail

log() {
    echo "=== $1 ==="
}

# Copiar system_files temprano (mismo patrón que ya usabas)
cp -avf "/ctx/system_files"/. /

#######################################################################
# LIMPIEZA AGRESIVA DE PAQUETES BASE
#######################################################################
# NOTA: como fedora-bootc es más minimalista que base-main, es posible que
# algunos de estos paquetes ni siquiera estén presentes acá. El "|| true"
# al final ya cubre ese caso sin romper el build.
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
log "Ensuring curl is available (fedora-bootc no lo trae por defecto)..."
dnf5 install -y curl

log "Adding COPR repositories..."
curl -L -o /etc/yum.repos.d/hyprland.repo \
    "https://copr.fedorainfracloud.org/coprs/ashbuk/Hyprland-Fedora/repo/fedora-$(rpm -E %fedora)/ashbuk-Hyprland-Fedora-fedora-$(rpm -E %fedora).repo"
curl -L -o /etc/yum.repos.d/xwayland-satellite.repo \
    "https://copr.fedorainfracloud.org/coprs/ulysg/xwayland-satellite/repo/fedora-$(rpm -E %fedora)/ulysg-xwayland-satellite-fedora-$(rpm -E %fedora).repo"

#######################################################################
# PACKAGE DEFINITIONS
#######################################################################
LANGPACKS=(
    glibc-langpack-es
    glibc-langpack-en
)
HYPR_PKGS=(
    hyprland
    hypridle
    hyprlock
    swaybg
    xdg-desktop-portal-hyprland
    xwayland-satellite
)
# Firmware y drivers GPU para AMD RX 9070 XT (RDNA4/gfx1201).
# fedora-bootc vanilla NO trae esto — a diferencia de base-main, hay que
# agregarlo explícitamente. amd-gpu-firmware es el paquete correcto (evitar
# amd-gpu-pro-firmware, que causó pantalla negra en RDNA4 según un caso real
# documentado en el foro de Fedora Discussion).
GPU_PKGS=(
    amd-gpu-firmware
    mesa-dri-drivers
    mesa-vulkan-drivers
    vulkan-loader
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
    wl-clipboard
    brightnessctl
    playerctl
    thunar
    gvfs
    thunar-archive-plugin
    thunar-volman
)
# Red y Bluetooth: Hyprland no trae applet de bandeja como GNOME/KDE,
# hay que agregarlo a mano.
NETWORK_PKGS=(
    network-manager-applet
    blueman
)
# Audio: control de volumen gráfico (PipeWire ya viene en el sistema base,
# pero sin GUI para manejarlo).
AUDIO_PKGS=(
    pavucontrol
)
# Navegador (paquete nativo — más simple y confiable en build-time que
# instalar la app de Flatpak durante el build, ver nota más abajo)
APPS=(
    firefox
    flatpak
    git
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
# INSTALACIÓN
#######################################################################
# CAMBIO CLAVE respecto a la versión anterior: dnf5 en vez de rpm-ostree.
# Durante el build de una imagen bootc todavía NO estamos en un sistema
# corriendo — es un filesystem de contenedor normal — así que dnf5 funciona
# directo, sin las limitaciones de rpm-ostree (que es solo para modificar
# un sistema ya desplegado). Esto también resuelve --setopt=install_weak_deps
# de forma nativa, sin el workaround de tocar /etc/dnf/dnf.conf a mano.
log "Installing packages with dnf5..."
dnf5 install --setopt=install_weak_deps=False -y \
    "${LANGPACKS[@]}" \
    "${HYPR_PKGS[@]}" \
    "${GPU_PKGS[@]}" \
    "${HYPR_DEPS[@]}" \
    "${NETWORK_PKGS[@]}" \
    "${AUDIO_PKGS[@]}" \
    "${APPS[@]}" \
    "${SDDM_PACKAGES[@]}" \
    "${FONTS[@]}"

log "Deshabilitando COPRs..."
dnf5 -y copr disable ashbuk/Hyprland-Fedora 2>/dev/null || true
dnf5 -y copr disable ulysg/xwayland-satellite 2>/dev/null || true

log "Limpiando caché de dnf..."
dnf5 clean all

# NOTA: acá solo dejamos el paquete flatpak instalado y el remote de
# Flathub agregado. NO instalamos apps de Flatpak durante el build (por
# ejemplo, no hacemos "flatpak install firefox" acá) porque durante el
# build no hay systemd/dbus corriendo, y eso suele fallar o generar
# builds poco confiables. Firefox lo dejamos como paquete nativo (arriba,
# en APPS) precisamente por esto. Cualquier otra app de Flatpak que
# quieras, se instala después de bootear, ya con el sistema corriendo.
log "Configurando remote de Flathub para Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

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
