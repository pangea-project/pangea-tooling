# When a require fails it will attempt to install the gem for it.

module RubyManager
  @__got_ruby_dev = false

  def self._install_ruby_dev
    return if @__got_ruby_dev
    `echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup`
    `echo "Acquire::Languages "none";" > /etc/apt/apt.conf.d/99no-languages`
    exit 1 unless system('apt-get install -y ruby ruby-dev')
    @__got_ruby_dev = true
  end
end

module Kernel
  def install_and_require(name)
    puts "doing require_or_install on '#{name}'"
    begin
      require(name)
    rescue LoadError => e
      raise e unless Process.uid == 0
      RubyManager._install_ruby_dev
      gem = name.gsub('/', '-')
      puts "\t\t\trunning :: gem install #{gem} --no-document"
      exit 1 unless system("gem install #{gem} --no-document")
      Gem.clear_paths
      require(name)
    end
  end
end
