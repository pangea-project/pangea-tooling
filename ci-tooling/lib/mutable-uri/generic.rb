require 'git_clone_url'

module MutableURI
  # Generic base class
  class Generic
    class NoURIError < StandardError; end

    def initialize(uri)
      fail unless uri.is_a?(URI::Generic)
      @writable = to_writable(uri)
      @readable = to_readable(uri)
    end

    # @return [URI::Generic] read-only URI
    # @raise [NoURIError] if no readable URI is available
    def readable
      return @readable if @readable
      fail NoURIError, "No readable URI available for #{self}"
    end

    # @return [URI::Generic] writeable URI
    # @raise [NoURIError] if no writable URI is available
    def writable
      return @writable if @writable
      fail NoURIError, "No writable URI available for #{self}"
    end

    private

    # @return [URI::Generic] a template URI to append path to
    def read_uri_template
      fail 'No read URI template defined'
    end

    # @return [URI::Generic] a template URI to append path to
    def write_uri_template
      fail 'No write URI template defined'
    end

    # @return [String] cleanup path to make it suitable for the templates
    def clean_path(path)
      path
    end

    # @return [URI::Generic] the readable version of uri
    def to_readable(uri)
      append_to_template(uri, read_uri_template.dup)
    end

    # @return [URI::Generic] the writable version of uri
    def to_writable(uri)
      append_to_template(uri, write_uri_template.dup)
    end

    # @param uri [URI::Generic] the input URI to use the path of
    # @param template [URI::Generic] the template to which path will be appended
    # @return [URI::Generic] appends path of uri to template
    # @see {clean_path}
    def append_to_template(uri, template)
      template.path += clean_path(uri.path.dup)
      template.path.gsub!('//', '/')
      template
    end
  end
end
