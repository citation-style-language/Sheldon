require File.expand_path('../../spec_helper', __FILE__)

class Sheldon
  describe Template do

    it 'works without variables' do
      Template.new('').render.must_equal ''
      Template.new('foo').render.must_equal 'foo'
      Template.new('<%= 2 + 2 %>').render.must_equal '4'
    end

    it 'works with variables' do
      Template.new('').render(x: 42).must_equal ''
      Template.new('<%= x %>').render(x: 42).must_equal '42'
    end

  end
end
