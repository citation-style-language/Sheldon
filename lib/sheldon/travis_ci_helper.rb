require 'digest/sha2'

module Sheldon
  module TravisCiHelper

    def valid_notification?
      true
      #digest.to_s == authorization
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
      @travis_payload ||= JSON.parse params[:payload]
    end

    def build_pull_request?
      travis_payload['type'] == 'pull_request'
    end

    def build_pull_request_number
      travis_payload['pull_request_number']
    end

    def build_passed?
      travis_payload['status'] == 0
    end

    def build_status
      if build_passed?
        build_passed
      else
        build_failed
      end
    end

    def build_passed
      'passed'
    end

    def build_failed
      'failed'
    end
  end
end
