# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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

require 'test/unit'
require 'tmpdir'
require 'webmock/test_unit'

require_relative 'assert_xml'

# Deal with a require-time expecation here. docker.rb does a version coercion
# hack at require-time which will hit the socket. As we install webmock above
# already it may be active by the time docker.rb is required, making it
# necessary to stub the expecation.
WebMock.stub_request(:get, 'http://unix/v1.16/version')
       .to_return(body: '{"Version":"17.03.0-ce","ApiVersion":"1.26","MinAPIVersion":"1.12"}')

# Test case base class handling fixtures and chdirring to not pollute the source
# dir.
class TestCase < Test::Unit::TestCase
  include EquivalentXmlAssertations

  ATFILEFAIL = 'Could not determine the basename of the file of the' \
               ' class inheriting TestCase. Either flatten your inheritance' \
               ' graph or set the name manually using `self.file = __FILE__`' \
               ' in class scope.'.freeze

  class << self
    attr_accessor :file
    # attr_accessor :required_binaries
    def required_binaries(*args)
      @required_binaries ||= []
      @required_binaries += args.flatten
    end
  end

  def self.autodetect_inherited_file
    caller_locations.each do |call|
      next if call.label.include?('inherited')
      path = call.absolute_path
      @file = path if path.include?('/test/')
      break
    end
    fail ATFILEFAIL unless @file
  end

  def self.inherited(subclass)
    super(subclass)
    subclass.autodetect_inherited_file unless @file
  end

  # Automatically issues omit() if binaries required for a test are not present
  # @param binaries [Array<String>] binaries to check for (can be full path)
  def require_binaries(*binaries)
    binaries.flatten.each do |bin|
      next if system("type #{bin} > /dev/null 2>&1")
      omit("#{self.class} requires #{bin} but #{bin} is not in $PATH")
    end
  end

  def assert_is_a(obj, expected)
    actual = obj.class.ancestors | obj.class.included_modules
    diff = AssertionMessage.delayed_diff(expected, actual)
    format = <<EOT
<?> expected but its ancestors and includes are at the very least
<?>.?
EOT
    message = build_message(message, format, expected, actual, diff)
    assert_block(message) { obj.is_a?(expected) }
  end

  def priority_setup
    ENV['PANGEA_UNDER_TEST'] = '1'
    raise ATFILEFAIL unless self.class.file
    ENV.delete('BUILD_NUMBER')
    script_base_path = File.expand_path(File.dirname(self.class.file))
    script_name = File.basename(self.class.file, '.rb')
    @datadir = File.join(script_base_path, 'data', script_name)
    @previous_pwd = Dir.pwd
    @tmpdir = Dir.mktmpdir(self.class.to_s.tr(':', '_'))
    Dir.chdir(@tmpdir)
    require_binaries(self.class.required_binaries)

    Retry.disable_sleeping if defined?(Retry)

    # Make sure we reset $?, so tests can freely mock system and ``
    reset_child_status!
    #FIXME: Drop when VCR gets fixed
    WebMock.enable!

    # Enable test case interception and make sure
    stub_request(:get, 'https://projects.kde.org/kde_projects.xml')
      .to_return(body:
         File.read("#{__dir__}/../data/kde_projects_stripped.xml"))
  end

  def priority_teardown
    Dir.chdir(@previous_pwd)
    FileUtils.rm_rf(@tmpdir)
  end

  def _method_name
    return @method_name if defined?(:@method_name)
    index = 0
    caller = ''
    until caller.start_with?('test_')
      caller = caller_locations(index, 1)[0].label
      index += 1
    end
    caller
  end

  def data(path = nil)
    caller = _method_name
    file = File.join(*[@datadir, caller, path].compact)
    return file if File.exist?(file)
    raise "Could not find data path #{file}"
  end

  # Different from data in that it does not assume ext will be a directory
  # but a simple extension. i.e.
  # data/caller.foo instead of data/caller/foo
  def fixture_file(ext)
    caller = _method_name
    file = File.join(*[@datadir, "#{caller}#{ext}"].compact)
    return file if File.exist?(file)
    raise "Could not find data file #{file}"
  end

  def fake_home(home = Dir.pwd, &block)
    home_ = ENV.fetch('HOME')
    ENV['HOME'] = home
    block.yield
  ensure
    ENV['HOME'] = home_
  end

  def reset_child_status!
    system('true') # Resets $? to all good
  end
end
