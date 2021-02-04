#! /bin/bash
BUILDDIR=$1
if [ -z $LIBXUL_SDK ] ; then
  LIBXUL_SDK=/usr/lib/thunderbird-devel/
fi
if [ -z $CACHE_DIR ] ; then
  CACHE_DIR=/tmp/
fi
if [ -f $LIBXUL_SDK/sdk/bin/typelib.py ]; then
  export PYTHONPATH=$PYTHONPATH:$LIBXUL_SDK/sdk/bin
  TYPELIB="python $LIBXUL_SDK/sdk/bin/typelib.py"
  OUT_SWITCH=-o
else
  TYPELIB="$LIBXUL_SDK/sdk/bin/xpidl -m typelib -w -v"
  OUT_SWITCH=-e
fi
COMPONENTS=$BUILDDIR/components
XPIDL_INCLUDE=$LIBXUL_SDK/idl/
XPIDL_INCLUDE_SELF=$COMPONENTS

for filename in $COMPONENTS/*.idl
do
  filetitle=`echo $filename|sed 's/\..\{3\}$//'`
  echo "Generating $filetitle.xpt from $filename..."
  $TYPELIB -I $XPIDL_INCLUDE -I $XPIDL_INCLUDE_SELF $OUT_SWITCH $filetitle.xpt $filename --cachedir=$CACHE_DIR

done

for filename in $COMPONENTS/*.idl
do
  rm $filename
done
