# 1. Create the two VMs on the host

**Why VMs:** the host already runs other people's Kubernetes cluster and containers. VMs give us
our own kernel, Kubernetes and firewall without touching them. They also give the O-RAN SC
installer the Ubuntu 20.04 it is written for.

| VM | IP | vCPU | RAM | Disk |
|---|---|---|---|---|
| `ric-nearrt` | 10.230.4.43 | 12 | 24 GB | 200 GB |
| `ric-smo` | 10.230.4.44 | 8 | 24 GB | 200 GB |

**Network settings:**
- Lab range 10.230.4.25–.55, mask 255.255.240.0 (/20), gateway 10.230.0.1, DNS 10.250.200.3.
- Register the IPs in the lab sheet first, and check they don't answer ping.

## On the host (once)

```bash
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils genisoimage
sudo usermod -aG libvirt,kvm $USER
sudo mkdir -p /var/lib/libvirt/images/pqc-ric && cd /var/lib/libvirt/images/pqc-ric
sudo wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -O focal-base.img
```

## Create the VMs

`scripts/mkvm.sh <name> <last IP octet> <vCPU> <RAM MB> <disk GB>`:

```bash
sudo bash mkvm.sh ric-nearrt 43 12 24576 200
sudo bash mkvm.sh ric-smo    44  8 24576 200
sudo virsh list --all
```

**Details:**
- **Network:** the VMs use **macvtap** on the host's `enp86s0`, so the host's own network settings
  don't change. As a side effect, the host itself cannot reach the VMs, but every other lab
  machine can.
- **Cloud-init:** sets the static IP, user `snsrl` with an SSH key (put your own public key in
  `mkvm.sh`), passwordless sudo, and swap off.
- **Autostart:** both VMs start when the host boots.

## Use them

```bash
ssh snsrl@10.230.4.43          # ric-nearrt
ssh snsrl@10.230.4.44          # ric-smo
sudo virsh shutdown ric-nearrt # on the host: clean power off
sudo virsh start ric-nearrt    # on the host: power on (pods come back in ~5 min)
```

## Campus internet

New IPs must log in to the campus portal before HTTPS works. Ping and DNS work without it, which is
misleading.

```bash
bash ~/portal_login.sh         # inside each VM; asks for the username and password, stores nothing
```

Run it again whenever downloads hang.
