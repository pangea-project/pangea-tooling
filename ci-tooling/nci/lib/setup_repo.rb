require 'open-uri'

require_relative '../../lib/apt'
require_relative '../../lib/lsb'

# Neon CI specific helpers.
module NCI
  module_function

  def setup_repo!
    debline = "deb http://archive.neon.kde.org.uk/unstable #{LSB::DISTRIB_CODENAME} main"
    abort 'adding repo failed' unless Apt::Repository.add(debline)
    # FIXME: this needs to be in the module!
    IO.popen(['apt-key', 'add', '-'], 'w') do |io|
      io.puts open('http://archive.neon.kde.org.uk/public.key').read
      io.close_write
      puts io
    end
    abort 'Failed to import key' unless $? == 0
    abort 'apt updated failed' unless Apt.update
    abort 'failed to install deps' unless Apt.install(%w(pkg-kde-tools))
  end
end
