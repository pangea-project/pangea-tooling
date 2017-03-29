#!/bin/bash
./appimagetool-x86_64.AppImage -v -s -u "zsync|$APPIMAGEFILENAME" /app.Dir/ /appimages/$APPIMAGEFILENAME
zsyncmake -u "https://s3-eu-central-1.amazonaws.com/ds9-apps/$PROJECT-master-appimage/$APPIMAGEFILENAME" -o /appimages/$APPIMAGEFILENAME.zsync /appimages/$APPIMAGEFILENAME
./appimagetool-x86_64.AppImage -v -s -u "zsync|$PROJECT-latest-$ARCH.AppImage" /app.Dir/ /appimages/$PROJECT-latest-$ARCH.AppImage
zsyncmake -u "https://s3-eu-central-1.amazonaws.com/ds9-apps/$PROJECT-master-appimage/$PROJECT-latest-$ARCH.AppImage" -o /appimages/$PROJECT_latestversion.zsync /appimages/$APPIMAGEFILENAME
