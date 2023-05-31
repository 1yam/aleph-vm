#!/bin/sh

set -euf

mount -t proc proc /proc -o nosuid,noexec,nodev

log() {
    echo "$(cat /proc/uptime | awk '{printf $1}')" '|S' "$@"
}
log "init0.sh is launching"

mkdir -p /dev/pts
mkdir -p /dev/shm

mount -t sysfs sys /sys -o nosuid,noexec,nodev
mount -t tmpfs run /run -o mode=0755,nosuid,nodev
#mount -t devtmpfs dev /dev -o mode=0755,nosuid
mount -t devpts devpts /dev/pts -o mode=0620,gid=5,nosuid,noexec
mount -t tmpfs shm /dev/shm -omode=1777,nosuid,nodev

# List block devices
lsblk

#cat /proc/sys/kernel/random/entropy_avail

# TODO: Move in init1
mkdir -p /run/sshd
/usr/sbin/sshd &
service nginx start
log "SSH UP"

log "Setup socat"
socat UNIX-LISTEN:/tmp/socat-socket,fork,reuseaddr VSOCK-CONNECT:2:53 &
log "Socat ready"

# Replace this script with the manager
exec /root/init1.py