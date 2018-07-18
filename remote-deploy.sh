#!/bin/sh
sudo mount /dev/mmcblk0p1 /mnt

if [ -f zImage ]; then
    sudo cp zImage /mnt
	mv zImage zImage.installed
fi

if [ -f u-boot-with-spl.sfp ]; then
	sudo dd if=u-boot-with-spl.sfp of=/dev/mmcblk0p3 bs=1024
	mv u-boot-with-spl.sfp u-boot-with-spl.sfp.installed
fi

sync
sync
sudo umount /mnt
