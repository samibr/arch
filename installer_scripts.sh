
#!/bin/bash
set -euo pipefail

# Clear the tty when starting the script
clear

SQUASHFS="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
VMLINUZ="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
INITRAMFS="/run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux.img"

BOLD='\e[1m'
GREEN='\e[92m'
RED='\e[91m'
YELLOW='\e[93m'
RESET='\e[0m'

print_info () {
    echo -ne "${BOLD}${YELLOW}$1${RESET}\n"
}

print_choice () {
    echo -ne "${BOLD}${GREEN}>> $1${RESET}\n\n"
}

invalid_input () {
    print_info "\n${RED}WARNING! Invalid input!"
    print_info "Please enter a valid option."
}

menu() {
    # Start from the 3rd argument
    local my_array=("${@:3}")
    while true; do
        print_info "$1"
        PS3="$2"
        select choice in "${my_array[@]}";
        do
	    # shellcheck disable=SC2076
            if [[ ! " ${my_array[*]} " =~ " ${choice} " ]]; then
		invalid_input
            else
		break
            fi
        done
        break
    done
}

txt_input () {
    while true; do
        print_info "$1"
        read -r -e -p "$2" txt
        if [ -n "$txt" ]; then
            break
        else
            invalid_input
        fi
    done
}

passwd_input () {
    while true; do
        print_info "$1"
        read -r -s -p "$2" txt
        if [ -n "$txt" ]; then
            break
        else
            invalid_input
        fi
    done
}


fzf_menu() {
    # Start from the 2rd argument
    for ((i=2; i<$#; i++)); do
      local my_array=("${@:i:1}")
    done
    while true; do
        print_info "$1"
        choice=$(fzf --exact --reverse --prompt "$1" < <(printf "%s\n" "${my_array[@]}"))
	# shellcheck disable=SC2076
        if [[ ! " ${my_array[*]} " =~ " ${choice} " ]]; then
            invalid_input
        else
            break
        fi
    done
}

vm_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )       pacstrap /mnt qemu-guest-agent &>/dev/null
                    systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                    ;;
        vmware  )   pacstrap /mnt open-vm-tools &>/dev/null
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) pacstrap /mnt hyperv &>/dev/null
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
    esac
}
echo -e "${BOLD}${GREEN}\
ARCH INSTALLER
${RESET}\n"


mapfile -t partition_array < <(lsblk -rpno NAME,SIZE,TYPE | awk '$3 == "part" {print $1}')


mapfile -t disk_array < <(lsblk -dno NAME,SIZE | awk '{print "/dev/"$1}')
menu "\nSelect the disk to install GRUB on:" "Select disk: " "${disk_array[@]}"
install_disk="$choice"


# Select root partition
menu "\nPlease select the ROOT partition (this will be FORMATTED):" "Select ROOT partition: " "${partition_array[@]}"
root_partition="$choice"
print_choice "Root partition: $root_partition"

# Select home partition
menu "\nPlease select the HOME partition (this will NOT be formatted):" "Select HOME partition: " "${partition_array[@]}"
home_partition="$choice"
print_choice "Home partition: $home_partition"


# Format root partition
mkfs.ext4 "$root_partition" -L root

# Mount root
mount "$root_partition" /mnt


mapfile -t my_array < <(grep -E '^#[a-z]' /etc/locale.gen | cut -c 2- | awk '{print $1}')
fzf_menu "Please select a locale [ex: en_us.UTF-8]: " "${my_array[*]}"
locale="$choice"
print_choice "locale: $locale"


# Set keymap
mapfile -t my_array < <(localectl list-keymaps)
fzf_menu "Please select the keyboard layout [ex: us]: " "${my_array[*]}"
keymap="$choice"
print_choice "keymap: $keymap"
loadkeys "$keymap"

# Set timezone
mapfile -t my_array < <(timedatectl list-timezones)
fzf_menu "Please select the timezone: " "${my_array[*]}"
timezone="$choice"
print_choice "timezone: $timezone"

# Ask for hostname
txt_input "Set the hostname for this computer:" "Please enter hostname: "
hostname="$txt"
print_choice "hostname: $hostname"


