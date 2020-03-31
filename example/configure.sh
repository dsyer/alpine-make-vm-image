#!/bin/sh

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}


step 'Set up timezone'
setup-timezone -z Europe/Prague

step 'Set up networking'
cat > /etc/network/interfaces <<-EOF
	iface lo inet loopback
	iface eth0 inet dhcp
EOF
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \qq
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Enable services'
rc-update add acpid default
rc-update add crond default
rc-update add sshd default
rc-update add net.eth0 default
rc-update add net.lo boot
rc-update add termencoding boot

step 'Adjust sshd_conf'
AUSER=dsyer
adduser -D -u 1000 -s /bin/bash $AUSER $AUSER
adduser $AUSER wheel
sed -e 's;^# \(%wheel.*NOPASSWD.*\);\1;g' -i /etc/sudoers
sed -i -e "s/$AUSER:!/$AUSER:*/" /etc/shadow
mkdir -p /home/$AUSER/.ssh
chown $AUSER:$AUSER /home/$AUSER/.ssh
chmod 700 /home/$AUSER/.ssh
cat << EOF > /home/$AUSER/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4yvDJ+mZfpMbCaPuZJ4jVmFHbTiN3ksCOvWj/4n9occuM0hMSqGlIvQ3686XB2ZUmxnN7Z4LGNS4eFYTdRZ6XXoEfdXXJBKMKLZwr5YBJasIV7bBiTFjX6lJDOkzRK0G5qyjO29z2nW3JfoReBXLzOOITuLj0bjWZTUsdrQ4tmOlPUtVe30yql/06YWcdn0jII1PASDw2yrRvbeOFM/nig3zElzb6+m8V5Y9BQ5HyDd6sdMTCwWiYWC1/S6EOmvB3HadbeNdH4LjoEgXGBJ/6u5icavpWQOmFQ5M/ZLkkfokkCIQQEIUHdFVGx5y4myvVPWEGQ79aOpVrBr1WxaJDw== dsyer_rsa
EOF
chown $AUSER:$AUSER /home/$AUSER/.ssh/*
chmod 600 /home/$AUSER/.ssh/*

#echo root:root | chpasswd
#sed -i -e 's/.PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i -e 's/.PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
