#!/usr/bin/env bash
set -euxo pipefail

dnf5 -y install dracut dracut-live strip systemd-boot-unsigned systemd-ukify zstd sbsigntools squashfs-tools-ng plymouth ncdu
mkdir -p /mnt/rootdir

dnf5 -y --installroot=/mnt/rootdir --use-host-config \
--exclude='geolite2*' \
--exclude='bluez*' \
install @minimal-environment

dnf5 -y --installroot=/mnt/rootdir \
--setopt=install_weak_deps=False \
install kernel-modules-core kernel-core kernel-modules linux-firmware amd-gpu-firmware mt7xxx-firmware zstd dracut-live

dnf5 -y --installroot=/mnt/rootdir \
install bash-completion htop vim NetworkManager-wifi tmux cryptsetup gdisk man-db man-pages sudo

systemd-firstboot \
    --root=/mnt/rootdir \
    --reset

systemd-firstboot \
    --root=/mnt/rootdir \
    --setup-machine-id \
    --timezone=America/Vancouver \
    --hostname=fedora-recovery \
    --kernel-command-line="amdgpu.sg_display=0 rd.shell=0 root=live:LABEL=BOOT rd.live.dir=/LiveOS rd.live.squashimg=rootfs-zstd.squashfs rd.live.ram=1 rd.live.overlay.overlayfs=1 rd.live.overlay.readonly=1 rw"

chroot /mnt/rootdir systemctl set-default multi-user.target
sed -ri "s/^#? *PasswordAuthentication *yes.*/PasswordAuthentication no/" /mnt/rootdir/etc/ssh/sshd_config

chroot /mnt/rootdir useradd -m -G wheel live

# Root and live account passwords are recovery
printf "recovery" | chroot /mnt/rootdir passwd
printf "recovery" | chroot /mnt/rootdir passwd live

echo "live ALL=(ALL) NOPASSWD: ALL" > /mnt/rootdir/etc/sudoers.d/01-nopasswd-live
mkdir -p /mnt/rootdir/home/live/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl0++N1F1NIQ/YDWaPtp1STrCK39lcSvrf9Rp/rdDhQ" > /mnt/rootdir/home/live/.ssh/authorized_keys
chroot /mnt/rootdir chown -R live:live /home/live

rm -rf /mnt/rootdir/var/cache/*

KVER="$(chroot /mnt/rootdir rpm -q kernel-core --qf '%{version}-%{release}.%{arch}')"
mv /mnt/rootdir/usr/lib/modules/$KVER/vmlinuz /mnt
cp /mnt/rootdir/etc/os-release /mnt
sed -ri "s/^ID=.*$/ID=fedora-recovery/" /mnt/os-release
sed -ri "s/^PRETTY_NAME=\"(.*)\(.*\)\"$/PRETTY_NAME=\"\1(Recovery Image)\"/" /mnt/os-release

gensquashfs \
--force -q \
--pack-dir /mnt/rootdir \
--selinux /mnt/rootdir/etc/selinux/targeted/contexts/files/file_contexts \
--compressor zstd \
/mnt/rootfs-zstd.squashfs

mkdir -p /tmp/dracut
dracut --reproducible --no-hostonly --tmpdir /tmp/dracut -vf \
--zstd \
--kver "$KVER" \
--add 'dmsquash-live' \
--omit 'network-manager network ifcfg nfs' \
--sysroot /mnt/rootdir \
/mnt/initramfs.img

/usr/lib/systemd/ukify build \
--linux=/mnt/vmlinuz \
--initrd=/mnt/initramfs.img \
--cmdline="amdgpu.sg_display=0 rd.shell=0 root=live:LABEL=BOOT rd.live.dir=/LiveOS rd.live.squashimg=rootfs-zstd.squashfs rd.live.ram=1 rd.live.overlay.overlayfs=1 rd.live.overlay.readonly=1 rw" \
--os-release=@/mnt/os-release \
"--uname=$KVER" \
--output=/mnt/recovery.efi
