EDITION=$(echo $NEONARCHIVE | sed 's,/, ,')
export LB_ISO_VOLUME="${IMAGENAME} ${EDITION} Mobile \$(date +%Y%m%d)"
export LB_ISO_APPLICATION="KDE neon Plasma Mobile Live"
export LB_LINUX_FLAVOURS="generic-hwe-22.04"
export LB_LINUX_PACKAGES="linux"