# Set User password
txt_input "Create your user:" "Please enter desired username: "
username="$txt"
print_choice "username: $username"

while true; do
    passwd_input "User & Root password:" "Please enter a password for $username: "
    userpass1="$txt"
    passwd_input "" "Retype the password for $username: "
    userpass2="$txt"
    if [[ "$userpass1" != "$userpass2" ]]; then
        echo -e "\nPasswords do not match! Please try again."
    else
        print_choice "\nPassword successfully set for $username."
	userpass="$userpass1"
        break
    fi
done

# Summary of config
print_info "---------------------------------"
print_info "SUMMARY OF CONFIGURATION CHOICES:"
print_info "---------------------------------"
echo -e "Disk:\t\t${BOLD}${GREEN}$install_disk${RESET}"
echo -e "Root partition:\t${BOLD}${GREEN}$root_partition${RESET}"
echo -e "Home partition:\t${BOLD}${GREEN}$home_partition${RESET}"
echo -e "Locale:\t\t${BOLD}${GREEN}$locale${RESET}"
echo -e "Keymap:\t\t${BOLD}${GREEN}$keymap${RESET}"
echo -e "Timezone:\t${BOLD}${GREEN}$timezone${RESET}"
echo -e "Hostname:\t${BOLD}${GREEN}$hostname${RESET}"
echo -e "Root password:\t${BOLD}${GREEN}✓${RESET}"
echo -e "Username:\t${BOLD}${GREEN}$username${RESET}"
echo -e "User password:\t${BOLD}${GREEN}✓${RESET}"

print_info "${RED}WARNING! Please review the above configuration.${RESET}"

while true; do
    read -rp "$(echo -e "${BOLD}${YELLOW}Proceed with installation? (yes/no): ${RESET}")" confirm
    case "$confirm" in
        yes|YES|y|Y )
            print_info "${GREEN}Proceeding with installation...${RESET}"
            break
            ;;
        no|NO|n|N )
            print_info "${RED}Installation cancelled by user.${RESET}"
            exit 1
            ;;
        * )
            invalid_input
            ;;
    esac
done


# Install base packages from local file
print_info "Copying system files to the root partition."

# Copy everything *except* home (because home is separate)

unsquashfs -f -d /mnt "$SQUASHFS"

mount "$home_partition" /mnt/home

cp "$VMLINUZ" "$INITRAMFS" /mnt/boot/






# === Bind mounts for chroot ===
echo "[*] Preparing chroot environment"
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

# === Post-install configuration in chroot ===
echo "[*] Entering chroot and configuring system"
arch-chroot /mnt /bin/bash <<EOF
# Set hostname
echo "$hostname" > /etc/hostname

# Timezone and locale
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
sed -i "s/^#\s*$locale/$locale/" /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf
echo "KEYMAP=$keymap" > /etc/vconsole.conf

# Set /etc/hosts
cat > /etc/hosts <<EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOL

# Set root password
echo "root:$userpass" | chpasswd

# Create user and set passwords
useradd -m -G wheel -s /bin/bash $username
echo "$username:$userpass" | chpasswd
echo "root:$userpass" | chpasswd

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# FSTAB
genfstab -U  >> /etc/fstab

# Initramfs
mkinitcpio -c /etc/mkinitcpio.conf -g /boot/initramfs-linux.img

# Install GRUB for BIOS
grub-install --target=i386-pc --recheck "$install_disk"
grub-mkconfig -o /boot/grub/grub.cfg

# Enable essential services (optional)
systemctl enable NetworkManager || true


# Remove liveuser and its home directory if it exists
userdel -rf liveuser 2>/dev/null || true

# Remove xfce-wayland.desktop
rm /usr/share/wayland-sessions/xfce-wayland.desktop
EOF

exit


# === Cleanup ===
print_info "[*] Unmounting and cleaning up"
for d in run sys proc dev; do umount -l /mnt/$d || true; done
umount -l /mnt

print_info "[✔] Offline installation complete. Reboot and remove media."


