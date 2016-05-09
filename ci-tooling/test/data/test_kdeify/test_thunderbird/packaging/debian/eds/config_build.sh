#!/bin/bash

# Build config for the build script, build.sh. Look there for more info.

APP_NAME=edsintegration
CHROME_PROVIDERS="content locale res"
CLEAN_UP=1
ROOT_FILES=
ROOT_DIRS="components"
BEFORE_BUILD=
BEFORE_PACK="sh make_interface.sh build"
AFTER_BUILD=
