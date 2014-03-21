# -*- encoding : utf-8 -*-
require 'uri_template_shared'

describe URITemplate::Colon do

  it_should_behave_like "a uri template class"

  it_should_behave_like "a uri template class with extraction"

  describe "general" do
    it "says it's of type :colon" do
      URITemplate.new(:colon, '/foo').type.should == :colon
    end
  end

  describe "syntax" do

    it "should support variable names with underscores" do
      tpl = URITemplate.new(:colon, '/foo/:foo_bar/')
      tpl.variables.should == ['foo_bar']
    end

  end

  describe "extraction" do

    it "should extract as expected" do

      tpl = URITemplate.new(:colon, '/foo/{:bar}a/')

      tpl.should extract('bar' => 'baz').from('/foo/baza/')

    end

    it "should allow unicode" do

      tpl = URITemplate.new(:colon, '/föö' )

      tpl.should extract.from('/f%C3%B6%C3%B6')

    end

    it "should handle encoded stuff correctly" do

      tpl = URITemplate.new(:colon, '/:a' )
      tpl.should extract('a'=>'foo/bar').from('/foo%2Fbar')

    end

    it "should handle optional params" do

      tpl = URITemplate.new(:colon, '/?:foo?/?:bar?')

    end

    it "should return nil if not matchable" do

      tpl = URITemplate.new(:colon, '/foo/{:bar}a/')

      tpl.should_not extract.from('/foo/foo/')

    end

    it "should support splats" do

      tpl = URITemplate.new(:colon, '/foo/*')

      tpl.should extract('splat' => ['bar%20z']).from('/foo/bar%20z')
      tpl.should extract('splat' => ['bar/z']).from('/foo/bar/z')

    end

    it "should support multiple splats" do

      tpl = URITemplate.new(:colon, '/*/*.*')

      tpl.should extract('splat' => ['dir','b/c','ext']).from('/dir/b/c.ext')

    end

    it "should match dots in named parameters" do

      tpl = URITemplate.new(:colon, '/:foo/:bar')

      tpl.should extract('foo'=>'user@example.com','bar'=>'name').from('/user@example.com/name')

    end

    it "should match dots, parens and pluses in paths" do

      tpl = URITemplate.new(:colon, '/+/(foo)/:file.:ext')
      tpl.should extract('file'=>'pony','ext'=>'jpg').from('/+/(foo)/pony.jpg')

    end

    it "should encode literal spaces" do

      tpl = URITemplate.new(:colon, ' ')
      tpl.should extract.from('%20')

    end

  end

  describe "expansion" do

    it "should work with simple expressions" do

      tpl = URITemplate.new(:colon, '/foo/:bar/')

      tpl.should expand('bar'=>'baz').to '/foo/baz/'

    end

    it "should work with bracketed expressions" do

      tpl = URITemplate.new(:colon, '/foo/{:bar}a/')

      tpl.should expand('bar'=>'baz').to '/foo/baza/'

    end

    it "should support splats" do

      tpl = URITemplate.new(:colon, '/foo/*')

      tpl.should expand('splat' => ['bar z']).to('/foo/bar%20z')

    end

    it "should support multiple splats" do

      tpl = URITemplate.new(:colon, '/*/*.*')

      tpl.should expand('splat' => ['dir','b/c','ext'] ).to('/dir/b/c.ext')
    end

    it 'should support splats using array expansion' do

      tpl = URITemplate.new(:colon, '/*/*.*')
      tpl.should expand([['dir','b/c','ext']] ).to('/dir/b/c.ext')

    end

    it "should raise if splat is not an array" do

      tpl = URITemplate.new(:colon,'/*')
      expect{ tpl.expand('splat'=>'string') }.to raise_error(URITemplate::InvalidValue)

    end

    it "should encode literal spaces" do

      tpl = URITemplate.new(:colon, ' ')
      tpl.should expand.to('%20')

    end

  end

end
