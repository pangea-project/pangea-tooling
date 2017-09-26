# frozen_string_literal: true
# Split a segment out of a build log by defining a start maker and an end marker
module BuildLogSegmenter
  class SegmentMissingError < StandardError; end

  module_function

  def segmentify(data, start_marker, end_marker)
    start_index = data.index(start_marker)
    end_index = data.index(end_marker)
    raise SegmentMissingError, "missing #{start_marker}" unless start_index
    raise SegmentMissingError, "missing #{end_marker}" unless end_index
    data = data.slice(start_index..end_index).split("\n")
    data.shift # Ditch start line
    data.pop # Ditch end line
    data
  end
end
