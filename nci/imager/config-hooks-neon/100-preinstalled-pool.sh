mkdir -vp config/gnupg
mkdir -vp config/indices

for component in $COMPONENTS; do
   (cd config/indices && \
    wget http://archive.ubuntu.com/ubuntu/indices/override.$SUITE.$component && \
    wget http://archive.ubuntu.com/ubuntu/indices/override.$SUITE.extra.$component \
   )
done
