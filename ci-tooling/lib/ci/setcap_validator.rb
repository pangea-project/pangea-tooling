# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'drb/drb'
require 'yaml'

require_relative 'pattern'

module CI
  # DRB server side for setcap expecation checking.
  class SetCapServer
    def initialize
      @expected = load_data
      # Keep track of seen calls so we don't triper over multiple equal calls.
      @seen = []
      @master_thread = Thread.current
    end

    def check_expected(argv)
      return if expected?(argv)
      raise <<~ERRORMSG
        \n
        Unallowed call to: setcap #{argv.inspect}
        setcap must not be called. Build containers are run without a whole
        bunch of privileges which makes setcap non functional!
        Additionally, setcap uses xattrs which may not be available on the
        installation file system. Instead you should introduce a postinst
        call matching the setcap call with a fallback to setuid.
      ERRORMSG
    end

    def assert_all_called
      return if @expected.empty?
      raise <<~ERRORMSG
        A number of setcap calls were expected but didn't actually happen.
        This is indicative of the build no longer needing setcap. Check the code
        and if applicable make sure there no longer are postinst calls to setcap
        or setuid.
        Exepcted calls:
        #{@expected.collect(&:inspect).join("\n")}
      ERRORMSG
    end

    private

    def raise(*args)
      # By default DRB would raise the exception in the client (i.e. setcap)
      # BUT that may then get ignored on a cmake/whatever level so the build
      # passes even though we wanted it to fail.
      # To deal with this we'll explicitly raise into the master thread
      # (the thread that created us) rather than the current thread (which is
      # the drb service thread).
      @master_thread.raise(*args)
    end

    def expected?(argv)
      if @expected.delete(argv) || @seen.include?(argv)
        @seen << argv
        return true
      end
      false
    end

    def load_data
      array = YAML.load_file('debian/setcap.yaml')
      array.collect { |x| x.collect { |y| FNMatchPattern.new(y) } }
    rescue Errno::ENOENT
      []
    end
  end

  # Validator wrapper using setcap tooling to hijack setcap calls and
  # run them through a noop expectation check instead.
  class SetCapValidator
    def self.run
      validator = new
      validator.start
      validator.with_client { yield }
    ensure
      validator.stop
    end

    def start
      @server = DRb.start_service('druby://localhost:0', SetCapServer.new)
      ENV['PACKAGE_BUILDER_DRB_URI'] = @server.uri
    end

    def stop
      ENV.delete('PACKAGE_BUILDER_DRB_URI')
      @server.stop_service
      @server.thread.join # Wait for thread
      @server.front.assert_all_called
    end

    def with_client
      oldpath = ENV.fetch('PATH')
      # Do not allow setcap calls of any kind!
      Dir.mktmpdir do |tmpdir|
        populate_client_dir(tmpdir)
        # FIXME: also overwrite /sbin/setcap
        ENV['PATH'] = "#{tmpdir}:#{oldpath}"
        yield
      end
    ensure
      ENV['PATH'] = oldpath
    end

    private

    def populate_client_dir(dir)
      setcap = "#{dir}/setcap"
      FileUtils.cp("#{__dir__}/setcap.rb", setcap, verbose: true)
      FileUtils.chmod(0o755, setcap, verbose: true)
      return unless Process.uid.zero? # root
      FileUtils.cp(setcap, '/sbin/setcap') # overwrite original setcap
    end
  end
end

__END__

if [ "$1" = configure ]; then
    # If we have setcap is installed, try setting cap_net_bind_service,cap_net_admin+ep,
    # which allows us to install our helper binary without the setuid bit.
    if command -v setcap > /dev/null; then
        if setcap cap_net_bind_service,cap_net_admin+ep /usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper; then
            echo "Setcap worked! gst-ptp-helper is not suid!"
        else
            echo "Setcap failed on gst-ptp-helper, falling back to setuid" >&2
            chmod u+s /usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper
        fi
    else
        echo "Setcap is not installed, falling back to setuid" >&2
        chmod u+s /usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper
    fi
fi
