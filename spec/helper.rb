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

$LOAD_PATH << File.expand_path('../lib',File.dirname(__FILE__))

require 'bundler'
Bundler.setup(:default,:development)
Bundler.require(:default,:development)

begin
  require 'simplecov'
  SimpleCov.add_filter('spec')
  SimpleCov.start
rescue LoadError
  warn 'Not using simplecov.'
end

require 'uri_template'

unless URITemplate::Utils.using_escape_utils?
  warn 'Not using escape_utils.'
end


class URITemplate::ExpansionMatcher

  def initialize( variables, expected )
    @variables = variables
    @expected = expected
  end

  def matches?( actual )
    @actual = actual
    s = @actual.expand(@variables)
    return Array(@expected).any?{|e| e === s }
  end

  def failure_message_for_should
    return [@actual.inspect, ' should not expand to ', @actual.expand(@variables).inspect ,' but ', @expected.inspect, ' when given the following variables: ',"\n", @variables.inspect ].join 
  end

end

class URITemplate::ExtractionMatcher

  def initialize( variables, uri, fuzzy = true )
    @variables = variables
    @fuzzy = fuzzy
    @uri = uri 
  end

  def matches?( actual )
    @message = []
    v = actual.extract(@uri)
    if v.nil?
      @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but didn\' extract anything.']
      return false
    end
    if !@fuzzy
      @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but got ',v.inspect]
      return @variables == v
    else
      tpl_variable_names = actual.variables
      diff = []
      @variables.each do |key,val|
        if tpl_variable_names.include? key
          if val != v[key]
            diff << [key, val, v[key] ]
          end
        end
      end
      v.each do |key,val|
        if !@variables.key? key
          diff << [key, nil, val]
        end
      end
      if !diff.empty?
        @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but got ',v.inspect]
        diff.each do |key, should, actual|
          @message << "\n\t" << key << ":\tshould: " << should.inspect << ", is: " << actual.inspect
        end
      end
      return diff.empty?
    end
  end

  def failure_message_for_should
    return @message.join
  end

end

RSpec::Matchers.class_eval do
  def expand_to( variables,expected )
    return URITemplate::ExpansionMatcher.new(variables, expected)
  end

  def extract_from( variables, uri)
    return URITemplate::ExtractionMatcher.new(variables, uri)
  end
end

