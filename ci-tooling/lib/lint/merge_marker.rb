require_relative 'result'

module Lint
  # Lints the presence of merge markers (i.e. <<< or >>>)
  class MergeMarker
    attr_reader :package_directory

    def initialize(package_directory = Dir.pwd)
      @package_directory = package_directory
    end

    # @return [Result]
    def lint
      result = Result.new
      result.valid = true
      Dir.glob("#{@package_directory}/**/**").each do |file|
        next if File.directory?(file)
        # Check filter. If this becomes too cumbersome, FileMagic offers a
        # reasonable solution to filetype checking based on mime.
        next if %w(.png .svgz .pdf).include?(File.extname(file))
        lint_file(result, file)
      end
      result
    end

    private

    def lint_file(result, path)
      File.open(path, 'r') do |file|
        file.each_line do |line|
          unless line.start_with?('<<<<<<< ') || line.start_with?('>>>>>>> ')
            next
          end
          result.errors << "File #{path} contains merge markers!"
          break
        end
      end
      result
    end
  end
end
