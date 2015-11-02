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

    def self.prune_logs(dir)
      buildsdir = "#{dir}/builds"
      return unless File.exist?(buildsdir)
      content = Dir.glob("#{buildsdir}/*")

      locked = []
      content.reject! do |d|
        next false unless STATE_SYMLINKS.include?(File.basename(d))
        locked << File.realpath(d)
      end

      # Filter now locked directories
      content.reject! { |d| locked.include?(File.realpath(d)) }
      # Filter directories that have no log anymore
      content.reject! { |d| !File.exist?("#{d}/log") }

      content.sort_by! { |c| File.basename(c).to_i }
      content[0..-6].each do |d| # Always keep the last 6 builds.
        file = "#{d}/log"
        next unless age(file) > 14
        FileUtils.rm(File.realpath(file))
      end
    end
  end
end
