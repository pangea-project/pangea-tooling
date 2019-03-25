# frozen_string_literal: true
#
# Copyright (C) 2016-2019 Harald Sitter <sitter@kde.org>
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
    data = fix_encoding(data)

    start_index = data.index(start_marker)
    raise SegmentMissingError, "missing #{start_marker}" unless start_index

    end_index = data.index(end_marker, start_index)
    raise SegmentMissingError, "missing #{end_marker}" unless end_index

    data = data.slice(start_index..end_index).split("\n")
    data.shift # Ditch start line
    data.pop # Ditch end line
    data
  end

  def fix_encoding(data)
    # Due to parallel building stdout can get messed up and contain
    # invalid byte sequences (rarely, and I am not entirely certain
    # how exactly) and that would result in ArgumentErrors getting thrown
    # when segmentifying **using a regex** as regexing asserts the
    # encoding being valid. To prevent this from causing problems
    # we'll simply re-encode and drop all invalid sequences.
    # This is a bit of a sledge hammer approach as it effectively could
    # drop unknown data, but this seems the most reliable option and
    # in the grand scheme of things the relevant portions we lint are all
    # ASCII anyway. Us dropping some random bytes printed during the
    # actual make portion should have no impact whatsoever.
    #
    # NB: this is only tested through dh_missing test. if that ever gets
    #   dropped this may end up without coverage, the check for valid encoding
    #   is only here so we can see this happening and eventually bring back test
    #   coverage
    return data if data.valid_encoding?

    data.encode('utf-8', invalid: :replace, replace: nil)
  end
end
