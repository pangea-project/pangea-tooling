EDITION=$(echo $NEONARCHIVE | sed 's,/, ,')
export LB_ISO_VOLUME="${IMAGENAME} ${EDITION} \$(date +%Y%m%d-%H:%M)"
export LB_ISO_APPLICATION="KDE neon Live"
