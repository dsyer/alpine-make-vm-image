#!/bin/bash

start_time="$(date -u +%s.%N)"
if qemu-img snapshot -l disk.qcow | grep server; then
    snapshot="-loadvm server"
fi
qemu-system-x86_64 -hda disk.qcow -enable-kvm -net nic -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 -localtime -m 512 $snapshot &
while ! curl localhost:8080 2>&1 > /dev/null; do
	sleep 0.01
done
end_time="$(date -u +%s.%N)"
curl -w '\n' localhost:8080
elapsed="$(bc <<< $end_time-$start_time)"
echo "Total of $elapsed seconds elapsed for process"
pkill qemu
