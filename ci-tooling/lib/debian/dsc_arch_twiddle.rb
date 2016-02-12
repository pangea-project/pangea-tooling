require_relative '../kci'

module Debian
  # Mangle dsc to not do ARM builds unless explicitly enabled.
  # With hundreds of distinct sources on CI, building all of them on three
  # architectures, of which one is not too commonly used, is extremly excessive.
  # Instead, by default we only build on the common architectures with extra
  # architectures needing to be enabled explicitly.
  # To achieve this mangle the Architecture field in the control file.
  # If it contains an uncommon arch -> remove it -> if it is empty now, abort
  # If it contains any -> replace with !uncommon
  # This is a cheapster hack implementation to avoid having to implement write
  # support in Debian::Control|DSC.
  class DSCArch
    class Error < Exception; end
    class EmptyError < Error; end
    class CountError < Error; end
    class MultilineError < Error; end

    def self.enabled_architectures
      enabled_architectures = KCI.architectures.dup
      extras = KCI.extra_architectures
      env_extras = ENV.fetch('ENABLED_EXTRA_ARCHITECTURES') { nil }
      extras.each do |extra|
        next unless env_extras && !env_extras.empty?
        next unless env_extras.split(' ').include?(extra)
        enabled_architectures << extra
      end
      enabled_architectures
    end

    # Twiddles the Architecture field of a DSC file to only list enabled arches.
    def self.twiddle!(directory_with_dsc)
      dsc = nil
      Dir.chdir(directory_with_dsc) do
        dsc = Dir.glob('*.dsc')
        unless dsc.size == 1
          raise CountError, "Not exactly one dsc WTF -> #{dsc}"
        end
        dsc = File.expand_path(dsc[0])
      end

      enabled_arches = enabled_architectures

      saw_architecture = false
      line_after = false
      lines = File.read(dsc).lines
      lines.collect! do |line|
        if line_after && line.start_with?(' ')
          raise MultilineError, 'Line after Architecture starts with space.'
        end
        line_after = false

        match = line.match(/^Architecture: (.*)$/)
        next line unless match
        arches = match[1].split(' ')
        arches.collect! do |arch|
          next enabled_arches if arch == 'any' || arch == 'linux-any'
          next arch if arch == 'all'
          next nil unless enabled_arches.include?(arch)
          arch
        end
        arches.flatten!
        arches.compact!
        arches.uniq!
        raise EmptyError, "Ripped all arches out of '#{line}'" if arches.empty?
        saw_architecture = true
        line_after = true
        "Architecture: #{arches.join(' ')}\n"
      end
      File.write(dsc, lines.join)
      return if saw_architecture
      raise EmptyError, 'There apparently was no Architecture field!'
    end
  end
end
