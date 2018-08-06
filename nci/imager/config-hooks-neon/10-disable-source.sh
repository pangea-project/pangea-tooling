. /etc/os-release # to get access to version_codename; NB: of host container!

if [ "$VERSION_CODENAME" = "bionic" ]; then
  echo 'LB_SOURCE=false' >> config/source
fi
