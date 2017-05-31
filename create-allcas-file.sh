#!/bin/bash
#
# Create properly formatted ca-bundle file in /etc/grid-security/certificates/
#
#

CADIR=/etc/grid-security/certificates
ALLCAS=$CADIR/allcas.pem
echo "Removing old allcas.pem file."
rm -f $ALLCAS
echo "Merging CA files in $CADIR..."
for file in `ls $CADIR/*.0`; do
	echo "Processing $file..."
	openssl x509 -in $file -text >> $ALLCAS
done
echo "Done."
