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
  
  end
  
  describe 'section resolving' do
    
    
    it 'should create template sections' do
    
      URITemplate::Section.new('{x}').should == URITemplate::Draft7::Section.new('{x}')
      
    end
    
    it 'should be able to select a template version' do
    
      URITemplate::Section.new(:draft7,'{x}').should == URITemplate::Draft7::Section.new('{x}')
      URITemplate::Section.new('{x}',:draft7).should == URITemplate::Draft7::Section.new('{x}')
    
    end
    
    it 'should raise when given an invalid version' do
    
      lambda{ URITemplate::Section.new(:foo,'{x}') }.should raise_error(ArgumentError)
    
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
          it "#{object.to_s} in #{object.file} should have valid example #{(i+1).to_s}" do
            lambda{ eval code }.should_not raise_error
          end
        end
      end
    end
  
  end
  
  describe "utils" do
  
    it "should raise when an object is not convertable" do
    
      lambda{ URITemplate::Utils.object_to_param(BasicObject.new) }.should raise_error(URITemplate::Unconvertable)
    
    end
  
  end

end
