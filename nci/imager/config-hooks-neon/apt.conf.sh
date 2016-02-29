rm config/chroot_apt/apt.conf || true
echo 'Debug::pkgProblemResolver "true";' >> config/chroot_apt/apt.conf
echo 'Acquire::Languages "none";' >> config/chroot_apt/apt.conf
