#!/bin/bash
#
#
# /usr/bin/openssl x509 -noout -modulus -in /etc/grid-security/hostcert.pem | /usr/bin/openssl md5
# /usr/bin/openssl rsa -noout -modulus -in /etc/grid-security/hostkey.pem | /usr/bin/openssl md5

usage()
{
	cat << EOF
	usage: $0 options
	This script validates SSL cert/key pairs. Exit code reflects match success. 
	OPTIONS:
	-h  Show this message
	-c  Certificate file [/etc/grid-security/hostcert.pem]
	-k  Certificate file [/etc/grid-security/hostkey.pem]
	-v  Verbose
EOF

}

CERTFILE=/etc/grid-security/hostcert.pem
KEYFILE=/etc/grid-security/hostkey.pem
VERBOSE=0

while getopts “hc:k:v” OPTION
do
     case $OPTION in
		h)
             usage
             exit 1
             ;;
		c)
             CERTFILE=$OPTARG
             ;;
        k)
             KEYFILE=$OPTARG
             ;;
         v)
             VERBOSE=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done


CERTFP=`/usr/bin/openssl x509 -noout -modulus -in $CERTFILE | /usr/bin/openssl md5 | awk '{ print $2}'`
KEYFP=`/usr/bin/openssl rsa -noout -modulus -in $KEYFILE | /usr/bin/openssl md5 | awk '{ print $2}'`


if [ $VERBOSE -eq 1 ] ; then
  	echo "Certfile is $CERTFILE"
   	echo "Keyfile is $KEYFILE"
   	echo "Verbose is $VERBOSE"
	echo "Cert fingerprint is $CERTFP"
	echo "Key fingerprint is $KEYFP" 
fi

if [ "$CERTFP" == "$KEYFP" ]; then
	echo "match"
	exit 0
else
	echo "nomatch"
	exit 1
fi






