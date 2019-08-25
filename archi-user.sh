#!/bin/sh

echo ''
echo '   Setting up user...'
echo ''


### Initialize arguments
ARG_USERNAME=$1


### Verify and install sudo
pacman -Qkq sudo 2> /dev/null

if [ ! $? = 0 ]; then
  pacman -Sy sudo
fi


### Create user
ARCH_USERNAME=''

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


### Set password
PASSWD_RESULT=1

while [ ! $PASSWD_RESULT = 0 ]; do
  passwd -q "$ARCH_USERNAME"

  PASSWD_RESULT=$?
done


### Configure wheel group access to sudo
sed -i 's/^# %wheel ALL=(ALL) ALL$/%wheel ALL=(ALL) ALL/' /etc/sudoers


### Lock root account
passwd -l -q root