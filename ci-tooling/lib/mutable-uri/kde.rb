require_relative 'generic'

module MutableURI
  # Mutable for git.kde.org
  class KDE < Generic
    def self.match(uri)
      %w(git.kde.org anongit.kde.org).include?(uri.host)
    end

    private

    def read_uri_template
      GitCloneUrl.parse('git://anongit.kde.org/')
    end

    def write_uri_template
      GitCloneUrl.parse('git@git.kde.org:')
    end

    def clean_path(path)
      path.sub(%r{^/}, '')
    end
  end
end
