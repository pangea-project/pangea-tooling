require_relative 'generic'

module MutableURI
  # Mutable for git.debian.org
  class Debian < Generic
    def self.match(uri)
      %w[anonscm.debian.org git.debian.org].include?(uri.host)
    end

    private

    def read_uri_template
      GitCloneUrl.parse('git://anonscm.debian.org/')
    end

    def write_uri_template
      GitCloneUrl.parse('git.debian.org:/git/')
    end

    def clean_path(path)
      path.sub!(%r{^/git}, '')
      path.sub!(%r{^/}, '')
      path
    end
  end
end
