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

if $0 !~ /mutant\z/
  # using simplecov in mutant is pointless
  begin
    require 'simplecov'
    SimpleCov.add_filter('/spec')
    SimpleCov.start
  rescue LoadError
    warn 'Not using simplecov.'
  end
end

Bundler.require(:default,:development)

require 'uri_template'

unless URITemplate::Utils.using_escape_utils?
  warn 'Not using escape_utils.'
end

if RUBY_DESCRIPTION =~ /\Ajruby/ and "".respond_to? :force_encoding
  # jruby produces ascii encoded json hashes :(
  def force_all_utf8(x)
    if x.kind_of? String
      return x.dup.force_encoding("UTF-8")
    elsif x.kind_of? Array
      return x.map{|a| force_all_utf8(a) }
    elsif x.kind_of? Hash
      return Hash[ x.map{|k,v| [force_all_utf8(k),force_all_utf8(v)]} ]
    else
      return x
    end
  end
else
  def force_all_utf8(x)
    return x
  end
end

class URITemplate::ExpansionMatcher

  def initialize( variables, expected = nil )
    @variables = variables
    @expected = expected
  end

  def matches?( actual )
    @actual = actual
    s = @actual.expand(@variables)
    # only in 1.8.7 Array("") is []
    ex = @expected == "" ? [""] : Array(@expected)
    return ex.any?{|e| e === s }
  end

  def to(expected)
    @expected = expected
    return self
  end

  def failure_message_for_should
    return [@actual.inspect, ' should not expand to ', @actual.expand(@variables).inspect ,' but ', @expected.inspect, ' when given the following variables: ',"\n", @variables.inspect ].join 
  end

end

class URITemplate::ExtractionMatcher

  def initialize( variables = nil, uri = '', fuzzy = true )
    @variables = variables.nil? ? variables : Hash[ variables.map{|k,v| [k.to_s, v]} ]
    @fuzzy = fuzzy
    @uri = uri 
  end

  def from( uri )
    @uri = uri
    return self
  end

  def matches?( actual )
    @message = []
    v = actual.extract(@uri)
    if v.nil?
      @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but didn\' extract anything.']
      return false
    end
    if @variables.nil?
      return true
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

  def expand(variables = {})
    return URITemplate::ExpansionMatcher.new(variables)
  end

  def expand_to( variables,expected )
    return URITemplate::ExpansionMatcher.new(variables, expected)
  end

  def extract( *args )
    return URITemplate::ExtractionMatcher.new(*args)
  end

  def extract_from( variables, uri)
    return URITemplate::ExtractionMatcher.new(variables, uri)
  end
end

