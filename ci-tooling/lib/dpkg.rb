# Wrapper around dpkg commandline tool.
module DPKG
  private

  def self.run(cmd, args)
    args = [*args]
    puts "backticking: #{cmd} #{args.join(' ')}"
    output = `#{cmd} #{args.join(' ')}`
    puts $?
    return [] if $? != 0
    # FIXME: write test
    output.strip.split($/).compact
  end

  def self.dpkg(args)
    run('dpkg', args)
  end

  def self.architecture(var)
    run('dpkg-architecture', [] << "-q#{var}")[0]
  end

  public

  def self.const_missing(name)
    architecture("DEB_#{name}")
  end

  module_function

  def list(package)
    DPKG.dpkg([] << '-L' << package)
  end
end
