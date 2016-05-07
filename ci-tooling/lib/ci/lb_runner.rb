require 'fileutils'

class LiveBuildRunner
  class Error < Exception; end
  class ConfigError < Error; end
  class BuildFailedError < Error; end

  def initialize(config_dir = Dir.pwd)
    @config_dir = config_dir
    Dir.chdir(@config_dir) do
      raise ConfigError unless File.exist?('configure') || Dir.exist?('auto')
    end
  end

  def configure!
    Dir.chdir(@config_dir) do
      system('./configure') if File.exist? 'configure'
      system('lb config') if Dir.exist? 'auto'
    end
  end

  def build!
    Dir.chdir(@config_dir) do
      begin
        raise BuildFailedError unless system('lb build')
        FileUtils.mkdir_p('result')
        @images = Dir.glob('*.{iso,tar}')
        FileUtils.cp(@images, 'result', verbose: true)
        latest_symlink
      ensure
        system('lb clean')
      end
    end
  end

  def latest_symlink
    # Symlink to latest
    Dir.chdir('result') do
      raise Error unless @images.size == 1
      latest = "latest#{File.extname(@images[0])}"
      File.rm(latest) if File.exist? latest
      FileUtils.ln_s(@images[0], latest)
    end
  end
end
