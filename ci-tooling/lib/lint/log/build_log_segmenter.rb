# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

# Split a segment out of a build log by defining a start maker and an end marker
module BuildLogSegmenter
  class SegmentMissingError < StandardError; end

  module_function

  def segmentify(data, start_marker, end_marker)
    start_index = data.index(start_marker)
    raise SegmentMissingError, "missing #{start_marker}" unless start_index

    end_index = data.index(end_marker, start_index)
    raise SegmentMissingError, "missing #{end_marker}" unless end_index

    data = data.slice(start_index..end_index).split("\n")
    data.shift # Ditch start line
    data.pop # Ditch end line
    data
  end
end
