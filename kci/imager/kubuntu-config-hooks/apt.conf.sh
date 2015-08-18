rm config/chroot_apt/apt.conf
echo 'Debug::pkgProblemResolver "true";' >> config/chroot_apt/apt.conf
echo 'Acquire::Languages "none";' >> config/chroot_apt/apt.conf
