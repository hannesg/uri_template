# -*- encoding : utf-8 -*-
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the Affero GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    (c) 2011 - 2012 by Hannes Georg
#

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
      result[2].should be_true
      result[3].should be_true

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

  describe "utils" do

    it "should raise on basic object", :if => (defined? BasicObject) do

      lambda{ URITemplate::Utils.object_to_param(BasicObject.new) }.should raise_error(URITemplate::Unconvertable)

    end

    it "should raise when an object is not convertable to string" do

      obj = Object.new

      class << obj

        undef to_s

      end

      lambda{ URITemplate::Utils.object_to_param(obj) }.should raise_error(URITemplate::Unconvertable)

    end

    describe "escape utils", :if => URITemplate::Utils.using_escape_utils? do

      if URITemplate::Utils.using_escape_utils?

        encode = "".respond_to? :encode
        pure = Object.new
        pure.extend(URITemplate::Utils::Escaping::Pure)
        escape_utils = Object.new
        escape_utils.extend(URITemplate::Utils::Escaping::EscapeUtils)

        [
          "",
          "a",
          " ",
          "%%%",
          encode ? "a".encode('ISO-8859-1') : "a",
          encode ? "öüä".encode('ISO-8859-1') : "öüä",
          "+",
          "öäü"
        ].each do |str|
          it "should correctly escape #{str.inspect} ( encoding: #{encode ? str.encoding : '--'} )" do
            escape_utils.escape_uri(str).should == pure.escape_uri(str)
            escape_utils.escape_url(str).should == pure.escape_url(str)
          end
        end

        [
          "",
          "a",
          " ",
          encode ? "a".encode('ISO-8859-1') : "a",
          "+",
          "%20%30%40",
          "%C3%BC",
          # errors:
          "%",
          "%%%",
          "%gh",
          "%a"
        ].each do |str|
          it "should correctly unescape #{str.inspect} ( encoding: #{encode ? str.encoding : '--'} )" do
            escape_utils.unescape_uri(str).should == pure.unescape_uri(str)
            escape_utils.unescape_url(str).should == pure.unescape_url(str)
          end
        end

      end

    end

    describe "string encoding" do

      if "".respond_to? :encoding

      describe "real" do

        subject{ o = Object.new; o.extend(URITemplate::Utils::StringEncoding::Encode); o }

        it "converts to ascii" do
          result = subject.to_ascii("foo".encode(Encoding::UTF_8))
          result.encoding.should == Encoding::ASCII
          result.should == "foo".encode(Encoding::ASCII)
        end

        it "converts to utf8" do
          result = subject.to_utf8("foo".encode(Encoding::ASCII))
          result.encoding.should == Encoding::UTF_8
          result.should == "foo".encode(Encoding::UTF_8)
        end

      end

      end

      describe "fallback" do

        subject{ o = Object.new; o.extend(URITemplate::Utils::StringEncoding::Fallback); o }

        it "passes thru to_ascii" do
          subject.to_ascii("foo").should == "foo"
        end

        it "converts to utf8" do
          subject.to_utf8("foo").should == "foo"
        end

      end

    end

    describe URITemplate::RegexpEnumerator do

      subject{URITemplate::RegexpEnumerator}

      it "yields if called with block" do
        enum = subject.new(/b/)
        expect{|b| enum.each("aba",&b) }.to yield_successive_args("a", MatchData, "a")
      end

      it "returns an iterator if called without block" do
        enum = subject.new(/b/).each("aba")
        enum.should be_a(Enumerable)
        expect{|b| enum.each(&b) }.to yield_successive_args("a", MatchData, "a")
      end

      it "should yield the rest if match is empty" do
        enum = subject.new(//)
        expect{|b| enum.each("foo",&b) }.to yield_successive_args(MatchData, "foo")
      end

      it "should raise if match is empty and told to do so" do
        enum = subject.new(//, :rest => :raise)
        expect{
          enum.each("foo"){}
        }.to raise_error(/matched an empty string/)
      end

    end

  end

end
