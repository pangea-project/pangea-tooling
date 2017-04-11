module Apt
  class File
    def initialize(sources_list: nil, cache_dir: nil)
      @sources_list = sources_list
      @cache_dir = cache_dir
    end

    def update
      @update ||= run('update')
    end

    def search(pattern)
      run('search', pattern)
    end

    private

    BINARY = 'apt-file'.freeze

    def run(*args)
      data = `#{([BINARY] + default_args + args).join(' ')} 2>&1`
      raise data unless $?.success?
      data
    end

    def default_args
      @args ||= begin
        a = []
        a << '--sources-list' << @sources_list if @sources_list
        a << '--cache' << @cache_dir if @cache_dir
      end
    end
  end
end
