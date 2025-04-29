
#!/bin/bash
set -euo pipefail

# === User Settings ===
DISK="/dev/sda"                # Adjust if different
HOSTNAME="arch-offline"
USERNAME="sami"
PASSWORD="yourpassword"        # Set safely or prompt later
TIMEZONE="Europe/Paris"
LOCALE="en_US.UTF-8"
SQUASHFS="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"

# === Partitioning (BIOS + /home) ===
echo "[*] Partitioning $DISK (MBR: BIOS boot)"
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
parted --script "$DISK" \
  mklabel msdos \
  mkpart primary ext4 1MiB 50GiB \
  mkpart primary ext4 50GiB 100%

echo "[*] Formatting partitions"
mkfs.ext4 "${DISK}1" -L root
mkfs.ext4 "${DISK}2" -L home

echo "[*] Mounting partitions"
mount "${DISK}1" /mnt
mkdir -p /mnt/home
mount "${DISK}2" /mnt/home

# === Extract root from SquashFS ===
echo "[*] Extracting root filesystem from SquashFS"
unsquashfs -d /mnt "$SQUASHFS"

# === Bind mounts for chroot ===
echo "[*] Preparing chroot environment"
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

# === Post-install configuration in chroot ===
echo "[*] Entering chroot and configuring system"
arch-chroot /mnt /bin/bash <<EOF
# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Timezone and locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i "s/^#\s*$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Create user and set passwords
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install GRUB for BIOS
grub-install --target=i386-pc --recheck "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

# Enable essential services (optional)
systemctl enable NetworkManager || true
EOF

# === Fstab ===
echo "[*] Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# === Cleanup ===
echo "[*] Unmounting and cleaning up"
for d in run sys proc dev; do umount -R /mnt/$d || true; done
umount -R /mnt

echo "[✔] Offline installation complete. Reboot and remove media."
