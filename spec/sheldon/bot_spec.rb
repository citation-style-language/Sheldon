require File.expand_path('../../spec_helper', __FILE__)

module Sheldon
  describe Bot do
    it 'is ok' do
      get '/status'
      last_response.body.must_equal 'OK'
    end

    it 'is versioned' do
      get '/version'
      last_response.body.must_equal Sheldon::VERSION
    end
  end
end
