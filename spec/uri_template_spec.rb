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

    class BadExpression

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

  end

  describe 'resolving' do

    it 'should create templates' do

      URITemplate.new('{x}').should == URITemplate::Draft7.new('{x}')

    end

    it 'should be able to select a template version' do

      URITemplate.new(:draft7,'{x}').should == URITemplate::Draft7.new('{x}')
      URITemplate.new('{x}',:draft7).should == URITemplate::Draft7.new('{x}')

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
      URITemplate.convert(URITemplate::Draft7.new('foo')).should be_kind_of(URITemplate)

    end

    it 'should make templates recreateable by type' do

      URITemplate::VERSIONS.each do |type|
        tpl = URITemplate.new(type, '/foo')
        URITemplate.new(tpl.type, tpl.pattern).should == tpl
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
            lambda{ eval code }.should_not raise_error
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

  end

end
