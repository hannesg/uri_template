# -*- encoding : utf-8 -*-
require 'uri_template'

describe URITemplate do

  class BadURITemplate

    include URITemplate

    class BadToken
      include URITemplate::Token
    end

    class BadExpression < BadToken
      include URITemplate::Expression
    end

    attr_reader :pattern

    def self.try_convert(x)
      if x.kind_of? String
        return new(x)
      elsif x.kind_of? self
        return x
      else
        return nil
      end
    end

    def initialize(pattern)
      @pattern = pattern
    end

  end

  describe 'done wrong' do

    it 'should moarn about unimplemented .type' do
      expect{
        BadURITemplate.new("").type
      }.to raise_error(/\APlease implement/)
    end

    it 'should moarn about unimplemented .tokens' do
      expect{
        BadURITemplate.new("").tokens
      }.to raise_error(/\APlease implement/)
    end

    it 'should moarn about unimplemented Expression.to_s' do
      expect{
        BadURITemplate::BadExpression.new.to_s
      }.to raise_error(/\APlease implement/)
    end

    it 'should moarn about unimplemented Expression.expand(variables)' do
      expect{
        BadURITemplate::BadExpression.new.expand(nil)
      }.to raise_error(/\APlease implement/)
    end

    describe "at least" do

      it "has token size 0" do
        BadURITemplate::BadToken.new.size.should == 0
      end

      it "has empty variable array" do
        BadURITemplate::BadToken.new.variables.should == []
      end

      it "doesn't start with slash" do
        BadURITemplate::BadToken.new.should_not be_starts_with_slash
      end

    end

  end

  describe 'resolving' do

    it 'should create templates' do

      URITemplate.new('{x}').should be_kind_of URITemplate

    end

    it 'should raise when given an invalid version' do

      lambda{ URITemplate.new(:foo,'{x}') }.should raise_error(ArgumentError)

    end

    it 'should coerce two strings' do

      result = URITemplate.coerce('foo','bar')
      result[0].should be_kind_of(URITemplate)
      result[1].should be_kind_of(URITemplate)
      result[2].should be true
      result[3].should be true

    end

    it 'should raise when arguments could not be coerced' do

      lambda{

        URITemplate.coerce(Object.new,Object.new)

      }.should raise_error(ArgumentError)

    end

    it 'should raise when arguments could not be coerced' do

      lambda{

        URITemplate.coerce(BadURITemplate.new('x'),URITemplate.new('y'))

      }.should raise_error(ArgumentError)

    end

    it 'should raise argument errors when convert fails' do

      lambda{
        URITemplate.convert(Object.new)
      }.should raise_error(ArgumentError)

    end

    it 'should not raise argument errors when convert succeds' do

      URITemplate.convert('tpl').should be_kind_of(URITemplate)
      URITemplate.convert(URITemplate.new('foo')).should be_kind_of(URITemplate)

    end

    it 'should make templates recreateable by type' do

      URITemplate::VERSIONS.each do |type|
        tpl = URITemplate.new(type, '/foo')
        URITemplate.new(tpl.type, tpl.pattern).should == tpl
        URITemplate.new(tpl.pattern, tpl.type).should == tpl
      end

    end

  end

  describe "expand" do
    it 'should expand variables from a hash where the keys are symbols' do
      t = URITemplate.new("/foo{?bar}")
      v = { :bar => 'qux' }

      t.expand(v).should == '/foo?bar=qux'
    end

    it 'should expand variables from a hash with mixed key types' do
      t = URITemplate.new("{/list*}/{?bar}")
      v = { :bar => 'qux', "list" => ['a', :b] }

      t.expand(v).should == '/a/b/?bar=qux'
    end

    it 'should expand variables from an array' do
      t = URITemplate.new("/{foo}{/list*}/{?bar}")
      t.should expand(['bar', ['a', :b], 'qux']).to '/bar/a/b/?bar=qux'
    end
  end

  describe "docs" do

    gem 'yard'
    require 'yard'

    YARD.parse('lib/**/*.rb').inspect

    YARD::Registry.each do |object|
      if object.has_tag?('example')
        object.tags('example').each_with_index do |tag, i|
          code = tag.text.gsub(/^[^\n]*#UNDEFINED!/,'').gsub(/(.*)\s*#=>(.*)(\n|$)/){
            "(#{$1}).should == #{$2}\n"
          }
          it "#{object.to_s} in #{object.file}:#{object.line} should have valid example #{(i+1).to_s}" do
            eval code
          end
        end
      end
    end

  end

  describe "cross-type usability" do

    describe "path concatenation" do

      it 'should be possible between RFC6570("/prefix") and COLON("/suffix")' do
        (URITemplate.new(:rfc6570, '/prefix') / URITemplate.new(:colon, '/suffix')).pattern.should == '/prefix/suffix'
      end

      it 'should be possible between COLON("/prefix") and RFC6570("/suffix")' do
        (URITemplate.new(:colon, '/prefix') / URITemplate.new(:rfc6570, '/suffix')).pattern.should == '/prefix/suffix'
      end

      it 'should be possible between RFC6570("/{prefix}") and COLON("/suffix")' do
        (URITemplate.new(:rfc6570, '/{prefix}') / URITemplate.new(:colon, '/suffix')).pattern.should == '/{prefix}/suffix'
      end

      it 'should be possible between RFC6570("/prefix") and COLON("/:suffix")' do
        (URITemplate.new(:rfc6570, '/prefix') / URITemplate.new(:colon, '/:suffix')).pattern.should == '/prefix/{suffix}'
      end

      it 'should be possible between COLON("/:prefix") and RFC6570("/suffix")' do
        (URITemplate.new(:colon, '/:prefix') / URITemplate.new(:rfc6570, '/suffix')).pattern.should == '/:prefix/suffix'
      end

      it 'should be possible between COLON("/:prefix") and RFC6570("/{suffix}")' do
        (URITemplate.new(:colon, '/:prefix') / URITemplate.new(:rfc6570, '/{suffix}')).pattern.should == '/:prefix/:suffix'
      end

      it 'should be possible between COLON("/:prefix") and RFC6570("{/suffix}")' do
        (URITemplate.new(:colon, '/:prefix') / URITemplate.new(:rfc6570, '{/suffix}')).pattern.should == '/{prefix}{/suffix}'
      end

    end

  end

  describe "path concatenation" do

    it 'should be possible when the last template is empty' do
      (URITemplate.new(:rfc6570, '/prefix') / URITemplate.new(:rfc6570, '')).pattern.should == '/prefix'
    end

    it 'should be possible when the first template is empty' do
      (URITemplate.new(:rfc6570, '') / URITemplate.new(:rfc6570, '/suffix')).pattern.should == '/suffix'
    end

    it 'should raise when the last template contains a host' do
      expect{
        URITemplate.new(:rfc6570, '/prefix') / URITemplate.new(:rfc6570, '//host')
      }.to raise_error(ArgumentError)
    end

    it 'should be possible when a slash has to be removed from the first template' do
      (URITemplate.new(:rfc6570, '/') / URITemplate.new(:rfc6570, '{/a}')).pattern.should == '{/a}'
    end

    it 'should be possible when a slash has to be removed from the last template' do
      tpl = URITemplate.new(:rfc6570, '{a}')
      last_token = tpl.tokens.last
      def last_token.ends_with_slash?
        true
      end
      (tpl / URITemplate.new(:rfc6570, '/')).pattern.should == '{a}'
    end

    it 'should be possible when a slash has to be inserted' do
      (URITemplate.new(:rfc6570, 'a') / URITemplate.new(:rfc6570, 'b')).pattern.should == 'a/b'
    end

    it 'should raise when the last template contains a scheme' do
      expect{
        URITemplate.new(:rfc6570, '/prefix') / URITemplate.new(:rfc6570, 'scheme:')
      }.to raise_error(ArgumentError)
    end

    it 'should not barf when an absolute uri is the first template' do
      merged = (URITemplate.new(:rfc6570, 'http://foo.bar/') / URITemplate.new(:rfc6570, '/{+file}'))
      merged.tokens.each do |tk|
        expect(tk).to be_a(URITemplate::Token)
      end
    end

  end

end
