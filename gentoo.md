Gentoo Documentation
====================

* TOC
{:toc}

Installation
------------

### System Rescue CD

The following options are helpful:  

* `setkmap='de'` to set the keyboard layout to German
* `rootpass=geheim` set root password to `geheim` so you can directly ssh into
  the system
* note as default the English keyboard layout is present = is \`

**connect via ssh**:  
If we have set `rootpass=` boot parameter we can directly connect via ssh. If
you use a live CD to install Gentoo the host identification often changes. (each
time you boot) you can bypass the check of ssh with the following two options.

```
-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
```

### Prepare the Disk

Layout:  

- swap
- btrfs

```console
# parted -a optimal /dev/sdX
```

Setup parted to use Megabyte.

```console
(parted) unit mib
```

```console
# generate new partition table
# ! Caution this will delete all data.
(parted) mktable
gpt
yes
# create the grub partition.
(parted) mkpart primary 1 3
(parted) name 1 grub
(parted) set 1 bios_grub on
# create the needed partitions.
(parted) mkpart primary 3 6000
(parted) name 2 swap
(parted) mkpart primary 6000 100%
(parted) name 3 rootfs
(parted) set 3 boot on 
(parted) quit
```

### Prepare the Filesystem 

**SWAP Partition**:  
Now create the swap partition with label and enable it.

```console
# mkswap -L SWAP /dev/sd[swap]
# swapon /dev/sd[swap]
```

**Remaining Partitions**:  
Now create the rest of the filesystem either with `btrfs` if you want or with
`ext4` we will proceed with btrfs as we want to heavy use subvolumes and
snapshots later.

Now we create our partition model with btrfs subvolumes.

```console
# mkfs.btrfs -L ROOTFS /dev/sd[rootfs]
# mount /dev/sd[rootfs] /mnt
# cd /mnt
# btrfs subvolume create __active  
# btrfs subvolume create __active/boot
# btrfs subvolume create __active/root
# btrfs subvolume create __active/home  
# btrfs subvolume create __snapshots  
```

The reason for having rootvol on a dedicated subvolume is that it makes
recovering from snapshots easier than if home and var were children of rootvol.
Mount the subvolumes:


to see the list of all subvolumes including the quota ids:

```console
# btrfs subvolume list -pt <path>
```

### Mount the Partitions

```console
# cd  
# umount /mnt  
# mkdir /mnt/gentoo
# mount -o subvol=__active/root /dev/sd[rootfs] /mnt/gentoo
# mkdir /mnt/gentoo/{home,boot}  
# mount -o subvol=__active/boot /dev/sd[rootfs] /mnt/gentoo/boot
# mount -o subvol=__active/home /dev/sd[rootfs] /mnt/gentoo/home  
```

### Stage3

use elinks on a gentoo server to get the files.

```console
# cd /mnt/gentoo
# elinks https://www.gentoo.org/downloads/mirrors
```

Select a mirror and go to `releases/amd64/autobuilds/` download with key `D`

Finaly unpack the stage3 file:  

```console
# tar xvjpf stage3* --xattrs
```

Make sure that the same options (xvjpf and --xattrs) are used. The x stands for
Extract, the v for Verbose to see what happens during the extraction process
(optional), the j for Decompress with bzip2, the p for Preserve permissions and
the f to denote that we want to extract a File, not standard input. Finally,
the --xattrs is to include the extended attributes stored in the archive as
well.

### Chroot into new system.

```console
# cd /mmt/gentoo
# mount -t proc proc proc
# mount --rbind /sys sys
# mount --make-rslave sys
# mount --rbind /dev dev
# mount --make-rslave dev
# cp -L /etc/resolv.conf etc
# chroot . /bin/bash
# source /etc/profile
```

to easy repeat the chrooting process write the following mount options and
network copy into a script. make it executable

```bash
$ chmod u+x startChroot.sh
```

### Portage

Sync the portage tree. Later we will switch over to git portage tree.

```console
# mkdir /usr/portage
# emerge-webrsync
```

### User accounts

Change the root password:

```console
# passwd
```
Create user(s):

```console
# useradd -g users -G wheel,portage,audio,video,usb,cdrom -m USERNAME
# passwd USERNAME
```

There are no spaces allowed between the groups.

### Configure your system

#### /etc/fstab

```
LABEL=ROOTFS    /       btrfs           subvol=__active/root,noatime    0 1
LABEL=ROOTFS    /home   btrfs           subvol=__active/home,noatime    0 1
LABEL=ROOTFS    /boot   btrfs           subvol=__active/boot,noatime    0 1
LABEL=SWAP      none    swap            sw                              0 0
```

#### /etc/portage/make.conf

we will skip this file here as we will configure it after reboot.

#### Timezone

Set the appropriate timezone:

```console
# ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
```

#### systemD

##### locale

###### /etc/env.d/02locale

```
LANG="de_DE.UTF-8"
LC_COLLATE="C"
```

```console
# eselect locale list

