env
if [ "$VERSION_CODENAME" = "bionic" ]; then
  echo 'LB_SOURCE=false' >> config/source
fi
