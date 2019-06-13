#!zsh

ARCH_INSTALL_CHARACTER_SET=""
ARCH_INSTALL_ENCRYPTED_VOLUME_PASSWORD=""
ARCH_INSTALL_HOSTNAME=""
ARCH_INSTALL_KEYMAP=""
ARCH_INSTALL_LOCAL_DOMAIN=""
ARCH_INSTALL_LOCALE=""
ARCH_INSTALL_LOCALTIME=""
ARCH_INSTALL_PACKAGES=('base')
ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE=""

while [ -z "$ARCH_INSTALL_KEYMAP" ]; do 
  printf 'Keyboard layout: '
  read ARCH_INSTALL_KEYMAP
 
  if [ -z "$(find /usr/share/kbd/keymaps/ -name ${ARCH_INSTALL_KEYMAP}.map.gz -printf 1)" ]; then
    ARCH_INSTALL_KEYMAP=''
    echo 'Keyboard layout not found.'
  fi
done

loadkeys $ARCH_INSTALL_KEYMAP

while [ -z "$ARCH_INSTALL_LOCALTIME" ]; do
  printf 'Local time zone: '
  read ARCH_INSTALL_LOCALTIME

  if [ ! -e "/usr/share/zoneinfo/${ARCH_INSTALL_LOCALTIME}" ]; then
    ARCH_INSTALL_LOCALTIME=''
    echo 'Time zone not found.'
  fi
done

while [ -z "$ARCH_INSTALL_LOCALE" ]; do
  printf 'Locale: '
  read ARCH_INSTALL_LOCALE

  if [ ! -e "/usr/share/i18n/locales/${ARCH_INSTALL_LOCALE}" ]; then
    ARCH_INSTALL_LOCALE=''
    echo 'Locale not found.'
  fi
done

while [ -z "$ARCH_INSTALL_CHARACTER_SET" ]; do
  printf 'Character set: '
  read ARCH_INSTALL_CHARACTER_SET

  if [ ! -e "/usr/share/i18n/charmaps/${ARCH_INSTALL_CHARACTER_SET}.gz" ]; then
    ARCH_INSTALL_CHARACTER_SET=''
    echo 'Character set not found.'
  fi
done

while [ -z "$ARCH_INSTALL_HOSTNAME" ]; do
  printf 'Hostname: '
  read ARCH_INSTALL_HOSTNAME
done

while [ -z "$ARCH_INSTALL_LOCAL_DOMAIN" ]; do
  printf 'Local domain: '
  read ARCH_INSTALL_LOCAL_DOMAIN
done

while [ -z "$ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE" ]; do
  printf 'Path to persistent storage device: '
  read ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE
  
  if [ -z "$(lsblk -l -o PATH,TYPE | awk -v stg="$ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE" '{ if (($1 == stg) && ($2 == "disk")) { print 1 } }')" ]; then
    ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE=''
    echo 'Persistent storage device not found.'
  fi 
done

while [ -z "$ARCH_INSTALL_ENCRYPTED_VOLUME_PASSWORD" ]; do
  printf 'Encrypted volume password: '
  read -s ARCH_INSTALL_ENCRYPTED_VOLUME_PASSWORD
  echo 'Go'

  printf 'Confirm encrypted volume password: '
  read -s confirm
  echo ''

  if [ ! "$ARCH_INSTALL_ENCRYPTED_VOLUME_PASSWORD" = "$confirm" ]; then
    ARCH_INSTALL_ENCRYPTED_VOLUME_PASSWORD=''
    echo 'Confirmation password does not match.'
  fi
done

timedatectl set-ntp true

./prepare-disk.sh $ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE $ARCH_INSTALL_HOSTNAME $ARCH_INSTALL_ENCRYPTED_VOLUME_PASSWORD

uuid=$(lsblk -o PATH,UUID | awk -v stg="${ARCH_INSTALL_PERSISTENT_STORAGE_DEVICE}2" '($1 == stg) {print $2}')

initrd=()

if [ -n "$(cat /proc/cpuinfo | awk '($1 == "vendor_id" && $3 == "GenuineIntel") {print 1}')" ]; then
  ARCH_INSTALL_PACKAGES+=('intel-ucode')
  initrd+=('initrd /intel-ucode.img')
elif [ -n "$(cat /proc/cpuinfo | awk '($1 == "vendor_id" && $3 == "AuthenticAMD") {print 1}')" ]; then
  ARCH_INSTALL_PACKAGES+=('amd-ucode')
  initrd+=('initrd /amd-ucode.img')
fi

initrd+=('initrd /initramfs-linux.img')

echo ${(j:\n:)ARCH_INSTALL_PACKAGES} | pacstrap /mnt -

genfstab -U /mnt >> /mnt/etc/fstab

cat <<SETUP > /mnt/root/setup.sh

ln -sf /usr/share/zoneinfo/${ARCH_INSTALL_LOCALTIME} /etc/localtime

hwclock --systohc 

echo "${ARCH_INSTALL_LOCALE} ${ARCH_INSTALL_CHARACTER_SET}" > /etc/locale.gen

locale-gen

echo "LANG=${ARCH_INSTALL_LOCALE}" > /etc/locale.conf

echo "KEYMAP=${ARCH_INSTALL_KEYMAP}" > /etc/vconsole.conf

echo "${ARCH_INSTALL_HOSTNAME}" > /etc/hostname

bootctl --path=/boot install

cat <<HOSTS > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${ARCH_INSTALL_HOSTNAME}.${ARCH_INSTALL_LOCAL_DOMAIN} ${ARCH_INSTALL_HOSTNAME}
HOSTS

cat <<MKINITCPIO > /etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
MKINITCPIO

cat <<ENTRY > /boot/loader/entries/${uuid}.conf
title Arch Linux
linux /vmlinuz-linux
${(pj:\n:)initrd}
options cryptdevice=UUID=${uuid}:cryptlvm resume=/dev/${ARCH_INSTALL_HOSTNAME}/swap root=/dev/${ARCH_INSTALL_HOSTNAME}/root
ENTRY

cat <<LOADER > /boot/loader/loader.conf
timeout 0
default ${uuid}
editor 0
LOADER

mkinitcpio -p linux
SETUP

chmod +x /mnt/root/setup.sh

arch-chroot /mnt /root/setup.sh

rm /mnt/root/setup.sh

umount -R /mnt

reboot
