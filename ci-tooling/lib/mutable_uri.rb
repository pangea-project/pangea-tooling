require 'uri'

require_relative 'mutable-uri/debian'
require_relative 'mutable-uri/github'
require_relative 'mutable-uri/kde'

# A URI wrapper to provide read URIs and write URIs for repositories.
module MutableURI
  InvalidURIError = URI::InvalidURIError

  def self.parse(url)
    uri = GitCloneUrl.parse(url)
    constants.each do |name|
      next if name == :Generic ||
              name.to_s.end_with?('Test') ||
              name.to_s.end_with?('Error')
      klass = const_get(name)
      next unless klass.is_a?(Class) && klass.match(uri)
      return klass.send(:new, uri)
    end
    raise InvalidURIError, "Could not match to URI class #{url}"
  end
end
