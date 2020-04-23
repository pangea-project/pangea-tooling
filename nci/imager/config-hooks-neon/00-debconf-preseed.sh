# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# preseed debconf selections

# - disable man-db updates, they are super slow and who even uses man-db...
cat << EOF > config/preseed/000-neon.preseed
man-db man-db/auto-update boolean false
EOF
