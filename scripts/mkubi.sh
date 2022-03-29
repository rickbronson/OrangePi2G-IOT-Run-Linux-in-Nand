#!/bin/bash
# some of this borrowed from https://blog.actorsfit.com/a?ID=00550-f9fa23ab-f71e-4a89-bef1-6870bb036794
# and http://surfero.blogspot.com/2017/09/orange-pi-iot-2g-flashear-memoria-nand.html
# parameters: image to flash

# wget https://raw.githubusercontent.com/zoums/zoums.github.io/master/image/DietPi_OrangePi-2G-IOT_sdcard.img.7z
# 7z x DietPi_OrangePi-2G-IOT_sdcard.img.7z
# iso=dietpi_OrangePi-2G-IOT_sdcard.img
# iso=OrangePi_2G-iot_debian_stretch_server_linux3.10.62_v0.0.4.img
# pv "$iso" | sudo dd bs=1M iflag=fullblock oflag=direct,sync of=/dev/sdb

# on target you need to do:
# sudo apt-get update
# sudo apt-get install -y u-boot-tools kpartx

# call like ./scripts/mkubi [autologin] [ssid] [ssid-passcode]

set -x

PIUSER=dietpi
PROJ=${PWD}
AUTOLOGIN=$1
SSID=$2
PASS=$3
# make a dietpi SD card and boot into it, edit /boot/network/interfaces to attach to your wifi

# transfer this script to your target (on your target):
# scp rick@192.168.2.9:/home/rick/boards/orangepi-iot/scripts/mkubi.sh .

# make the files first

sudo rm -rf nandbuild
mkdir nandbuild
cd nandbuild
# get rid of some fluff
cat > cpfs.filter << EOF
- /var/backup/*
- /var/cache/apt/archives/*
- /var/log/*
- /var/tmp/*
- /usr/src/linux-headers*
- /usr/share/doc/*
- /usr/share/man/*
- /boot/System.map-3.10.62-rel5.0.2+
- /boot/initrd.img-3.10.62-rel5.0.2+
EOF

cat > fstab << EOF
ubi0:nandroot / ubifs  defaults  0 1
tmpfs/tmp  tmpfs nodev,nosuid,mode=1777  0 0	
EOF

# cat > boot.cmd << EOF
#setenv bootargs  "mtdparts=rda_nand:64M@0(bootloader),-(nandrootfs) root=\${rootdev} rootwait rootfstype=\${rootfstype} console=ttyS0,921600 panic=10 consoleblank=0 loglevel=\${verbosity} \${extraargs} \${extraboardargs}"
# EOF

cat > boot-nand.cmd << EOF

setenv ubiargs "ubi.mtd=1"
setenv rootdev "ubi0:nandroot"
setenv rootfstype "ubifs"

setenv bootargs "\${ubiargs} \${mtdparts} root=\${rootdev} rootwait rootfstype=\${rootfstype} console=ttyS0,921600 panic=10 consoleblank=0 loglevel=8 \${extraargs} \${extraboardargs}"

ubifsload \${initrd_addr} "/boot/uInitrd"
ubifsload \${kernel_addr} "/boot/zImage"
ubifsload \${modem_addr} "/boot/modem.bin"

mdcom_loadm \${modem_addr}
mdcom_check 1

bootz \${kernel_addr} \${initrd_addr}
EOF

cat > ubinize.ini << EOF
  [nandroot-volume]
  mode=ubi
  image=nandroot.img
  vol_id=0
  vol_name=nandroot
  vol_size=480MiB
  vol_type=dynamic
  vol_alignment=1
EOF

do_autologin () {
sudo mkdir -p ${DEST}/etc/systemd/system/serial-getty@ttyS0.service.d
  sudo bash -c "cat << EOF > ${DEST}/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf
[Service]
ExecStart=
ExecStart=/sbin/agetty -o '-p -- \u' --keep-baud 921600 --noclear --autologin $PIUSER ttyS0 vt220
EOF"
  sudo bash -c "echo /dev/ttyS0 > ${DEST}/etc/pishelltty"
  sudo sed -i -e "1s|^|auth sufficient pam_listfile.so item=tty sense=allow file=/etc/pishelltty onerr=fail apply=$PIUSER\n|" ${DEST}/etc/pam.d/login
}

# start of script

DEST=nandroot

sudo rm -rf rootfs boot
mkdir -p rootfs boot
sudo kpartx -av ${PROJ}/dietpi_OrangePi-2G-IOT_sdcard.img > /tmp/loop
LOOP1=`cat /tmp/loop | head -1 | sed -n -e "s/add map \([^ ]*\).*/\1/gp"`
LOOP2=`cat /tmp/loop | tail -1 | sed -n -e "s/add map \([^ ]*\).*/\1/gp"`
sudo mount /dev/mapper/${LOOP1} boot
sudo mount /dev//mapper/${LOOP2} rootfs

