#!/bin/bash

# build up flags passed to this file on run + env flag for additional flags
# e.g. -e "ADDED_FLAGS=--tls=2"
PURE_FTPD_FLAGS="$@ $ADDED_FLAGS "

# start rsyslog
if [[ "$PURE_FTPD_FLAGS" == *" -d "* ]] || [[ "$PURE_FTPD_FLAGS" == *"--verboselog"* ]]
then
	echo "Log enabled, see /var/log/messages"
	rsyslogd
fi

# Load in any existing db from volume store
if [ -e /etc/pure-ftpd/passwd/pureftpd.passwd ]
then
    pure-pw mkdb /etc/pure-ftpd/pureftpd.pdb -f /etc/pure-ftpd/passwd/pureftpd.passwd
fi

# Generate TLS certification to Volume if pure-ftpd.pem is empty or flag --openssl-renew is set
if [[ "$PURE_FTPD_FLAGS" == *"--openssl-renew"* ]] || [ ! -e /home/ftpusers/.ftpssl/pure-ftpd.pem ]
then
    echo "Generate TLS"
    mkdir -p /home/ftpusers/.ftpssl
    openssl dhparam -out /home/ftpusers/.ftpssl/pure-ftpd-dhparams.pem 2048
    openssl req -x509 -nodes -newkey rsa:2048 -sha256 -subj $OPENSSL_SUBJ \
        -days 36500 -keyout /home/ftpusers/.ftpssl/pure-ftpd.pem \
        -out /home/ftpusers/.ftpssl/pure-ftpd.pem
fi

# Create symbolic link to TLS certification in Volume
cp /home/ftpusers/.ftpssl/*.pem /etc/ssl/private
ln -s /home/ftpusers/.ftpssl /etc/ssl/private

# detect if using TLS (from volumed in file) but no flag set, set one
if [ -e /etc/ssl/private/pure-ftpd.pem ] && [[ "$PURE_FTPD_FLAGS" != *"--tls"* ]]
then
    echo "TLS Enabled"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS --tls=1 "
fi

# let users know what flags we've ended with (useful for debug)
echo "Starting Pure-FTPd:"
echo "  pure-ftpd $PURE_FTPD_FLAGS"

# start pureftpd with requested flags
exec /usr/sbin/pure-ftpd $PURE_FTPD_FLAGS
