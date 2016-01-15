require_relative '../dpkg'

# Management construct for QML related bits.
module QML
  SEARCH_PATHS = ["/usr/lib/#{DPKG::HOST_MULTIARCH}/qt5/qml"]

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

    private

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
