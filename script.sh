
#!/bin/bash
set -euo pipefail

# === User Settings ===
DISK="/dev/vda"                # Adjust if different
HOSTNAME="arch"
USERNAME="sami"
PASSWORD="sami1111"        # Set safely or prompt later
TIMEZONE="Africa/Tunis"
LOCALE="en_US.UTF-8"
SQUASHFS="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
VMLINUZ="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
INITRAMFS="/run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux.img"

# === Partitioning (BIOS + /home) ===
echo "[*] Partitioning $DISK (MBR: BIOS boot)"
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
parted --script "$DISK" \
  mklabel msdos \
  mkpart primary ext4 1MiB 15GiB \
  mkpart primary ext4 15GiB 100%

echo "[*] Formatting partitions"
mkfs.ext4 "${DISK}1" -L root
mkfs.ext4 "${DISK}2" -L home

echo "[*] Mounting partitions and Extracting from SquashFS"
mount "${DISK}1" /mnt

# === Extract root from SquashFS ===
echo "[*] Extracting root filesystem from SquashFS"
unsquashfs -d /mnt "$SQUASHFS"
mount "${DISK}2" /mnt/home
cp "$VMLINUZ" "$INITRAMFS" /mnt/boot

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

# mkinitcpio
mkinitcpio -c /etc/mkinitcpio.conf -g /boot/initramfs-linux.img

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
for d in run sys proc dev; do umount -l /mnt/$d || true; done
umount -l /mnt

echo "[✔] Offline installation complete. Reboot and remove media."
