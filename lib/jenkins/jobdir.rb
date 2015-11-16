require 'fileutils'

module Jenkins
  class JobDir
    STATE_SYMLINKS = %w(
      lastFailedBuild
      lastStableBuild
      lastSuccessfulBuild
      lastUnstableBuild
      lastUnsuccessfulBuild
    )

    def self.age(file)
      ((Time.now - File.mtime(file)) / 60 / 60 / 24).to_i
    end

    def self.recursive?(file)
      return false unless File.symlink?(file)
      abs_file = File.absolute_path(file)
      abs_file_dir = File.dirname(abs_file)
      link = File.readlink(abs_file)
      abs_link = File.absolute_path(link, abs_file_dir)
      abs_link == abs_file
    end

    def self.prune(dir)
      buildsdir = "#{dir}/builds"
      return unless File.exist?(buildsdir)
      content = Dir.glob("#{buildsdir}/*")

      locked = []
      content.reject! do |d|
        # Symlink but points to itself
        next true if recursive?(d)
        # Symlink is not a static one, keep these
        next false unless STATE_SYMLINKS.include?(File.basename(d))
        # Symlink, but points to invalid target
        next true unless File.symlink?(d) && File.exist?(d)
        locked << File.realpath(d)
      end

      # Filter now locked directories
      content.reject! { |d| locked.include?(File.realpath(d)) }

      content.sort_by! { |c| File.basename(c).to_i }
      content[0..-6].each do |d| # Always keep the last 6 builds.
        log = "#{d}/log"
        archive = "#{d}/archive"
        next unless age(log) > 14
        FileUtils.rm(File.realpath(log)) if File.exist?(log)
        FileUtils.rm_r(File.realpath(archive)) if File.exist?(archive)
      end
    end
  end
end
