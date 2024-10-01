#!/bin/bash

# Arch Linux Installation Script for Dell G15 5515
# This script assumes you're running from an Arch Linux live environment

# Set variables
ROOT_PARTITION="/dev/nvme0n1p2"
USERNAME="rabbitScripter"
TIMEZONE="Africa/Cairo"

# Format partition
mkfs.ext4 $ROOT_PARTITION

# Mount partitions
mount $ROOT_PARTITION /mnt
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

# Install base system
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash << EOF

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "arch-dell-g15" > /etc/hostname

# Set root password
echo "Set root password:"
passwd

# Install and configure bootloader (GRUB)
pacman -S grub efibootmgr os-prober --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Modify GRUB for NVIDIA
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& nvidia-drm.modeset=1/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Install necessary packages
pacman -S networkmanager sddm plasma konsole firefox nvidia nvidia-utils nvidia-settings --noconfirm

# Enable services
systemctl enable NetworkManager
systemctl enable sddm

# Install yay
pacman -S git --noconfirm
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# Install additional packages
pacman -S zed alacritty  --noconfirm

# Create the user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "Set password for $USERNAME:"
passwd $USERNAME

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# NVIDIA driver setup
# Modify mkinitcpio.conf
sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
sed -i 's/HOOKS=([^)]*kms[^)]*/HOOKS=(&)/' /etc/mkinitcpio.conf
sed -i 's/kms //' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P

# Create NVIDIA hook
mkdir -p /etc/pacman.d/hooks/
cat << EOT > /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOT

EOF

# Unmount partitions
umount -R /mnt

echo "Installation complete. You can now reboot into your new Arch Linux system."
