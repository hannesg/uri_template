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
#    (c) 2011 by Hannes Georg
#

require 'uri_template'

describe URITemplate do

  class BadURITemplate
  
    include URITemplate
    
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
  
  describe "docs" do
  
    gem 'yard'
    require 'yard'
    
    YARD.parse('lib/**/*.rb').inspect
    
    YARD::Registry.each do |object|
      if object.has_tag?('example')
        object.tags('example').each_with_index do |tag, i|
          code = tag.text.gsub(/(.*)\s*#=>(.*)(\n|$)/){
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
  
    it "should allow path-style concatenation between colon and draft7" do
    
      (URITemplate.new(:draft7, '/prefix') / URITemplate.new(:colon, '/suffix')).pattern.should == '/prefix/suffix'
      
      (URITemplate.new(:colon, '/prefix') / URITemplate.new(:draft7, '/suffix')).pattern.should == '/prefix/suffix'
      
      (URITemplate.new(:draft7, '/{prefix}') / URITemplate.new(:colon, '/suffix')).pattern.should == '/{prefix}/suffix'
      
      (URITemplate.new(:draft7, '/prefix') / URITemplate.new(:colon, '/:suffix')).pattern.should == '/prefix/{suffix}'
      
      (URITemplate.new(:colon, '/:prefix') / URITemplate.new(:draft7, '/suffix')).pattern.should == '/:prefix/suffix'
      
      (URITemplate.new(:colon, '/:prefix') / URITemplate.new(:draft7, '/{suffix}')).pattern.should == '/:prefix/{:suffix}'
      
      (URITemplate.new(:colon, '/:prefix') / URITemplate.new(:draft7, '{/suffix}')).pattern.should == '/{prefix}{/suffix}'
   
    end
  
  end
  
  describe "utils" do
  
    it "should raise on basic object" do
    
      lambda{ URITemplate::Utils.object_to_param(BasicObject.new) }.should raise_error(URITemplate::Unconvertable)
    
    end
    
    it "should raise when an object is not convertable to string" do
    
      obj = Object.new
      
      class << obj
      
        undef to_s
      
      end
    
      lambda{ URITemplate::Utils.object_to_param(obj) }.should raise_error(URITemplate::Unconvertable)
    
    end
  
  end

end
