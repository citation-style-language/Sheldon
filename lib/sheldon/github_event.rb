require 'json'

module Sheldon
  class GithubEvent

    class << self
      def parse(request)
        raise 'POST request expected' unless request.post?

        raise 'Github Event header expected' unless
          request.env.key? 'X_GITHUB_EVENT'

        new request.env['X_GITHUB_EVENT'], request.POST
      end
    end

    attr_reader :type, :data

    def initialize(type, data)
      @type, @data = type.to_sym, data
    end

    def ping?
      type == :ping
    end

  end
end
