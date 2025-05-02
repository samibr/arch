
#!/bin/bash
set -euo pipefail

# === User Settings ===
DISK="/dev/vda"
HOSTNAME="arch"
USERNAME="sami"
PASSWORD="sami1111"
TIMEZONE="Africa/Tunis"
LOCALE="en_US.UTF-8"
FILESYSTEM="btrfs" # btrfs or ext4
DO_PARTITIONING=false
ENABLE_SWAPFILE=true
SWAPFILE_SIZE="4G"

SQUASHFS="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
VMLINUZ="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
INITRAMFS="/run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux.img"

# === Partitioning ===
if $DO_PARTITIONING; then
  echo "[*] Partitioning $DISK (MBR: BIOS boot)"
  wipefs -af "$DISK"
  sgdisk --zap-all "$DISK"
  parted --script "$DISK" \
    mklabel msdos \
    mkpart primary ext4 1MiB 15GiB \
    mkpart primary ext4 15GiB 100%
else
  echo "[*] Skipping partitioning"
fi

# === Filesystem Creation ===
echo "[*] Formatting root partition as $FILESYSTEM"
if [[ "$FILESYSTEM" == "btrfs" ]]; then
  mkfs.btrfs -f -L root "${DISK}1"
elif [[ "$FILESYSTEM" == "ext4" ]]; then
  mkfs.ext4 "${DISK}1" -L root
else
  echo "Unsupported filesystem: $FILESYSTEM"
  exit 1
fi

if $DO_PARTITIONING; then
  if [[ "$FILESYSTEM" == "btrfs" ]]; then
    mkfs.btrfs -f -L home "${DISK}2"
  else
    mkfs.ext4 "${DISK}2" -L home
  fi
else
  echo "[*] Keeping existing /home partition"
  e2label "${DISK}2" home || true
fi

# === Btrfs Subvolumes (if applicable) ===
if [[ "$FILESYSTEM" == "btrfs" ]]; then
  echo "[*] Creating Btrfs subvolumes"
  mount "${DISK}1" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  umount /mnt

  echo "[*] Mounting Btrfs subvolumes"
  mount -o compress=zstd,subvol=@ "${DISK}1" /mnt
  mkdir -p /mnt/home /mnt/.snapshots
  mount -o compress=zstd,subvol=@home "${DISK}1" /mnt/home
  mount -o compress=zstd,subvol=@snapshots "${DISK}1" /mnt/.snapshots
else
  mount "${DISK}1" /mnt
  mount "${DISK}2" /mnt/home
fi

# === Extract root from SquashFS ===
echo "[*] Extracting root filesystem from SquashFS"
unsquashfs -d /mnt "$SQUASHFS"
cp "$VMLINUZ" "$INITRAMFS" /mnt/boot

# === Bind mounts for chroot ===
echo "[*] Preparing chroot environment"
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

# === Fstab ===
echo "[*] Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

if [[ "$FILESYSTEM" == "btrfs" ]]; then
  echo "[*] Adding .snapshots to fstab"
  cat >> /mnt/etc/fstab <<EOL

# Snapper snapshots
LABEL=root /.snapshots btrfs subvol=@snapshots,compress=zstd 0 0
EOL
fi

# === Post-install configuration in chroot ===
echo "[*] Entering chroot and configuring system"
arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i "s/^#\s*$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

cat > /etc/default/keyboard <<EOL
XKBMODEL="pc105"
XKBLAYOUT="fr"
EOL

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

mkinitcpio -c /etc/mkinitcpio.conf -g /boot/initramfs-linux.img

grub-install --target=i386-pc --recheck "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager || true

# Swapfile
if [ "$ENABLE_SWAPFILE" = true ]; then
  if ! grep -q swap /etc/fstab; then
    fallocate -l "$SWAPFILE_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap defaults 0 0' >> /etc/fstab
  fi
fi

# Snapper setup
if [[ "$FILESYSTEM" == "btrfs" ]]; then
  echo "[*] Installing and configuring Snapper"
  pacman -Sy --noconfirm snapper

  snapper -c root create-config /
  mkdir -p /.snapshots
  mount --bind /.snapshots /.snapshots

  sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
  sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="20"/' /etc/snapper/configs/root

  snapper -c root create -d "Initial installation"
fi

id liveuser &>/dev/null && userdel -rf liveuser || true
rm -f /usr/share/wayland-sessions/xfce-wayland.desktop
EOF

# === Cleanup ===
echo "[*] Unmounting and cleaning up"
for d in run sys proc dev; do umount -l /mnt/$d || true; done
umount -l /mnt

echo "[✔] Offline installation complete. Reboot and remove media."
