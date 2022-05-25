# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Install grub shebang in container. lb's grub-efi is a bit conflicted on
# which files to get from the host and which to get from the chroot so best
# have it on both ends.
apt install -y \
  shim-signed \
  grub-efi-amd64-signed \
  grub-efi-ia32-bin
