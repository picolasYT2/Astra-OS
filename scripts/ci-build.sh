#!/usr/bin/env bash
# Construye el ISO de Astra OS dentro de un contenedor de Arch Linux (lo usa GitHub Actions,
# pero también sirve en tu PC con Docker):
#
#   docker run --rm --privileged -v "$PWD:/work" -w /work archlinux:latest bash scripts/ci-build.sh
#
# Resultado: out/astraos-1.0-AAAA.MM.DD-x86_64.iso (+ .sha256)
set -euo pipefail

export USER=root HOME=/root
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"

msg() { printf '\n\e[1;38;2;143;123;255m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

msg "Preparando Arch Linux"
# Docker: sin comprobación de espacio, y sin el sandbox de pacman (no funciona dentro de contenedores)
sed -i 's/^#\?CheckSpace/#CheckSpace/' /etc/pacman.conf
if [[ "$(pacman -V | grep -oE 'v[0-9]+' | head -1 | tr -d v)" -ge 7 ]]; then
    grep -q '^DisableSandbox' /etc/pacman.conf || sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
    grep -q '^DisableSandbox' archiso/pacman.conf || sed -i '/^\[options\]/a DisableSandbox' archiso/pacman.conf
fi
# multilib (Steam, Wine, Proton)
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm --needed archiso base-devel pacman-contrib git sudo \
    imagemagick librsvg grub python rsync mtools dosfstools libarchive

msg "Usuario para compilar (makepkg no corre como root)"
id builder &>/dev/null || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder
mkdir -p "$ROOT/repo/x86_64" "$ROOT/build" "$ROOT/out"
chown -R builder:builder "$ROOT"

msg "Compilando los paquetes (tarda un buen rato: incluye Calamares)"
sudo -u builder -H bash "$ROOT/scripts/build-packages.sh"

msg "Construyendo el ISO"
bash "$ROOT/scripts/build-iso.sh"

msg "Suma SHA256"
cd "$ROOT/out"
for iso in *.iso; do sha256sum "$iso" > "$iso.sha256"; cat "$iso.sha256"; done
ls -lh "$ROOT/out"
