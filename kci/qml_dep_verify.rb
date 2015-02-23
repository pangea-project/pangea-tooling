require 'pp'

# Wrapper around dpkg commandline tool.
module DPKG
  private

  def self.run(cmd, args)
    args = [*args]
    output = `#{cmd} #{args.join(' ')}`
    return [] if $? != 0
    output.strip.split($RS).compact
  end

  def self.dpkg(args)
    run('dpkg', args)
  end

  def self.architecture(var)
    run('dpkg-architecture', [] << '--query' << var)[0]
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

# Management construct for QML related bits.
module QML
  BUILTINS = %w(QtQuick)
  SEARCH_PATHS = ["/usr/lib/#{DPKG::HOST_MULTIARCH}/qt5/qml"]

  # Describes a QML module.
  class Module
    IMPORT_SEPERATOR = '.'

    attr_reader :identifier
    attr_reader :version
    attr_reader :qualifier

    def self.parse(line)
      new.send(:parse, line)
    end

    def builtin?
      BUILTINS.include?(identifier)
    end

    def import_paths
      @import_paths if defined?(@import_paths)
      @import_paths = []
      base_path = @identifier.gsub(IMPORT_SEPERATOR, File::SEPARATOR)
      @import_paths << base_path
      version_parts = @version.split('.')
      version_parts.each_index do |i|
        @import_paths << "#{base_path}.#{version_parts[0..i].join('.')}"
      end
      @import_paths
    end

    def to_s
      "#{@identifier}[#{@version}]"
    end

    private

    def parse(line)
      minsize = 3 # import + name + version
      return nil unless line && !line.empty?
      parts = line.split(/\s/)
      return nil unless parts.size >= minsize
      parts.delete_if { |str| str.nil? || str.empty? }
      return nil unless parts.size >= minsize && parts[0] == 'import'
      @identifier = parts[1]
      @version = parts[2]
      # FIXME: what if part 3 is not as?
      @qualifier = parts[4] if parts.size == 5
      self
    end
  end
end

package_map = {
  'org.kde.plasma.plasmoid' => 'plasma-framework',
  'org.kde.plasma.configuration' => 'plasma-framework'
}

missing_modules = []

packages = %w(plasma-nm plasma-widgets-addons)
packages.each do |package|
  if Process.uid == 0
    # FIXME: need to fail otherwise, the results will be skewed
    `sudo apt-get --purge #{package}`
    `sudo apt-get --purge autoremove`
  end

  files = DPKG.list(package).select { |f| File.extname(f) == '.qml' }

  # TODO: THREADING!

  modules = []
  files.each do |file|
    lines = File.read(file).lines
    lines.each do |l|
      m = QML::Module.parse(l)
      modules << m if m
    end
  end

  modules.each do |mod|
    found = false
    static_package = package_map.fetch(mod.identifier, nil)
    if static_package
      # FIXME: move to dpkg module
      found = system("dpkg -s #{static_package} 2>&1 > /dev/null")
    else
      # FIXME: beyond path this currently doesn't take version into account
      QML::SEARCH_PATHS.each do |search_path|
        mod.import_paths.each do |import_path|
          path = File.join(search_path, import_path, 'qmldir')
          found = File.exist?(path) && File.file?(path)
          break if found
        end
        break if found
      end
    end
    missing_modules << mod unless found
  end

  if Process.uid == 0
    # FIXME: need to fail otherwise, the results will be skewed
    `sudo apt-get --purge #{package}`
    `sudo apt-get --purge autoremove`
  end
end

require 'logger'
require 'logger/colors'
log = Logger.new(STDOUT)
log.progname = 'QML Dep'
log.level = Logger::INFO
missing_modules.uniq!
missing_modules.each do |mod|
  log.warn "#{mod} not found."
  log.info '  looked for:'
  mod.import_paths.each do |path|
    log.info "    - #{path}"
  end
end
