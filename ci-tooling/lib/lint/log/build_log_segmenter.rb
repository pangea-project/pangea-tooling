# Split a segment out of a build log by defining a start maker and an end marker
module BuildLogSegmenter
  module_function

  def segmentify(data, start_marker, end_marker)
    start_index = data.index(start_marker)
    end_index = data.index(end_marker)
    return [] unless start_index && end_index
    data = data.slice(start_index..end_index).split("\n")
    data.shift # Ditch start line
    data.pop # Ditch end line
    data
  end
end
