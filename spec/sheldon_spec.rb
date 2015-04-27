require File.expand_path('../spec_helper', __FILE__)

describe Sheldon do

  it 'is ok' do
    get '/status'
    last_response.body.must_equal 'OK'
  end

end
