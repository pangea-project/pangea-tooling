# frozen_string_literal: true
require_relative '../dpkg'

# Management construct for QML related bits.
module QML
  SEARCH_PATHS = ["/usr/lib/#{DPKG::HOST_MULTIARCH}/qt5/qml"].freeze

  # Describes a QML module.
  class Module
    IMPORT_SEPERATOR = '.'

    attr_reader :identifier
    attr_reader :version
    attr_reader :qualifier

    def initialize(identifier = nil, version = nil, qualifier = nil)
      @identifier = identifier
      @version = version
      @qualifier = qualifier
    end

    # @return [Array<QML::Module>]
    def self.read_file(path)
      modules = []
      File.read(path).lines.each do |line|
        mods = QML::Module.parse(line)
        modules += mods unless mods.empty?
      end
      modules.compact.uniq
    end

    # @return [Array<QML::Module>]
    def self.parse(line)
      modules = []
      line.split(';').each do |statement|
        modules << new.send(:parse, statement)
      end
      modules.compact.uniq
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

    def ==(other)
      identifier == other.identifier \
        && (version.nil? || other.version.nil? || version == other.version) \
        && (qualifier.nil? || other.qualifier.nil? || qualifier == other.qualifier)
    end

    def installed?
      static_package = QML::StaticMap.new.package(self)
      return package_installed?(static_package) if static_package
      modules_installed?
    end

    private

    def modules_installed?
      found = false
      # FIXME: beyond path this currently doesn't take version into account
      QML::SEARCH_PATHS.each do |search_path|
        import_paths.each do |import_path|
          path = File.join(search_path, import_path, 'qmldir')
          found = File.exist?(path) && File.file?(path)
          break if found
        end
        break if found
      end
      found
    end

    def package_installed?(package_name)
      return true if package_name == 'fake-global-ignore'
      # FIXME: move to dpkg module
      # FIXME: instead of calling -s this probably should manually check
      #   /var/lib/dpkg/info as -s is rather slow
      system("dpkg -s #{package_name} 2>&1 > /dev/null")
    end

    def parse(line)
      minsize = 3 # import + name + version
      return nil unless line && !line.empty?
      parts = line.split(/\s/)
      return nil unless parts.size >= minsize
      parts.delete_if { |str| str.nil? || str.empty? }
      return nil unless parts.size >= minsize && parts[0] == 'import'
      return nil if parts[1].start_with?('"') # Directory import.
      @identifier = parts[1]
      @version = parts[2]
      # FIXME: what if part 3 is not as?
      @qualifier = parts[4] if parts.size == 5
      self
    end
  end
end
