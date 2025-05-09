
#!/bin/bash
set -euo pipefail

# === Styling ===
BOLD='\e[1m'
GREEN='\e[92m'
RED='\e[91m'
YELLOW='\e[93m'
RESET='\e[0m'

log() {
  echo -e "${BOLD}${YELLOW}[*] $1${RESET}"
}

# === User Settings ===
DISK="/dev/vda"
HOSTNAME="arch"
USERNAME="sami"
PASSWORD="sami1111"
TIMEZONE="Africa/Tunis"
LOCALE="en_US.UTF-8"
DO_PARTITIONING=false
ENABLE_SWAPFILE=true
SWAPFILE_SIZE="2G"


# === Summary and Confirmation ===
echo -e "${BOLD}${GREEN}=== Installation Summary ===${RESET}"
echo -e "${BOLD}${YELLOW}Disk:            ${RESET}${DISK}"
echo -e "${BOLD}${YELLOW}Hostname:        ${RESET}${HOSTNAME}"
echo -e "${BOLD}${YELLOW}Username:        ${RESET}${USERNAME}"
echo -e "${BOLD}${YELLOW}Timezone:        ${RESET}${TIMEZONE}"
echo -e "${BOLD}${YELLOW}Locale:          ${RESET}${LOCALE}"
echo -e "${BOLD}${YELLOW}Partitioning:    ${RESET}${DO_PARTITIONING}"
echo -e "${BOLD}${YELLOW}Enable Swapfile: ${RESET}${ENABLE_SWAPFILE}"
echo -e "${BOLD}${YELLOW}Swapfile Size:   ${RESET}${SWAPFILE_SIZE}"
echo
echo -e "${BOLD}${RED}WARNING: This will format and install Arch on ${DISK}${RESET}"
echo -e "${BOLD}${RED}Root partition: ${DISK}1${RESET}"
[[ "$DO_PARTITIONING" == true ]] && echo -e "${BOLD}${RED}Home partition: ${DISK}2${RESET}" || echo -e "${BOLD}${YELLOW}Note: Home partition will not be reformatted${RESET}"
echo

read -rp "$(echo -e ${BOLD}${GREEN}"Proceed with installation? (yes/[no]): "${RESET})" confirm
if [[ "$confirm" != "yes" ]]; then
  echo -e "${BOLD}${RED}Aborting installation.${RESET}"
  exit 1
fi


SQUASHFS="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
VMLINUZ="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
INITRAMFS="/run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux.img"

if $DO_PARTITIONING; then
  log "Partitioning $DISK (MBR: BIOS boot)"
  wipefs -af "$DISK"
  sgdisk --zap-all "$DISK"
  parted --script "$DISK" \
    mklabel msdos \
    mkpart primary ext4 1MiB 22GiB \
    mkpart primary ext4 22GiB 100%
else
  log "Skipping partitioning"
fi

log "Formatting partitions"
mkfs.ext4 "${DISK}1" -L root
if $DO_PARTITIONING; then
  mkfs.ext4 "${DISK}2" -L home
else
  log "Keeping existing /home partition"
  e2label "${DISK}2" home || true
fi

log "Mounting root and home partitions"
mount "${DISK}1" /mnt

log "Extracting root filesystem from SquashFS"
unsquashfs -d /mnt "$SQUASHFS"
mount "${DISK}2" /mnt/home
cp "$VMLINUZ" "$INITRAMFS" /mnt/boot

log "Preparing chroot environment"
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

log "Entering chroot and configuring system"
arch-chroot /mnt /bin/bash -e <<EOF
log() {
  echo -e "${BOLD}${YELLOW}[*] \$1${RESET}"
}

log "Setting hostname"
echo "$HOSTNAME" > /etc/hostname

log "Setting timezone and locale"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i "s/^#\s*$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

log "Configuring keyboard layout"
cat > /etc/default/keyboard <<EOL
XKBMODEL="pc105"
XKBLAYOUT="fr"
EOL

log "Creating user and setting passwords"
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

log "Enabling sudo for wheel group"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

log "Generating initramfs"
mkinitcpio -c /etc/mkinitcpio.conf -g /boot/initramfs-linux.img

log "Installing and configuring GRUB"
grub-install --target=i386-pc --recheck "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

log "Enabling NetworkManager"
systemctl enable NetworkManager || true

if [ "$ENABLE_SWAPFILE" = true ]; then
  log "Creating swapfile"
  if ! grep -q swap /etc/fstab; then
    fallocate -l "$SWAPFILE_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
  fi
fi

log "Configuring ZRAM"
cat > /etc/systemd/zram-generator.conf <<-EOL
[zram0]
zram-size = min(ram / 2, 8192)
EOL

log "Creating mail directories"
for provider in gmail zoho; do
  for d in accounts bodies cache certificates headers private tmp; do
    mkdir -p /home/"$USERNAME"/.local/share/mutt/"\$provider"/"\$d"
  done
done
mkdir -p /home/"$USERNAME"/ScanTailor

log "Cleaning up system"
if id liveuser &>/dev/null; then
  userdel -rf liveuser 2>/dev/null || true
fi
rm /usr/share/wayland-sessions/xfce-wayland.desktop
chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"
EOF

log "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

log "Unmounting and cleaning up"
for d in run sys proc dev; do umount -l /mnt/$d || true; done
umount -l /mnt

log "Offline installation complete. Reboot and remove media."
