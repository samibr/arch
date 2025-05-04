
#!/bin/bash
set -euo pipefail

# === User Settings ===
DISK="/dev/vda"                # Adjust if different
HOSTNAME="arch"
USERNAME="sami"
PASSWORD="sami1111"        # Set safely or prompt later
TIMEZONE="Africa/Tunis"
LOCALE="en_US.UTF-8"
DO_PARTITIONING=false  # Set to false to skip partitioning and only format
ENABLE_SWAPFILE=true       # Set to false to skip creating a swapfile
SWAPFILE_SIZE="2G"         # Set your desired swapfile size

SQUASHFS="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
VMLINUZ="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
INITRAMFS="/run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux.img"

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

echo "[*] Formatting partitions"
mkfs.ext4 "${DISK}1" -L root

if $DO_PARTITIONING; then
  mkfs.ext4 "${DISK}2" -L home
else
  echo "[*] Keeping existing /home partition"
  e2label "${DISK}2" home || true
fi

echo "[*] Mounting partitions and Extracting from SquashFS"
mount "${DISK}1" /mnt

echo "[*] Extracting root filesystem from SquashFS"
unsquashfs -d /mnt "$SQUASHFS"
mount "${DISK}2" /mnt/home
cp "$VMLINUZ" "$INITRAMFS" /mnt/boot

echo "[*] Preparing chroot environment"
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

echo "[*] Entering chroot and configuring system"
arch-chroot /mnt /bin/bash <<EOF
echo "[*] Setting hostname"
echo "$HOSTNAME" > /etc/hostname

echo "[*] Setting timezone to $TIMEZONE"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

echo "[*] Setting hardware clock"
hwclock --systohc

echo "[*] Generating locale"
sed -i "s/^#\s*$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "[*] Setting keyboard layout for login manager"
cat > /etc/default/keyboard <<EOL
XKBMODEL="pc105"
XKBLAYOUT="fr"
EOL

echo "[*] Creating user $USERNAME and setting passwords"
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

echo "[*] Enabling sudo for wheel group"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[*] Generating initramfs"
mkinitcpio -c /etc/mkinitcpio.conf -g /boot/initramfs-linux.img

echo "[*] Installing GRUB for BIOS"
grub-install --target=i386-pc --recheck "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Enabling NetworkManager"
systemctl enable NetworkManager || true

if [ "$ENABLE_SWAPFILE" = true ]; then
  echo "[*] Creating swapfile"
  if ! grep -q swap /etc/fstab; then
    fallocate -l "$SWAPFILE_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
  fi
fi

echo "[*] Configuring ZRAM"
cat > /etc/systemd/zram-generator.conf <<-EOL
[zram0]
zram-size = min(ram / 2, 8192)
EOL

echo "[*] Creating Mutt mail folders"
for provider in gmail zoho; do
  for d in accounts bodies cache certificates headers private tmp; do
    mkdir -p ~/.local/share/mutt/"\$provider"/"\$d"
  done
done

echo "[*] Creating ScanTailor folder"
mkdir -p ~/ScanTailor

echo "[*] Cleaning up live environment"
id liveuser &>/dev/null && userdel -rf liveuser || true
rm /usr/share/wayland-sessions/xfce-wayland.desktop
EOF

echo "[*] Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Unmounting and cleaning up"
for d in run sys proc dev; do umount -l /mnt/\$d || true; done
umount -l /mnt

echo "[✔] Offline installation complete. Reboot and remove media."