Available targets for the LANG variable:
    [1]   C *
    [2]   POSIX
    [3]   en_GB
    [4]   en_GB.iso88591
    [5]   en_GB.utf8
    [  ]   (free form)
```

```console
# eselect locale set 5
# source /etc/profile 
```

Now we need to inform systemd of our choice. Issue: 

```console
# localectl set-locale LANG="${LANG}" LC_COLLATE="C" 
```

##### Keymap

```console
# localectl list-keymaps | grep -i de
# localectl set-keymap de
# loadkeys de
# localectl --no-convert set-x11-keymap de
```

#### openRC

##### /etc/env.d/02locale

```
LANG="de_DE.UTF-8"
LC_COLLATE="C"
```

##### Keymap

Edit /etc/conf.d/keymaps


### Kernel

The sys-kernel/gentoo-sources package is the vanilla kernel with the Gentoo
patchset applied. Choose between kernel sources. The sys-kernel/linux-firmware
package contains binary blobs needed for some hardware (wlan cards). 

If sys-kernel/gentoo-sources has been selected: 

```console
# emerge -av sys-kernel/gentoo-sources sys-kernel/linux-firmware
# cd /usr/src/linux
```

If everything is working in the livecd we can fasten the config generation with:

```console
# make localyesconfig
```

now we need to disable the initrd by selecting `General Setup` and disabling
`CONFIG_BLK_DEV_INITRD`:

```console
# make menuconfig
```

```
--> General Setup
    ...
    [ ] Initial RAM filesystem and RAM disk (initramfs/initrd) support
    ...
```



Then build and install the kernel

```console
# make -j2
# make modules_install
# make install
```

### Bootloader

Specify the correct setting for the system's firmware. BIOS/MBR is `pc`, 64-bit
UEFI is `efi-64`, 32-bit UEFI is `efi-32`:  
32-bit UEFI is rare to find on PCs. Mostly older Apple hardware use this. It
has nothing to do with the Gentoo architecture chosen.

For PC BIOS

/etc/portage/make.conf

```
GRUB_PLATFORMS="pc"
```

For 64-bit UEFI

/etc/portage/make.conf

```
GRUB_PLATFORMS="efi-64"
```

Emerge grub:

```console
# emerge --ask sys-boot/grub 
```

Supposing the system has PC BIOS:

```console
# grub-install /dev/sda
```

Supposing the system has UEFI firmware: 

```console
# grub-install --target=x86_64-efi /dev/sda
```

Use the grub-mkconfig command to generate the configuration file:
Note that if you choose to use systemd you need to enable it first by:
```
# /etc/default/grub
# uncomment or add folling line
GRUB_CMDLINE_LINUX="init=/usr/lib/systemd/systemd rootfstype=btrfs"
```
this will enable systemd and tell grub that our rootfs is btrfs and he has not
to guess the filesystem. Then finaly create config.

```console
# grub-mkconfig -o /boot/grub/grub.cfg

Found vmlinuz-3.14.4-gentoo
```

### Networktools

Ensure that after reboot network is working, therefore install the needed tools.

```console
# emerge --ask net-misc/dhcpcd
```

### Final Note for SystemD

To ensure systemD can boot create a machine-id file by:

```console
# touch /etc/machine-id
```

to enable network after reboot.

```console
# systemctl enable dhcpcd
# systemctl start dhcpcd
# systemctl enable sshd
# systemctl start sshd
```

### Clean up

Exit chroot, unmount partitions, and reboot:

```console
# exit
# cd /mnt
# umount -R gentoo
# reboot 
```

[TOP](#gentoo-documentation)
