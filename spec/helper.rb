# -*- encoding : utf-8 -*-
require 'bundler'
Bundler.setup(:default,:development)

if $0 !~ /mutant\z/
  # using coverage in mutant is pointless
  begin
    require 'simplecov'
    require 'simplecov-console'
    require 'coveralls'
    # the console output needs this to work:
    ROOT = File.expand_path('../lib',File.dirname(__FILE__))
    SimpleCov.start do
      add_filter '/spec'
      formatter SimpleCov::Formatter::MultiFormatter[
        Coveralls::SimpleCov::Formatter,
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::Console
      ]
      refuse_coverage_drop
      nocov_token "nocov"
    end
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

  def failure_message
    return [@actual.inspect, ' should not expand to ', @actual.expand(@variables).inspect ,' but ', @expected.inspect, ' when given the following variables: ',"\n", @variables.inspect ].join
  end

end

class URITemplate::PartialExpansionMatcher

  def initialize( variables, expected = nil )
    @variables = variables
    @expected = Array(expected)
  end

  def matches?( actual )
    @actual = actual
    s = @actual.expand_partial(@variables)
    return Array(@expected).any?{|e| e == s }
  end

  def to(expected)
    @expected = Array(expected)
    return self
  end

  def failure_message
    return [@actual.to_s, ' should not partially expand to ', @actual.expand_partial(@variables).to_s.inspect ,' but ', Array(@expected).map(&:to_s).to_s, ' when given the following variables: ',"\n", @variables.inspect ].join
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

  def failure_message
    return @message.join
  end

end

RSpec::Matchers.class_eval do

  def expand(variables = {})
    return URITemplate::ExpansionMatcher.new(variables)
  end

  def expand_partially(variables = {})
    return URITemplate::PartialExpansionMatcher.new(variables)
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

