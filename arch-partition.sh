#!/bin/sh

echo ''
echo '   Setting up partitioning...'
echo ''


### Parameter validation

eval_persistent_storage_device() {
    PROMPTED=0

    while ! valid_persistent_storage_device "$AI_PERSISTENT_STORAGE_DEVICE"; do
        prompt_persistent_storage_device
        PROMPTED=1
    done

    _PERSISTENT_STORAGE_DEVICE="$AI_PERSISTENT_STORAGE_DEVICE"

    if ! $PROMPTED; then
        echo "Path to persistent storage device: $_PERSISTENT_STORAGE_DEVICE"
    fi
}

eval_volume_name() {
    PROMPTED=0

    while ! valid_volume_name "$AI_VOLUME_NAME"; do
        prompt_volume_name
        PROMPTED=1
    done

    _VOLUME_NAME="$AI_VOLUME_NAME"

    if [ $PROMPTED = 0 ]; then
        echo "Encrypted volume name: $_VOLUME_NAME"
    fi
}

eval_volume_password() {
    PROMPTED=0

    while ! valid_volume_password "$AI_VOLUME_PASSWORD" "$AI_VOLUME_PASSWORD_CONFIRM"; do
        prompt_volume_password
        PROMPTED=1
    done

    _VOLUME_PASSWORD="$AI_VOLUME_PASSWORD"

    if ! $PROMPTED; then
        echo 'Encrypted volume password: ****'
    fi
}

prompt_persistent_storage_device() {
    printf 'Persistent storage device: '
    read -r AI_PERSISTENT_STORAGE_DEVICE
}

prompt_volume_name() {
    printf 'Volume name: '
    read -r AI_VOLUME_NAME
}

prompt_volume_password() {
    printf 'Encrypted volume password: '
    stty -echo
    read -r AI_VOLUME_PASSWORD
    echo ''

    printf 'Confirm encrypted volume password: '
    read -r AI_VOLUME_PASSWORD_CONFIRM
    stty echo
    echo ''
}

valid_persistent_storage_device() {
    if lsblk -l -o PATH,TYPE | awk -v stg="$1" '{ if (($1 == stg) && ($2 == "disk")) { exit 1 } }'; then
        return 1
    fi

    return 0
}

valid_volume_name() {
    if ! echo "$1" | grep -Eq '^[a-zA-Z][a-zA-Z0-9]*$'; then
        return 1
    fi

    return 0
}

valid_volume_password() {
    if [ -z "$1" ]; then
        return 1
    fi

    if [ "$1" != "$2" ]; then
        return 2
    fi

    return 0
}

eval_persistent_storage_device
eval_volume_name
eval_volume_password

_MEMTOTAL=$(awk '/MemTotal/{print $2}' /proc/meminfo)


### Generate and configure partition

 fdisk "$_PERSISTENT_STORAGE_DEVICE" < ./partition-scheme.fdisk

printf '%s' "$_VOLUME_PASSWORD" | cryptsetup luksFormat "${_PERSISTENT_STORAGE_DEVICE}2" -
printf '%s' "$_VOLUME_PASSWORD" | cryptsetup --key-file - luksOpen "${_PERSISTENT_STORAGE_DEVICE}2" cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate "$_VOLUME_NAME" /dev/mapper/cryptlvm
lvcreate -L "${$_MEMTOTAL}K" "$_VOLUME_NAME" -n swap
lvcreate -l 100%FREE "$_VOLUME_NAME" -n root

mkfs.fat -F32 "${_PERSISTENT_STORAGE_DEVICE}1"
mkfs.ext4 "/dev/${_VOLUME_NAME}/root"
mkswap "/dev/${_VOLUME_NAME}/swap"

mount "/dev/${_VOLUME_NAME}/root" /mnt
swapon "/dev/${_VOLUME_NAME}/swap"

mkdir -p /mnt/boot
mount "${_PERSISTENT_STORAGE_DEVICE}1" /mnt/boot