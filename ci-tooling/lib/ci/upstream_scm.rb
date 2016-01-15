require 'erb'
require 'json'
require 'yaml'

require_relative 'pattern'
require_relative 'scm'

module CI
  # Construct an upstream scm instance and fold in overrides set via
  # meta/upstream_scm.json.
  class UpstreamSCM < SCM
    # Binding context for SCM overrides.
    # SCM overrides can use ERB syntax to access properties of the context.
    # Overrides can not access the UpstreamSCM directly!
    class BindingContext
      # @return [String] name of the packaging SCM (i.e. basename of path)
      attr_reader :name
      # @return [String] full repo URL of the packaging SCM
      attr_reader :packaging_repo
      # @return [String] full branch of the packaging SCM
      attr_reader :packaging_branch

      def initialize(scm)
        @name = scm.instance_variable_get(:@name)
        @packaging_repo = scm.instance_variable_get(:@packaging_repo)
        @packaging_branch = scm.instance_variable_get(:@packaging_branch)
      end

      def render(template_str)
        ERB.new(template_str).result(binding)
      end
    end

    # Constructs an upstream SCM description from a packaging SCM description.
    #
    # Upstream SCM settings default to sane KDE settings and can be overridden
    # via data/upstraem-scm-map.yml. The override file supports pattern matching
    # according to File.fnmatch and ERB templating using a {BindingContext}.
    #
    # @param packaging_repo [String] git URL of the packaging repo
    # @param packaging_branch [String] branch of the packaging repo
    # @param working_directory [String] local directory path of directory
    #   containing debian/ (this is only used for repo-specific overrides)
    def initialize(packaging_repo, packaging_branch, working_directory = Dir.pwd)
      @packaging_repo = packaging_repo
      @packaging_branch = packaging_branch
      @name = File.basename(packaging_repo)
      @directory = working_directory

      super('git', "git://anongit.kde.org/#{@name.chomp('-qt4')}", 'master')

      global_override!
      repo_override!
    end

    private

    def override_apply(override)
      context = BindingContext.new(self)

      [:type, :url, :branch].each do |var|
        override_value = override.fetch(var.to_s, nil)
        next unless override_value
        # Version would be float. Coerce into string.
        override_value = override_value.to_s
        override_value = context.render(override_value)
        next unless override_value
        instance_variable_set("@#{var}", override_value)
      end
    end

    def global_override_load
      base = File.expand_path(File.dirname(File.dirname(File.dirname(__FILE__))))
      file = File.join(base, 'data', 'upstream-scm.yml')
      hash = YAML.load(File.read(file))
      hash = CI::Pattern.convert_hash(hash, recurse: false)
      hash.each do |k, v|
        hash[k] = CI::Pattern.convert_hash(v, recurse: false)
      end
      hash
    end

    def global_override!
      overrides = global_override_load
      repo_patterns = CI::Pattern.filter(@packaging_repo, overrides)
      repo_patterns = CI::Pattern.sort_hash(repo_patterns)
      return if repo_patterns.empty?

      branches = overrides[repo_patterns.flatten.first]
      branch_patterns = CI::Pattern.filter(@packaging_branch, branches)
      branch_patterns = CI::Pattern.sort_hash(branch_patterns)
      return if branch_patterns.empty?

      override_apply(branches[branch_patterns.flatten.first])
    end

    def repo_override!
      overrides = {}
      file_path = File.join(@directory, 'debian/meta/upstream_scm.json')
      overrides = JSON.parse(File.read(file_path)) if File.exist?(file_path)
      override_apply(overrides) unless overrides.empty?
    end
  end
end

require_relative '../deprecate'
class UpstreamSCM < CI::UpstreamSCM
  extend Deprecate
  deprecate :initialize, CI::UpstreamSCM, 2015, 12
end
