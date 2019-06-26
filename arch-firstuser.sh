#!/bin/sh

ARG_USERNAME=$1

ARCH_USERNAME=''

echo ''
echo '   Setting up first user...'

pacman -Qkq sudo 2> /dev/null

if [ ! $? = 0 ]; then
  pacman -Sy sudo
fi

while [ -z "$ARCH_USERNAME" ]; do
  printf 'Username: '

  if [ -z "$ARG_USERNAME"]; then 
    read -r ARCH_USERNAME
  else
    printf "$ARG_USERNAME\n"
    ARCH_USERNAME="$ARG_USERNAME"
  fi

  useradd -m -G wheel -s /bin/sh "$ARCH_USERNAME"

  if [ ! $? = 0 ]; then
    ARG_USERNAME=''
    ARCH_USERNAME=''
  fi
done

PASSWD_RESULT=1

while [ ! $PASSWD_RESULT = 0 ]; do
  passwd -q "$ARCH_USERNAME"

  PASSWD_RESULT=$?
done

sed -i 's/^# %wheel ALL=(ALL) ALL$/%wheel ALL=(ALL) ALL/' /etc/sudoers

passwd -l -q root
