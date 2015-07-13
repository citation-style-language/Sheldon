require 'digest/sha2'

module Sheldon
  module TravisCiHelper

    def valid_notification?
      digest.to_s == authorization
    end

    def digest
      Digest::SHA2.new.update "#{repo_slug}#{settings.travis_token}"
    end

    def authorization
      request.env['HTTP_AUTHORIZATION']
    end

    def repo_slug
      request.env['HTTP_TRAVIS_REPO_SLUG']
    end

    def travis_payload
      @travis_payload ||= JSON.parse request.params[:payload]
    end
  end
end
