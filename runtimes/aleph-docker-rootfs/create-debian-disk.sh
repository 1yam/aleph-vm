#!/bin/sh

umount /mnt/vm
rm ./rootfs.ext4
rm -fr ./rootfs
mkdir -p ./rootfs
mkdir -p /mnt/vm

set -euf

# Create a 1,5 GB partition
dd if=/dev/zero of=rootfs.ext4 bs=1MB count=1500
mkfs.ext4 rootfs.ext4
mount rootfs.ext4 /mnt/vm

rm -rf ./docker-image
docker buildx build -t docker-image --output type=local,dest=./docker-image .
cp -vap ./docker-image/. ./rootfs/

chroot ./rootfs /bin/sh <<EOT

set -euf

apt-get install -y --no-install-recommends --no-install-suggests \
  python3-minimal \
  openssh-server \
  socat libsecp256k1-0 \
  \
  python3-aiohttp python3-msgpack \
  python3-setuptools \
  python3-pip python3-cytoolz python3-pydantic \
  iproute2 unzip \
  nodejs npm \
  build-essential python3-dev \
  \
  docker.io \
  cgroupfs-mount \
  nftables \
  \
  iputils-ping curl

pip3 install 'fastapi~=0.71.0'

echo "Pip installing aleph-client"
pip3 install 'aleph-client>=0.4.6' 'coincurve==15.0.0'

# Compile all Python bytecode
python3 -m compileall -f /usr/local/lib/python3.9

echo "root:toor" | /usr/sbin/chpasswd

# Set up a login terminal on the serial console (ttyS0):
ln -s agetty /etc/init.d/agetty.ttyS0
echo ttyS0 > /etc/securetty
EOT

echo "PermitRootLogin yes" >> ./rootfs/etc/ssh/sshd_config

# Generate SSH host keys
#systemd-nspawn -D ./rootfs/ ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
#systemd-nspawn -D ./rootfs/ ssh-keygen -q -N "" -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key
#systemd-nspawn -D ./rootfs/ ssh-keygen -q -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
#systemd-nspawn -D ./rootfs/ ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

cat <<EOT > ./rootfs/etc/inittab
# /etc/inittab

::sysinit:/sbin/init sysinit
::sysinit:/sbin/init boot
::wait:/sbin/init default

# Set up a couple of getty's
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

# Put a getty on the serial port
ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt100

# Stuff to do for the 3-finger salute
::ctrlaltdel:/sbin/reboot

# Stuff to do before rebooting
::shutdown:/sbin/init shutdown
EOT

# Reduce size
rm -fr ./rootfs/root/.cache
rm -fr ./rootfs/var/cache
mkdir -p ./rootfs/var/cache/apt/archives/partial
rm -fr ./rootfs/usr/share/doc
rm -fr ./rootfs/usr/share/man
rm -fr ./rootfs/var/lib/apt/lists/

# Custom init
cp ./init0.sh ./rootfs/sbin/init
cp ./init1.py ./rootfs/root/init1.py
chmod +x ./rootfs/sbin/init
chmod +x ./rootfs/root/init1.py

cp -pr ./rootfs/. /mnt/vm
umount /mnt/vm