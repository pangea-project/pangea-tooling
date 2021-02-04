#!/usr/bin/make -f

DISTRIB_VERSION_MAJOR 	:= $(shell lsb_release -s -r | cut -d '.' -f 1)
DISTRIB_VERSION_MINOR 	:= $(shell lsb_release -s -r | cut -d '.' -f 2)
DISTRIB_CODENAME	:= $(shell lsb_release -s -c)

include $(CURDIR)/debian/config/branch.mk
-include /usr/share/cdbs/1/rules/buildvars.mk

# Various build defaults
# 1 = Build crashreporter (if supported)
MOZ_ENABLE_BREAKPAD	?= 0
# 1 = Build without jemalloc suitable for valgrind debugging
MOZ_VALGRIND		?= 0
# 1 = Profile guided build
MOZ_BUILD_PGO		?= 0
# 1 = Build and run the testsuite
MOZ_WANT_UNIT_TESTS	?= 0
# 1 = Turn on debugging bits and disable optimizations
MOZ_DEBUG		?= 0
# 1 = Disable optimizations
MOZ_NO_OPTIMIZE		?= 0

# The package name
MOZ_PKG_NAME		:= $(shell dpkg-parsechangelog | sed -n 's/^Source: *\(.*\)$$/\1/ p')
# The binary name to use (derived from the package name by default)
MOZ_APP_NAME		?= $(MOZ_PKG_NAME)

# Define other variables used throughout the build
MOZ_DEFAULT_APP_NAME	?= $(MOZ_PKG_BASENAME)

MOZ_FORCE_UNOFFICIAL_BRANDING = 0

ifeq (1,$(MOZ_VALGRIND))
MOZ_FORCE_UNOFFICIAL_BRANDING = 1
endif

ifneq (,$(findstring noopt,$(DEB_BUILD_OPTIONS)))
MOZ_BUILD_PGO = 0
MOZ_NO_OPTIMIZE	= 1
MOZ_FORCE_UNOFFICIAL_BRANDING = 1
endif

ifneq (,$(findstring debug,$(DEB_BUILD_OPTIONS)))
MOZ_NO_OPTIMIZE = 1
MOZ_DEBUG = 1
MOZ_FORCE_UNOFFICIAL_BRANDING = 1
endif

ifneq ($(MOZ_APP_NAME),$(MOZ_DEFAULT_APP_NAME))
# If we change MOZ_APP_NAME, don't use official branding
MOZ_FORCE_UNOFFICIAL_BRANDING = 1
endif

MOZ_LOCALE_PKGS	= $(strip $(shell dh_listpackages | grep $(MOZ_PKG_NAME)-locale-))

MOZ_LOCALES	:= $(shell sed -n 's/\#.*//;/^$$/d;s/\([^\:]*\)\:\?.*/\1/ p' < $(CURDIR)/debian/config/locales.shipped)
