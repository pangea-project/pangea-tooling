require 'open-uri'
require 'tmpdir'

require_relative 'tarball'

module CI
  class WatchTarFetcher
    def initialize(watchfile)
      unless File.basename(watchfile) == 'watch'
        raise "path not a watch file #{watchfile}"
      end
      debiandir = File.dirname(File.absolute_path(watchfile))
      unless File.basename(debiandir) == 'debian'
        raise "path not a debian dir #{debiandir}"
      end
      @dir = File.dirname(debiandir)
    end

    def fetch(destdir)
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(@dir) do
          system('uscan',
                 '--verbose',
                 '--download-current-version',
                 "--destdir=#{tmpdir}",
                 '--rename')
        end
        tar = Dir.glob("#{tmpdir}/*.orig.tar*")
        return nil unless tar.size == 1
        tar = tar[0]
        FileUtils.cp(tar, destdir)
        return Tarball.new("#{destdir}/#{File.basename(tar)}")
      end
      nil
    end
  end

  class URLTarFetcher
    def initialize(url)
      @uri = URI.parse(url)
    end

    def fetch(destdir)
      filename = URI.unescape(File.basename(@uri.path))
      target = File.join(destdir, filename)
      puts "Downloading #{@uri}"
      File.write(target, open(@uri).read)
      puts "Tarball: #{target}"
      Tarball.new(target)
    end
  end

  # TODO fetch from a repo's deb-src?
  class RepoTarFetcher; end
end
