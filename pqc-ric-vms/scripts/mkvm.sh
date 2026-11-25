#!/bin/bash
# Create one RIC VM on .28: Ubuntu 20.04 cloud image, macvtap on enp86s0 (host network untouched),
# static lab IP via cloud-init. Usage: sudo bash mkvm.sh <name> <ip-last-octet> <vcpus> <ram-MB> <disk-GB>
set -eu
NAME=$1; OCT=$2; CPU=$3; RAM=$4; DISK=$5
D=/var/lib/libvirt/images/pqc-ric; cd $D
MAC=52:54:00:4a:04:$OCT
qemu-img create -f qcow2 -F qcow2 -b $D/focal-base.img $NAME.qcow2 ${DISK}G >/dev/null
cat > $NAME-user-data <<UD
#cloud-config
hostname: $NAME
manage_etc_hosts: true
users:
  - name: snsrl
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx1t7oNfrnToOB4yD9CgLSxrKAZ+burxM/eGyLcBTVq snsrl-lab-testbed
ssh_pwauth: false
package_update: false
runcmd:
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
UD
cat > $NAME-network-config <<NC
version: 2
ethernets:
  lab0:
    match:
      macaddress: "$MAC"
    set-name: lab0
    addresses: [10.230.4.$OCT/20]
    gateway4: 10.230.0.1
    nameservers:
      addresses: [10.250.200.3]
NC
printf "instance-id: $NAME-1\nlocal-hostname: $NAME\n" > $NAME-meta-data
cloud-localds -N $NAME-network-config $NAME-seed.iso $NAME-user-data $NAME-meta-data
virt-install --name $NAME --vcpus $CPU --memory $RAM --cpu host-passthrough \
  --disk path=$D/$NAME.qcow2,format=qcow2,bus=virtio --disk path=$D/$NAME-seed.iso,device=cdrom \
  --network type=direct,source=enp86s0,source_mode=bridge,model=virtio,mac=$MAC \
  --os-variant ubuntu20.04 --import --graphics none --noautoconsole --autostart >/dev/null
echo "created $NAME: 10.230.4.$OCT, $CPU vCPU, $RAM MB, ${DISK} GB"
