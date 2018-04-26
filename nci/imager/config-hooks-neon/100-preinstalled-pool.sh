mkdir -vp config/gnupg
mkdir -vp config/indices

# Make sure we usea  suitably strong digest algorithm. SHA1 is deprecated and
# makes apt angry.
cat > config/gnupg/gpg.conf <<EOF
personal-digest-preferences SHA512
cert-digest-algo SHA512
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
EOF

for component in $COMPONENTS; do
   (cd config/indices && \
    wget http://archive.ubuntu.com/ubuntu/indices/override.$SUITE.$component && \
    wget http://archive.ubuntu.com/ubuntu/indices/override.$SUITE.extra.$component \
   )
done
