#!/bin/sh

memtotal=$(awk '/MemTotal/{print $2}' /proc/meminfo)

psd=$1
vname=$2
vpwd=$3

fdisk "$psd" < ./partition-scheme.fdisk

printf '%s' "$vpwd" | cryptsetup luksFormat "${psd}"2 -
printf '%s' "$vpwd" | cryptsetup --key-file - luksOpen "${psd}"2 cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate "$vname" /dev/mapper/cryptlvm
lvcreate -L "${memtotal}K" "$vname" -n swap
lvcreate -l 100%FREE "$vname" -n root

mkfs.fat -F32 "${psd}1"
mkfs.ext4 "/dev/${vname}/root"
mkswap "/dev/${vname}/swap"

mount "/dev/${vname}/root" /mnt
swapon "/dev/${vname}/swap"

mkdir -p /mnt/boot
mount "${psd}1" /mnt/boot
