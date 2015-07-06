require File.expand_path('../../spec_helper', __FILE__)

module Sheldon
  describe Github do

    it 'accepts only github hookshots' do
      post '/pull_request'
      last_response.status.must_equal 404

      hookshot '/pull_request'
      last_response.status.must_equal 204
    end

    it 'ignores pings' do
      hookshot '/pull_request', :ping
      last_response.status.must_equal 202
    end

  end
end