sudo rm -rf $DEST
mkdir -p $DEST
sudo rsync -a -x --delete --delete-excluded rootfs/* boot $DEST -f "merge cpfs.filter"
sudo mkimage -C none -A arm -T script -d boot-nand.cmd $DEST/boot/boot-nand.scr
sudo cp fstab $DEST/etc/fstab
sudo sed -i -e "s|http.*|http://legacy.raspbian.org/raspbian/ jessie main contrib non-free|g" $DEST/etc/apt/sources.list
sudo rm $DEST/lib/systemd/systemd-backlight  # fix "Failed to start Load/Save Screen Backlight Brightnes" issue

cp ${PROJ}/u-boot-RDA8810/u-boot.rda ${PROJ}/u-boot-RDA8810/pdl*.bin .

read -t 0 # flush buffer
if [ "${AUTOLOGIN}" = "autologin" ]; then
		do_autologin
else
		read -p "Type y if would you like to enable autologin for serial connection: " -n 1 ANSWER
		if [ "${ANSWER}" = "y" ] ; then
				do_autologin
		fi
fi

if [ "${SSID}" != "" -a "${PASS}" != "" ]; then
    sudo sed -i -e "s/^wpa-ssid.*/wpa-ssid ${SSID}/" -e "s/^wpa-psk.*/wpa-psk ${PASS}/" ${DEST}/boot/network/interfaces
else		
		read -p "Type ssid if would you like auto attach to your router and hit <Enter>:" SSID
		if [ "${SSID}" != "" ] ; then
				read -p "Type passcode and hit <Enter>:" PASS
				if [ "${PASS}" != "" ] ; then
						sudo sed -i -e "s/^wpa-ssid.*/wpa-ssid ${SSID}/" -e "s/^wpa-psk.*/wpa-psk ${PASS}/" ${DEST}/boot/network/interfaces
				fi
		fi
fi

# make the ubi filesystem: mkfs.ubifs -r <root-fs> -m <min i/o size> -e <logical erase block size> -c <max erase blocks> -o <output file>
sudo mkfs.ubifs -e 248KiB -m 4096 -c 2000 -r $DEST -o nandroot.img
ubinize -p 256KiB -m 4096 ubinize.ini -o ubi.img

# cleanup
sudo umount boot rootfs
sudo rm -rf rootfs boot
sudo kpartx -d ${PROJ}/dietpi_OrangePi-2G-IOT_sdcard.img
# sudo losetup -d /dev/loop9

# power up with button held down and do:
echo  "Set the toggle switch 1234 ON, 5678 OFF"
echo -n "Hold button down while plugging target into to this machine with USB cable, then push any key"; read
../opi2g-utils/opi2g_nand_write.py -p/dev/ttyACM0 --format-flash --pdl1 pdl1.bin --pdl2 pdl2.bin bootloader:u-boot.rda nandroot:ubi.img

# to restore to Android:
#cd extracted; ../opi2g-utils/opi2g_nand_write.py --format-flash -v bootloader:bootloader.img modem:modem.img boot:boot.img system:system.img vendor:vendor.img
