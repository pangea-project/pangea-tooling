require_relative 'generic'

module MutableURI
  # Mutable for github.com
  class GitHub < Generic
    def self.match(uri)
      uri.host == 'github.com'
    end

    private

    def read_uri_template
      GitCloneUrl.parse('https://github.com/')
    end

    def to_writable(uri)
      path = uri.path.dup
      path.sub!(%r{^/}, '')
      GitCloneUrl.parse("git@github.com:#{path}")
    end
  end
end
