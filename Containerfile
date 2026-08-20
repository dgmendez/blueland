FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM quay.io/fedora/fedora-bootc:44

### MODIFICATIONS
## A diferencia de ublue-os/base-main, esta imagen es Fedora bootc vanilla:
## sin códecs, sin RPM Fusion, sin Distrobox de fábrica. Todo lo que aparezca
## en el sistema final tiene que venir explícitamente de build.sh.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### system_files: dotfiles de Hyprland, config de SDDM, etc.
COPY system_files/ /

### LINTING
RUN bootc container lint
