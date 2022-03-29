  Orange Pi 2G IOT run Linux in Nand
==========================================

This guide is for running Linux from the Nand on the Orange Pi 2G IOT board.  Thanks to all these sites for help:

[![Github All Releases](https://img.shields.io/github/downloads/xpack-dev-tools/openocd/total.svg)](https://github.com/xpack-dev-tools/openocd/releases/)

[range Pi IoT 2G Flashear memoria NAND](https://surfero.blogspot.com/2017/09/orange-pi-iot-2g-flashear-memoria-nand.html)
[install Linux to RDA nand Flash](https://blog.actorsfit.com/a?ID=00550-f9fa23ab-f71e-4a89-bef1-6870bb036794)
[SettinguptheLinux](http://www.orangepi.org/Docs/SettinguptheLinux.html)
[u-boot-RDA8810](https://github.com/aib/u-boot-RDA8810.git)
[OrangePiLibra](https://github.com/OrangePiLibra/OrangePi.git)
[opi2g-utils](https://github.com/aib/opi2g-utils)

I would not recommend buying this board if you are interested in using the cell connectivity since:

 - It only does 2G and carriers are dropping 2G support left and right.
 - The company behind the CPU (RDA Micro) seems to have gotten bought by a company that later went bandrupt.

Other than that, it's a reasonably fast board that has quite a few nice features.  This is the first time I've used a board with cell tower connectivity and it was so cheap I couldn't resist :)

1. Get repository and tools you will need.

```
git clone --recursive https://github.com/rickbronson/OrangePi2G-IOT-Run-Linux-in-Nand.git
cd OrangePi2G-IOT-Run-Linux-in-Nand
sudo apt-get update
sudo apt-get install -y u-boot-tools kpartx
```

2. We need to get a image to burn to the Nand so I chose DietPi.  If the following command doesn't work, Google the file name to see if it's moved.

```
wget https://raw.githubusercontent.com/zoums/zoums.github.io/master/image/DietPi_OrangePi-2G-IOT_sdcard.img.7z
7z x DietPi_OrangePi-2G-IOT_sdcard.img.7z

```

3. Put the switches to 1234 ON, 5678 OFF. Now run the script that makes the image we need to flash the Nand.  It will prompt you when to put the OrangePi2GIOT into USB mode.

```
./scripts/mkubi.sh [autologin] [ssid] [ssid-passcode]
```
4. Now unplug and re-plug the OrangePi2GIOT and it should run in Nand.  NOTE: The first time it runs it takes some time to boot so be patient.  Also note that you will need to put the switches back to 1234 OFF, 5678 ON if you want to use the USB Host connector.

5. Comments/suggestions

  Please contact me at rick AT efn DOT org
