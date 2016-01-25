module CI
  # SCM Base Class
  class SCM
    # @return [String] a type identifier (e.g. 'git', 'svn')
    attr_reader :type
    # @return [String] branch of the SCM to use (if applicable)
    attr_reader :branch
    # @return [String] valid git URL to the SCM
    attr_reader :url

    # Constructs an upstream SCM description from a packaging SCM description.
    #
    # Upstream SCM settings default to sane KDE settings and can be overridden
    # via data/upstraem-scm-map.yml. The override file supports pattern matching
    # according to File.fnmatch and ERB templating using a {BindingContext}.
    #
    # @param type [String] type of the SCM (git or svn)
    # @param url [String] URL of the SCM repo
    # @param branch [String] Branch of the SCM (if applicable)
    #   containing debian/ (this is only used for repo-specific overrides)
    def initialize(type, url, branch = nil)
      # FIXME: type should be a symbol really
      # FIXME: maybe even replace type with an is_a check?
      @type = type
      @url = url
      @branch = branch
    end
  end
end
