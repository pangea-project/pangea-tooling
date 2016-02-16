require 'test/unit'
require 'tmpdir'

# Test case base class handling fixtures and chdirring to not pollute the source
# dir.
class TestCase < Test::Unit::TestCase
  ATFILEFAIL = 'Could not determine the basename of the file of the' \
               ' class inheriting TestCase. Either flatten your inheritance' \
               ' graph or set the name manually using `self.file = __FILE__`' \
               ' in class scope.'

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
    fail ATFILEFAIL unless self.class.file
    ENV.delete('BUILD_NUMBER')
    script_base_path = File.expand_path(File.dirname(self.class.file))
    script_name = File.basename(self.class.file, '.rb')
    @datadir = File.join(script_base_path, 'data', script_name)
    @previous_pwd = Dir.pwd
    @tmpdir = Dir.mktmpdir(self.class.to_s.gsub(':', '_'))
    Dir.chdir(@tmpdir)
    require_binaries(self.class.required_binaries)
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
    fail "Could not find data file #{file}"
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
