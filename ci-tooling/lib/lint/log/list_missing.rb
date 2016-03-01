require_relative '../linter'
require_relative 'build_log_segmenter'

module Lint
  class Log
    # Parses list-missing block from a build log.
    class ListMissing < Linter
      include BuildLogSegmenter

      def lint(data)
        r = Result.new
        data = segmentify(data,
                          "=== Start list-missing\n",
                          "=== End list-missing\n")
        r.valid = !data.empty?
        data.each do |line|
          r.errors << line
        end
        r
      end
    end
  end
end
