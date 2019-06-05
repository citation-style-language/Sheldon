require 'base64'
require 'faraday'
require 'openssl'
require 'open-uri'
require 'json'
require 'logger'

module Sheldon
  module TravisCiHelper

    def valid_notification?
      key = OpenSSL::PKey::RSA.new(public_key)
      key.verify(
        OpenSSL::Digest::SHA1.new,
        Base64.decode64(signature),
        params[:payload]
      )
    end

    def signature
      request.env['HTTP_SIGNATURE']
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

    def build_details
      if @details.nil?
        prefix = 'sheldon:'.split('').collect{|c| "#{c}\b"}.join('')
        url = "https://api.travis-ci.org/v3/job/#{travis_payload['matrix'][0]['id']}/log.txt"
        logger.info "Travis Build: get log from #{url} (#{prefix.inspect})"

        # make sure we don't attempt again if we've not been successful before
        @details = ''

        begin
          # the gem part of sheldon hides the detals in the travis log by backspacing over it. It is marked in the log by the hidden prefix 'sheldon:'
          # the actual payload is JSONified so that newlines all live on a single line

          log = open(url).read.split("\n")
          log.each{|line|
            logger.info "Travis Build: log #{line.inspect}"
          }
          logger.info "Travis Build: log with #{log.length} lines"

          details = log.detect{|line| line.start_with?(prefix) }
          logger.info "Travis Build: hidden details #{details ? '' : 'not '}detected"

          # if found: un-hide, remove the prefix and un-base64
          @details = details ? Base64.decode64(details.gsub("\b", '').split(':', 2)[1].strip) : ''
        rescue OpenURI::HTTPError => e
          logger.info "Failed to load log from #{url}: #{e}"
          @details = ''
        end
      end

      return @details
    end

    def public_key
      conn = Faraday.new(url: settings.travis_api_host) do |f|
        f.adapter Faraday.default_adapter
      end

      response = conn.get '/config'
      JSON.parse(response.body)['config']['notifications']['webhook']['public_key']
    rescue
      ''
    end

    def build_passed
      'passed'
    end

    def build_failed
      'failed'
    end
  end
end
