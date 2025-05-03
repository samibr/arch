
#!/bin/bash
set -euo pipefail

# === Interactive Prompts with Defaults ===
read -rp "Enter target disk (e.g., /dev/vda): " DISK
DISK="${DISK:-/dev/vda}"

read -rp "Enter hostname: " HOSTNAME
HOSTNAME="${HOSTNAME:-arch}"

read -rp "Enter username: " USERNAME
USERNAME="${USERNAME:-sami}"

read -rsp "Enter password for user and root: " PASSWORD
echo

read -rp "Enter timezone (e.g., Africa/Tunis): " TIMEZONE
TIMEZONE="${TIMEZONE:-Africa/Tunis}"

read -rp "Enter locale (e.g., en_US.UTF-8): " LOCALE
LOCALE="${LOCALE:-en_US.UTF-8}"

read -rp "Partition disk? (y/n) [n]: " PART
DO_PARTITIONING=${PART,,} == "y"

read -rp "Create swapfile? (y/n) [y]: " SWAP
ENABLE_SWAPFILE=${SWAP,,} != "n"

read -rp "Swapfile size (e.g., 4G): " SWAPFILE_SIZE
SWAPFILE_SIZE="${SWAPFILE_SIZE:-4G}"

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

# === Formatting ===
echo "[*] Formatting partitions"
mkfs.ext4 "${DISK}1" -L root

if $DO_PARTITIONING; then
  mkfs.ext4 "${DISK}2" -L home
else
  echo "[*] Keeping existing /home partition"
  e2label "${DISK}2" home || true
fi

# === Mount & Extract ===
echo "[*] Mounting partitions and Extracting from SquashFS"
mount "${DISK}1" /mnt
unsquashfs -d /mnt "$SQUASHFS"
mount "${DISK}2" /mnt/home
cp "$VMLINUZ" "$INITRAMFS" /mnt/boot

# === Bind mounts ===
echo "[*] Preparing chroot environment"
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

# === Chroot configuration ===
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

if [ "$ENABLE_SWAPFILE" = true ]; then
  if ! grep -q swap /etc/fstab; then
    fallocate -l "$SWAPFILE_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap defaults 0 0' >> /etc/fstab
  fi
fi

id liveuser &>/dev/null && userdel -rf liveuser || true
rm /usr/share/wayland-sessions/xfce-wayland.desktop || true
EOF

echo "[*] Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Unmounting and cleaning up"
for d in run sys proc dev; do umount -l /mnt/$d || true; done
umount -l /mnt

echo "[✔] Installation complete. Reboot and remove installation media."
