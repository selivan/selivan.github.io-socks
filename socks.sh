#!/bin/bash
source /etc/lsb-release
if [ "$DISTRIB_ID $DISTRIB_CODENAME" = "Ubuntu xenial" ]; then

apt install -y dante-server libpam-pwdfile openssl
IFACE=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f5)

USER=user

if [ -z "$PORT" ]; then
        export PORT=8080
fi

if [ -z "$PASSWORD" ]; then
        # -s    do not echo input
        export PASSWORD=$( cat /dev/urandom | tr --delete --complement 'a-z0-9' | head --bytes=10 )
fi

PASSWD_FILE=/etc/danted.passwd

# -1    generate md5-based password hash
echo "$USER:$( openssl passwd -1 "$PASSWORD" )" > "$PASSWD_FILE"

cat > /etc/pam.d/sockd << EOF
auth required pam_pwdfile.so debug pwdfile=$PASSWD_FILE
account required pam_permit.so
EOF

cat > /etc/danted.conf <<EOF
internal: $IFACE port=$PORT
external: $IFACE

method: pam

user.privileged: root
user.notprivileged: nobody

client pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error
}

pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error
}
EOF
# Open port in firewall if required
if which ufw > /dev/null; then
        ufw allow "$PORT"/tcp
fi

systemctl restart danted.service

echo "Your socks proxy configuration:"
echo "IP: $( ip address show dev $IFACE | tr --squeeze-repeats ' ' | grep '^ inet ' | cut -d' ' -f3 | cut -d'/' -f1 )"
echo "Port: $PORT"
echo "User: $USER"
echo "Password: $PASSWORD"

else

echo "Sorry, this distribution is not supported"
echo "Feel free to send patches to selivan.github.io/socks to add support for more"
echo "Supported distributions:"
echo "- Ubuntu 16.04 Xenial"
exit 1

fi
