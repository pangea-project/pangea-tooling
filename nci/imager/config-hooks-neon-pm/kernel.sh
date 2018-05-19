# rename kernel and initrd to what syslinux expects
cat <<EOF > config/hooks/rename-kernel.binary
#!/bin/sh -e

find binary/casper

if [ ! -e binary/casper/initrd.lz ]; then
    echo "\$0: Renaming initramfs to initrd.lz..."
    zcat binary/casper/initrd.img-* | lzma -c > binary/casper/initrd.lz
    rm binary/casper/initrd.img-*
fi
if [ ! -e binary/casper/vmlinuz ]; then
    echo "\$0: Renaming kernel to vmlinuz..."
    # This will go wrong if there's ever more than one vmlinuz-* after
    # excluding *.efi.signed.  We can deal with that if and when it arises.
    for x in binary/casper/vmlinuz-*; do
	case \$x in
	    *.efi.signed)
		;;
	    *)
		mv \$x binary/casper/vmlinuz
		if [ -e "\$x.efi.signed" ]; then
		    mv \$x.efi.signed binary/casper/vmlinuz.efi
		fi
		;;
	esac
    done
fi
EOF
