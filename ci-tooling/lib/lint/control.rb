require_relative '../debian/control'
require_relative 'result'

module Lint
  # Lints a debian control file
  class Control
    attr_reader :package_directory

    def initialize(package_directory = Dir.pwd)
      @package_directory = package_directory
    end

    # @return [Result]
    def lint
      result = Result.new
      Dir.chdir(@package_directory) do
        control = DebianControl.new
        control.parse!
        result.valid = !control.source.nil?
        return result unless result.valid
        result = lint_vcs(result, control)
      end
      result
    end

    private

    def lint_vcs(result, control)
      unless control.source['Vcs-Browser']
        result.warnings << 'No Vcs-Browser field in control.'
      end
      unless control.source['Vcs-Git'] || control.source['Vcs-Bzr']
        result.warnings << 'No Vcs-Git or Vcs-Bzr field in contorl.'
      end
      result
    end
  end
end
