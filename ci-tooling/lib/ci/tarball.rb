require 'tmpdir'

module CI
  # A tarball handling class.
  class Tarball
    attr_reader :path

    def initialize(path)
      @path = File.absolute_path(path)
    end

    def to_s
      @path
    end
    alias to_str to_s

    def orig?
      self.class.orig?(@path)
    end

    # Change tarball path to Debian orig format.
    # @return New Tarball with orig path or existing Tarball if it was orig.
    #         This method copies the existing tarball to retain
    #         working paths if the path is being changed.
    def origify
      return self if orig?
      clone.origify!
    end

    # Like {origify} but in-place.
    # @return [Tarball, nil] self if the tarball is now orig, nil if it was orig
    def origify!
      return nil if orig?
      name = File.basename(@path)
      dir = File.dirname(@path)
      match = name.match(/(?<name>.+)-(?<version>[\d.]+)\.(?<ext>tar(.*))/)
      raise "Could not parse tarball #{name}" unless match
      old_path = @path
      @path = "#{dir}/#{match[:name]}_#{match[:version]}.orig.#{match[:ext]}"
      FileUtils.cp(old_path, @path) if File.exist?(old_path)
      self
    end

    # @param dest path to extract to. This must be the actual target
    #             for the directory content. If the tarball contains
    #             a single top-level directory it will be renamed to
    #             the basename of to_dir. If it contains more than one
    #             top-level directory or no directory all content is
    #             moved *into* dest.
    def extract(dest)
      Dir.mktmpdir do |tmpdir|
        system('tar', '-xf', path, '-C', tmpdir)
        content = list_content(tmpdir)
        if content.size > 1 || !File.directory?(content[0])
          FileUtils.mkpath(dest) unless Dir.exist?(dest)
          FileUtils.cp_r(content, dest)
        else
          FileUtils.cp_r(content[0], dest)
        end
      end
    end

    def self.orig?(path)
      # FIXME: copied from debian::version's upstream regex
      !File.basename(path).match(/(.+)_([A-Za-z0-9.+:~-]+?)\.orig\.tar(.*)/).nil?
    end

    private

    # Helper to include hidden dirs but strip self and parent refernces.
    def list_content(path)
      content = Dir.glob("#{path}/*", File::FNM_DOTMATCH)
      content.reject { |c| %w(. ..).include?(File.basename(c)) }
    end
  end
end
