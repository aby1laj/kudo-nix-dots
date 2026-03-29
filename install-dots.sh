#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/ilyamiro/nixos-configuration.git"
TARGET_DIR="/etc/nixos"
USERNAME="kudo"

echo "=== Installing NixOS dots ==="

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

if ! command -v nix &> /dev/null; then
  echo "Installing Nix..."
  curl -L https://nixos.org/nix/install | sh
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if [ ! -f /etc/nixos/.nix.enable-flakes ]; then
  echo "Enabling flakes..."
  mkdir -p /etc/nixos/.nix
  if [ -w /etc/nix/nix.conf ] 2>/dev/null; then
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
    echo "sandbox = false" >> /etc/nix/nix.conf
  else
    echo "Skipping nix.conf (read-only) - assuming flakes already enabled"
  fi
  touch /etc/nixos/.nix.enable-flakes
fi

if ! command -v home-manager &> /dev/null; then
  echo "Installing Home Manager..."
  nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz home-manager
  nix-channel --update
  nix-env -iA home-manager.home-manager
fi

echo "Cloning repository..."
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
if [ -d "$TARGET_DIR/nixos-configuration" ]; then
  cd nixos-configuration
  git pull
else
  git clone "$REPO_URL" nixos-configuration
  cd nixos-configuration
fi

echo "Replacing username ilyamiro -> kudo..."
find . -type f \( -name "*.nix" -o -name "*.sh" -o -name "*.conf" \) -exec sed -i 's/ilyamiro/kudo/g' {} \;

if [ ! -f "$TARGET_DIR/configuration.nix" ]; then
  ln -sf "$TARGET_DIR/nixos-configuration/configuration.nix" "$TARGET_DIR/configuration.nix"
fi

if [ ! -f "$TARGET_DIR/home.nix" ]; then
  ln -sf "$TARGET_DIR/nixos-configuration/home.nix" "$TARGET_DIR/home.nix"
fi

if [ ! -f "$TARGET_DIR/hardware-configuration.nix" ]; then
  echo "Generating hardware-configuration.nix..."
  nix-shell -p nixVersions.latest --run "nixos-generate-config"
fi

if [ ! -d "$TARGET_DIR/config" ]; then
  ln -sf "$TARGET_DIR/nixos-configuration/config" "$TARGET_DIR/config"
fi

if [ ! -L /root/.config/nix ]; then
  mkdir -p /root/.config
  ln -s /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh /root/.config/nix
fi

echo "Building NixOS configuration..."
nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix

echo "Done! Please reboot."
