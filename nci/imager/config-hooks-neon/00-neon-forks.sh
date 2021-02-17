#!/bin/sh
# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Ensure neon forks are installed. This is similar to neon-forks.chroot as
# build-hook but runs before live-build and thus allow us to preempt
# ambiguous errors by using incorrect components.
#
# When one of these isn't form us it likely means it has gotten outscored
# by an ubuntu version in -updates and needs merging.

# All CI builds force the maintainer to be neon so this is a trivial way to
# determine the origin of the package without having to meddle with dpkg-query
# format strings and the like or going through apt.

pkgs="livecd-rootfs"
for pkg in $pkgs; do
  if dpkg-query -s $pkg | grep --fixed-strings --quiet '<neon@kde.org>'; then
    echo "$pkg is from neon ✓"
  else
    echo "error: $pkg does not come from neon - talk to a dev to get it updated"
    exit 1
  fi
done
