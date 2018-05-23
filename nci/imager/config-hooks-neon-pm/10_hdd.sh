sed -i "s/^\\(LB_BINARY_IMAGES=\\).*/\\1\"hdd\"/" config/binary
sed -i "s/^\\(LB_BINARY_FILESYSTEM=\\).*/\\1\"ext4\"/" config/binary
