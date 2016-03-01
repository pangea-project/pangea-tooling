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
        # TODO: This doesn't really make sense? What does valid mean anyway?
        #  should probably be if the linting was able to be done, which is not
        #  asserted by this at all. segmentify would need to raise on
        # missing blocks
        r.valid = true
        data.each { |line| r.errors << line }
        r
      rescue BuildLogSegmenter::SegmentMissingError => e
        puts "#{self.class}: in log #{e.message}"
        r
      end
    end
  end
end
