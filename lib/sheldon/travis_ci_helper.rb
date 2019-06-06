require 'base64'
require 'faraday'
require 'openssl'
require 'open-uri'
require 'json'
require 'logger'
require 'net/http/post/multipart'
require 'stringio'
require 'sheldon/hidden_text'

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

    def travis_ip?
      ips = JSON.parse(open('https://dnsjson.com/nat.gce-us-central1.travisci.net/A.json').read)['results']['records']
      client = request.env['HTTP_X_FORWARDED_FOR']
      travis = ips.include?(client)
      logger.info "is #{client} in #{ips}? #{travis}"
      return travis
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
