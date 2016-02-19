require 'open-uri'

require_relative '../../lib/apt'
require_relative '../../lib/lsb'

# Neon CI specific helpers.
module NCI
  module_function

  def setup_repo_key!
    # FIXME: this needs to be in the apt module!
    IO.popen(['apt-key', 'add', '-'], 'w') do |io|
      io.puts open('http://archive.neon.kde.org.uk/public.key').read
      io.close_write
      puts io
    end
  end

  def setup_repo!
    debline = format('deb http://archive.neon.kde.org.uk/unstable %s main',
                     LSB::DISTRIB_CODENAME)
    abort 'adding repo failed' unless Apt::Repository.add(debline)
    setup_repo_key!
    abort 'Failed to import key' unless $? == 0
    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }
    abort 'failed to install deps' unless Apt.install(%w(pkg-kde-tools))
  end
end
