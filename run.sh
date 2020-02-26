#!/bin/bash

if ! [ -f disk.qcow ]; then
    echo No disk prepared. Creating...
    sudo ./alpine-make-vm-image --image-format qcow2 --image-size 2G --repositories-file example/repositories --packages "$(cat example/packages)" --script-chroot disk.qcow -- ./example/configure.sh
	sudo chown $USER:$USER disk.qcow
else
    echo Using existing disk.qcow disk
fi

echo Ready to go. Exposing ssh on port 2222 of host.
echo Use 'CTRL-A C' to switch to monitor.
if qemu-img snapshot -l disk.qcow | grep init; then
    snapshot="-loadvm init"
fi
qemu-system-x86_64 -hda disk.qcow -enable-kvm -net nic -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 -localtime -m 1024 -nographic $snapshot

# KVM notes:
# $ sudo usermod -aG kvm $(whoami)
# Log out and log in to join the new group
