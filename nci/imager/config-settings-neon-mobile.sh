EDITION=$(echo $NEONARCHIVE | sed 's,/, ,')
export LB_ISO_VOLUME="${IMAGENAME} ${EDITION} Plasma Mobile \$(date +%Y%m%d-%H:%M)"
export LB_ISO_APPLICATION="KDE neon Plasma Mobile Live"
export LB_LINUX_FLAVOURS="generic-hwe-20.04"
export LB_LINUX_PACKAGES="linux"
