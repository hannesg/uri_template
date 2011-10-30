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

require 'strscan'
require 'set'
require 'forwardable'

require 'uri_template'
require 'uri_template/utils'

# A uri template which should comply with the uri template spec draft 7 ( http://tools.ietf.org/html/draft-gregorio-uritemplate-07 ).
# @note
#   Most specs and examples refer to this class directly, because they are acutally refering to this specific implementation. If you just want uri templates, you should rather use the methods on {URITemplate} to create templates since they will select an implementation.
class URITemplate::Draft7

  include URITemplate
  extend Forwardable
  
  # @private
  Utils = URITemplate::Utils
  
  # @private
  LITERAL = /^([^"'%<>\\^`{|}\s]|%\h\h)+/
  
  # @private
  CHARACTER_CLASSES = {
  
    :unreserved => {
      :unencoded => /([^A-Za-z0-9\-\._])/,
      :class => '(?<c_u_>[A-Za-z0-9\-\._]|%\h\h)',
      :class_name => 'c_u_',
      :grabs_comma => false
    },
    :unreserved_reserved_pct => {
      :unencoded => /([^A-Za-z0-9\-\._:\/?#\[\]@!\$%'\(\)*+,;=]|%(?!\h\h))/,
      :class => '(?<c_urp_>[A-Za-z0-9\-\._:\/?#\[\]@!\$%\'\(\)*+,;=]|%\h\h)',
      :class_name => 'c_urp_',
      :grabs_comma => true
    },
    
    :varname => {
      :class => '(?<c_vn_> (?:[a-zA-Z_]|%[0-9a-fA-F]{2})(?:[a-zA-Z_\.]|%[0-9a-fA-F]{2})*?)',
      :class_name => 'c_vn_'
    }
  
  }
  
  # Specifies that no processing should be done upon extraction.
  # @see extract
  NO_PROCESSING = []
  
  # Specifies that the extracted values should be processed.
  # @see extract
  CONVERT_VALUES = [:convert_values]
  
  # Specifies that the extracted variable list should be processed.
  # @see extract
  CONVERT_RESULT = [:convert_result]
  
  # Default processing. Means: convert values and the list itself.
  # @see extract
  DEFAULT_PROCESSING = CONVERT_VALUES + CONVERT_RESULT
  
  # @private
  VAR = Regexp.compile(<<'__REGEXP__'.strip, Regexp::EXTENDED)
(?<operator> [+#\./;?&]?){0}
(?<varchar> [a-zA-Z_]|%[0-9a-fA-F]{2}){0}
(?<varname> \g<varchar>(?:\g<varchar>|\.)*){0}
(?<varspec> \g<varname>(?<explode>\*?)(?::(?<length>\d+))?){0}
\g<varspec>
__REGEXP__
  
  # @private
  EXPRESSION = Regexp.compile(<<'__REGEXP__'.strip, Regexp::EXTENDED)
(?<operator> [+#\./;?&]?){0}
(?<varchar> [a-zA-Z_]|%[0-9a-fA-F]{2}){0}
(?<varname> \g<varchar>(?:\g<varchar>|\.)*){0}
(?<varspec> \g<varname>\*?(?::\d+)?){0}
\{\g<operator>(?<vars>\g<varspec>(?:,\g<varspec>)*)\}
__REGEXP__

  # @private
  URI = Regexp.compile(<<'__REGEXP__'.strip, Regexp::EXTENDED)
(?<operator> [+#\./;?&]?){0}
(?<varchar> [a-zA-Z_]|%[0-9a-fA-F]{2}){0}
(?<varname> \g<varchar>(?:\g<varchar>|\.)*){0}
(?<varspec> \g<varname>\*?(?::\d+)?){0}
^(([^"'%<>^`{|}\s]|%\h\h)+|\{\g<operator>(?<vars>\g<varspec>(?:,\g<varspec>)*)\})*$
__REGEXP__
  
  # @private
  class Literal
  
    attr_reader :string
  
    def initialize(string)
      @string = string
    end
    
    def size
      0
    end
    
    def expand(*_)
      return @string
    end
    
    def to_r_source(*_)
      Regexp.escape(@string)
    end
    
    def to_s
      @string
    end
    
  end
  
  # @private
  class LeftBound
    
    def expand(*_)
      ''
    end
    
    def to_r_source(*_)
      '^'
    end
    
    def size
      0
    end
    
    def to_s
      ''
    end
    
  end
  
  # @private
  class RightBound
    
    def expand(*_)
      ''
    end
    
    def to_r_source(*_)
      '$'
    end
    
    def size
      0
    end
    
    def to_s
      ''
    end
    
  end
  
  # @private
  class Open
    def expand(*_)
      ''
    end
    def to_r_source(*_)
      ''
    end
    def size
      0
    end
    def to_s
      "\u2026"
    end
  end
  
  # @private
  class Expression
    
    attr_reader :variables, :max_length
    
    def initialize(vars)
      @variables = vars
    end
    
    PREFIX = ''.freeze
    SEPARATOR = ','.freeze
    PAIR_CONNECTOR = '='.freeze
    PAIR_IF_EMPTY = true
    LIST_CONNECTOR = ','.freeze
    
    CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved]
    
    NAMED = false
    OPERATOR = ''
    
    def size
      @variables.size
    end
    
    def expand( vars, options )
      result = []
      variables.each{| var, expand , max_length |
        unless vars[var].nil?
          if vars[var].kind_of? Hash
            result.push( *transform_hash(var, vars[var], expand, max_length) )
          elsif vars[var].kind_of? Array
            result.push( *transform_array(var, vars[var], expand, max_length) )
          else
            if self.class::NAMED
              result.push( pair(var, vars[var], max_length) )
            else
              result.push( cut( encode(vars[var]), max_length ) )
            end
          end
        end
      }
      if result.any?
        return (self.class::PREFIX + result.join(self.class::SEPARATOR))
      else
        return ''
      end
    end
    
    def to_s
      '{' + self.class::OPERATOR +  @variables.map{|name,expand,max_length| name +(expand ? '*': '') + (max_length > 0 ? ':'+max_length.to_s : '') }.join(',') + '}'
    end
    
    #TODO: certain things after a slurpy variable will never get matched. therefore, it's pointless to add expressions for them
    #TODO: variables, which appear twice could be compacted, don't they?
    def to_r_source(base_counter = 0)
      source = []
      first = true
      vs = variables.size - 1
      i = 0
      if self.class::NAMED
        variables.each{| var, expand , max_length |
          last = (vs == i)
          value = "(?:\\g<#{self.class::CHARACTER_CLASS[:class_name]}>|,)#{(max_length > 0)?'{,'+max_length.to_s+'}':'*'}"
          if expand
            #if self.class::PAIR_IF_EMPTY
            pair = "\\g<c_vn_>(?:#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value})?"
            
            if first
              source << "(?<v#{base_counter + i}>(?:#{pair})(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*)"
            else
              source << "(?<v#{base_counter + i}>(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*)"
            end
          else
            if self.class::PAIR_IF_EMPTY
              pair = "#{Regexp.escape(var)}(?<v#{base_counter + i}>#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value})?"
            else
              pair = "#{Regexp.escape(var)}(?<v#{base_counter + i}>#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value}|)"
            end
            
            if first
            source << "(?:#{pair})"
            else
              source << "(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})?"
            end
          end
          
          first = false
          i = i+1
        }
      else
        variables.each{| var, expand , max_length |
          last = (vs == i)
          if expand
            # could be list or map, too
            value = "\\g<#{self.class::CHARACTER_CLASS[:class_name]}>#{(max_length > 0)?'{,'+max_length.to_s+'}':'*'}"
            
            pair = "\\g<c_vn_>(?:#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value})?"
            
            value = "#{pair}(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*"
          elsif last
            # the last will slurp lists
            if self.class::CHARACTER_CLASS[:grabs_comma]
              value = "(?:\\g<#{self.class::CHARACTER_CLASS[:class_name]}>)#{(max_length > 0)?'{,'+max_length.to_s+'}':'*?'}"
            else
              value = "(?:\\g<#{self.class::CHARACTER_CLASS[:class_name]}>|,)#{(max_length > 0)?'{,'+max_length.to_s+'}':'*?'}"
            end
          else
            value = "\\g<#{self.class::CHARACTER_CLASS[:class_name]}>#{(max_length > 0)?'{,'+max_length.to_s+'}':'*?'}"
          end
          if first
            source << "(?<v#{base_counter + i}>#{value})"
            first = false
          else
            source << "(?:#{Regexp.escape(self.class::SEPARATOR)}(?<v#{base_counter + i}>#{value}))?"
          end
          i = i+1
        }
      end
      return '(?:' + Regexp.escape(self.class::PREFIX) + source.join + ')?'
    end
    
    def extract(position,matched)
      name, expand, max_length = @variables[position]
      if matched.nil?
        return [[ name , matched ]]
      end
      if expand
        ex = self.hash_extractor(max_length)
        rest = matched
        splitted = []
        found_value = false
        until rest.size == 0
          match = ex.match(rest)
          if match.nil?
            raise "Couldn't match #{rest.inspect} againts the hash extractor. This is definitly a Bug. Please report this ASAP!"
          end
          if match.post_match.size == 0
            rest = match['rest'].to_s
          else
            rest = ''
          end
          if match['name']
            found_value = true
            splitted << [ match['name'][0..-2], decode(match['value'] + rest , false) ]
          else
            splitted << [ decode(match['value'] + rest , false), nil ]
          end
          rest = match.post_match
        end
        if !found_value
          return [ [ name, splitted.map{|n,v| v || n } ] ]
        else
          return [ [ name, splitted ] ]
        end
      elsif self.class::NAMED
        return [ [ name, decode( matched[1..-1] ) ] ]
      end
      
      return [ [ name,  decode( matched ) ] ]
    end
    
    def variable_names
      @variables.collect(&:first)
    end
     
  protected
    
    def hash_extractor(max_length)
      value = "\\g<#{self.class::CHARACTER_CLASS[:class_name]}>#{(max_length > 0)?'{,'+max_length.to_s+'}':'*?'}"
      
      pair = "(?<name>\\g<c_vn_>#{Regexp.escape(self.class::PAIR_CONNECTOR)})?(?<value>#{value})"
      
      return Regexp.new( CHARACTER_CLASSES[:varname][:class] + "{0}\n" + self.class::CHARACTER_CLASS[:class] + "{0}\n"  + "^#{Regexp.escape(self.class::SEPARATOR)}?" + pair + "(?<rest>$|#{Regexp.escape(self.class::SEPARATOR)}(?!#{Regexp.escape(self.class::SEPARATOR)}))" ,Regexp::EXTENDED)
      
    end
    
    def encode(x)
      Utils.pct(Utils.object_to_param(x), self.class::CHARACTER_CLASS[:unencoded])
    end
    
    SPLITTER = /^(?:,(,*)|([^,]+))/
    
    def decode(x, split = true)
      if x.nil?
        if self.class::PAIR_IF_EMPTY
          return x
        else
          return ''
        end
      elsif split
        r = []
        v = x
        until v.size == 0
          m = SPLITTER.match(v)
          if m[1] and m[1].size > 0
            r << m[1]
          elsif m[2]
            r << Utils.dpct(m[2])
          end
          v = m.post_match
        end
        case(r.size)
          when 0 then ''
          when 1 then r.first
          else r
        end
      else
        Utils.dpct(x)
      end
    end
    
    def cut(str,chars)
      if chars > 0
        md = Regexp.compile("^#{self.class::CHARACTER_CLASS[:class]}{,#{chars.to_s}}", Regexp::EXTENDED).match(str)
        #TODO: handle invalid matches
        return md[0]
      else
        return str
      end
    end
    
    def pair(key, value, max_length = 0)
      ek = encode(key)
      ev = encode(value)
      if !self.class::PAIR_IF_EMPTY and ev.size == 0
        return ek
      else
        return ek + self.class::PAIR_CONNECTOR + cut( ev, max_length )
      end
    end
    
    def transform_hash(name, hsh, expand , max_length)
      if expand
        hsh.map{|key,value| pair(key,value) }
      elsif hsh.none?
        []
      else
        [ (self.class::NAMED ? encode(name)+self.class::PAIR_CONNECTOR : '' ) + hsh.map{|key,value| encode(key)+self.class::LIST_CONNECTOR+encode(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end
    
    def transform_array(name, ary, expand , max_length)
      if expand
        ary.map{|value| encode(value) }
      elsif ary.none?
        []
      else
        [ (self.class::NAMED ? encode(name)+self.class::PAIR_CONNECTOR : '' ) + ary.map{|value| encode(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end
    
    class Reserved < self
    
      CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved_reserved_pct]
      OPERATOR = '+'.freeze
    
    end
    
    class Fragment < self
    
      CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved_reserved_pct]
      PREFIX = '#'.freeze
      OPERATOR = '#'.freeze
    
    end
    
    class Label < self
    
      SEPARATOR = '.'.freeze
      PREFIX = '.'.freeze
      OPERATOR = '.'.freeze
    
    end
    
    class Path < self
    
      SEPARATOR = '/'.freeze
      PREFIX = '/'.freeze
      OPERATOR = '/'.freeze
    
    end
    
    class PathParameters < self
    
      SEPARATOR = ';'.freeze
      PREFIX = ';'.freeze
      NAMED = true
      PAIR_IF_EMPTY = false
      OPERATOR = ';'.freeze
    
    end
    
    class FormQuery < self
    
      SEPARATOR = '&'.freeze
      PREFIX = '?'.freeze
      NAMED = true
      OPERATOR = '?'.freeze
    
    end
    
    class FormQueryContinuation < self
    
      SEPARATOR = '&'.freeze
      PREFIX = '&'.freeze
      NAMED = true
      OPERATOR = '&'.freeze
    
    end
    
  end
  
  # @private
  OPERATORS = {
    ''  => Expression,
    '+' => Expression::Reserved,
    '#' => Expression::Fragment,
    '.' => Expression::Label,
    '/' => Expression::Path,
    ';' => Expression::PathParameters,
    '?' => Expression::FormQuery,
    '&' => Expression::FormQueryContinuation
  }
  
  # This error is raised when an invalid pattern was given.
  class Invalid < StandardError
    
    include URITemplate::Invalid
  
    attr_reader :pattern, :position
    
    def initialize(source, position)
      @pattern = pattern
      @position = position
      super("Invalid expression found in #{source.inspect} at #{position}: '#{source[position..-1]}'")
    end
    
  end
  
  # @private
  class Tokenizer
  
    include Enumerable
    
    attr_reader :source
    
    def initialize(source)
      @source = source
    end
  
    def each
      if !block_given?
        return Enumerator.new(self)
      end
      scanner = StringScanner.new(@source)
      until scanner.eos?
        expression = scanner.scan(EXPRESSION)
        if expression
          vars = scanner[5].split(',').map{|name|
            match = VAR.match(name)
            [ match['varname'], match['explode'] == '*', match['length'].to_i ]
          }
          yield OPERATORS[scanner[1]].new(vars)
        else
          literal = scanner.scan(LITERAL)
          if literal
            yield(Literal.new(literal))
          else
            raise Invalid.new(@source,scanner.pos)
          end
        end
      end
    end
  
  end
  
  # The class methods for all draft7 templates.
  module ClassMethods
  
    # Tries to convert the given param in to a instance of {Draft7}
    # It basically passes thru instances of that class, parses strings and return nil on everything else.
    # @example
    #   URITemplate::Draft7.try_convert( Object.new ) #=> nil
    #   tpl = URITemplate::Draft7.new('{foo}')
    #   URITemplate::Draft7.try_convert( tpl ) #=> tpl
    #   URITemplate::Draft7.try_convert('{foo}') #=> tpl
    #   # This pattern is invalid, so it wont be parsed:
    #   URITemplate::Draft7.try_convert('{foo') #=> nil
    def try_convert(x)
      if x.kind_of? self
        return x
      elsif x.kind_of? String and valid? x
        return new(x)
      else
        return nil
      end
    end
    
    # Tests whether a given pattern is a valid template pattern.
    # @example
    #   URITemplate::Draft7.valid? 'foo' #=> true
    #   URITemplate::Draft7.valid? '{foo}' #=> true
    #   URITemplate::Draft7.valid? '{foo' #=> false
    def valid?(pattern)
      URI === pattern
    end
  
  end
  
  extend ClassMethods
  
  attr_reader :pattern
  
  attr_reader :options
  
  # @param String,Array either a pattern as String or an Array of tokens
  # @param Hash some options
  # @option :lazy If true the pattern will be parsed on first access, this also means that syntax errors will not be detected unless accessed.
  def initialize(pattern_or_tokens,options={})
    @options = options.dup.freeze
    if pattern_or_tokens.kind_of? String
      @pattern = pattern_or_tokens.dup
      @pattern.freeze
      unless @options[:lazy]
        self.tokens
      end
    elsif pattern_or_tokens.kind_of? Array
      @tokens = pattern_or_tokens.dup
      @tokens.freeze
    else
      raise ArgumentError, "Expected to receive a pattern string, but got #{pattern_or_tokens.inspect}"
    end
  end
  
  # Expands the template with the given variables.
  # The expansion should be compatible to uritemplate spec draft 7 ( http://tools.ietf.org/html/draft-gregorio-uritemplate-07 ).
  # @note
  #   All keys of the supplied hash should be strings as anything else won't be recognised.
  # @note
  #   There are neither default values for variables nor will anything be raised if a variable is missing. Please read the spec if you want to know how undefined variables are handled.
  # @example
  #   URITemplate::Draft7.new('{foo}').expand('foo'=>'bar') #=> 'bar'
  #   URITemplate::Draft7.new('{?args*}').expand('args'=>{'key'=>'value'}) #=> '?key=value'
  #   URITemplate::Draft7.new('{undef}').expand() #=> ''
  #
  # @param variables Hash
  # @return String
  def expand(variables = {})
    tokens.map{|part|
      part.expand(variables, {})
    }.join
  end
  
  # Returns an array containing all variables. Repeated variables are ignored, but the order will be kept intact.
  # @example
  #   URITemplate::Draft7.new('{foo}{bar}{baz}').variables #=> ['foo','bar','baz']
  #   URITemplate::Draft7.new('{a}{c}{a}{b}').variables #=> ['c','a','b']
  #
  # @return Array
  def variables
    @variables ||= begin
      vars = []
      tokens.each{|token|
        if token.respond_to? :variable_names
          vn = token.variable_names.uniq
          vars -= vn
          vars.push(*vn)
        end
      }
      vars
    end
  end
  
  # Compiles this template into a regular expression which can be used to test whether a given uri matches this template. This template is also used for {#===}.
  #
  # @example
  #   tpl = URITemplate::Draft7.new('/foo/{bar}/')
  #   regex = tpl.to_r
  #   regex === '/foo/baz/' #=> true
  #   regex === '/foz/baz/' #=> false
  # 
  # @return Regexp
  def to_r
    classes = CHARACTER_CLASSES.map{|_,v| v[:class]+"{0}\n" }
    bc = 0
    @regexp ||= Regexp.new(classes.join + tokens.map{|part|
      r = part.to_r_source(bc)
      bc += part.size
      r
    }.join, Regexp::EXTENDED)
  end
  
  
  # Extracts variables from a uri ( given as string ) or an instance of MatchData ( which was matched by the regexp of this template.
  # The actual result depends on the value of @p post_processing.
  # This argument specifies whether pair arrays should be converted to hashes.
  # 
  # @example
  #   URITemplate::Draft7.new('{var}').extract('value') #=> {'var'=>'value'}
  #   URITemplate::Draft7.new('{&args*}').extract('&a=1&b=2') #=> {'args'=>{'a'=>'1','b'=>'2'}}
  #   URITemplate::Draft7.new('{&arg,arg}').extract('&arg=1&arg=2') #=> {'arg'=>'2'}
  #
  # @example
  #   URITemplate::Draft7.new('{var}').extract('value', URITemplate::Draft7::NO_PROCESSING) #=> [['var','value']]
  #   URITemplate::Draft7.new('{&args*}').extract('&a=1&b=2', URITemplate::Draft7::NO_PROCESSING) #=> [['args',[['a','1'],['b','2']]]]
  #   URITemplate::Draft7.new('{&arg,arg}').extract('&arg=1&arg=2', URITemplate::Draft7::NO_PROCESSING) #=> [['arg','1'],['arg','2']]
  #
  #   
  def extract(uri_or_match, post_processing = DEFAULT_PROCESSING )
    if uri_or_match.kind_of? String
      m = self.to_r.match(uri_or_match)
    elsif uri_or_match.kind_of?(MatchData)
      if uri_or_match.regexp != self.to_r
        raise ArgumentError, "Trying to extract variables from MatchData which was not generated by this template."
      end
      m = uri_or_match
    elsif uri_or_match.nil?
      return nil
    else
      raise ArgumentError, "Expected to receive a String or a MatchData, but got #{uri_or_match.inspect}."
    end
    if m.nil?
      return nil
    else
      result = extract_matchdata(m)
      if post_processing.include? :convert_values
        result.map!{|k,v| [k, Utils.pair_array_to_hash(v)] }
      end
      
      if post_processing.include? :convert_result
        result = Utils.pair_array_to_hash(result)
      end
      
      if block_given?
        return yield result
      end
      
      return result
    end
  end
  
  # Extracts variables without any proccessing.
  # This is equivalent to {#extract} with options {NO_PROCESSING}.
  # @see #extract
  def extract_simple(uri_or_match)
    extract( uri_or_match, NO_PROCESSING )
  end
  
  # Returns the pattern for this template.
  def pattern
    @pattern ||= tokens.map(&:to_s).join
  end
  
  alias to_s pattern

  # Sections are a custom extension to the uri template spec.
  # A template section ( in comparison to a template ) can be unbounded on its ends. Therefore they don't necessarily match a whole uri and can be concatenated.
  # Unboundedness is denoted with unicode character \u2026 ( … ).
  # 
  # @example
  #   prefix = URITemplate::Draft7::Section.new('/prefix…')
  #   template = URITemplate::Draft7.new('/prefix')
  #   prefix === '/prefix/something completly different' #=> true
  #   template === '/prefix/something completly different' #=> false
  #   prefix.to_r.match('/prefix/something completly different').post_match #=> '/something completly different'
  # 
  # @example
  #   prefix = URITemplate::Draft7::Section.new('/prefix…')
  #   tpl = prefix >> '…/end'
  #   tpl.pattern #=> '/prefix/end'
  # 
  # This behavior is usefull for building routers:
  # 
  # @example
  #   
  #   def route( uri )
  #     prefixes = [
  #       [ 'app_a/…' , lambda{|vars, rest| "app_a: #{rest} with #{vars.inspect}" } ],
  #       [ 'app_b/{x}/…', lambda{|vars, rest| "app_b: #{rest} with #{vars.inspect}" } ]
  #     ]
  #     prefixes.each do |tpl, lb|
  #       tpl = URITemplate::Draft7::Section.new(tpl)
  #       tpl.match(uri) do |match_data|
  #         return lb.call(tpl.extract(match_data), match_data.post_match)
  #       end
  #     end
  #     return "not found"
  #   end
  #   route( 'app_a/do_something' ) #=> "app_a: do_something with {}"
  #   route( 'app_b/1337/something_else' ) #=> "app_b: something_else with {\"x\"=>\"1337\"}"
  #   route( 'bla' ) #=> 'not found'
  # 
  class Section < self
  
    include URITemplate::Section
  
    # The ellipsis character.
    ELLIPSIS = "\u2026".freeze
    
    # Is this section left bounded?
    def left_bound?
      tokens.first.kind_of? LeftBound
    end
    
    # Is this section right bounded?
    def right_bound?
      tokens.last.kind_of? RightBound
    end
    
    # Concatenates this section with anything that can be coerced into a section.
    # 
    # @example
    #   sect = URITemplate::Draft7::Section.new('/prefix…')
    #   sect >> '…/mid…' >> '…/end' # URITemplate::Draft7::Section.new('/prefix/mid/end')
    # 
    # @return Section
    def >>(other)
      o = self.class.try_convert(other)
      if o.kind_of? Section
        if !self.right_bound? and !o.left_bound?
          return self.class.new(self.tokens[0..-2] + o.tokens[1..-1], o.options)
        end
      else
        raise ArgumentError, "Expected something that could be converted to a URITemplate section, but got #{other.inspect}"
      end
    end
    
    protected
    # @private
    def tokenize!
      pat = pattern
      if pat == ELLIPSIS
        return [Open.new]
      end
      lb = (pat[0] != ELLIPSIS)
      rb = (pat[-1] != ELLIPSIS)
      pat = pat[ (lb ? 0 : 1)..(rb ? -1 : -2) ]
      [lb ? LeftBound.new : Open.new] + Tokenizer.new(pat).to_a + [rb ? RightBound.new : Open.new]
    end
  
  end
  
  # Compares two template patterns.
  def ==(tpl)
    return false if self.class != tpl.class
    return self.pattern == tpl.pattern
  end
  
  # @method ===(uri)
  # Alias for to_r.=== . Tests whether this template matches a given uri.
  # @return TrueClass, FalseClass
  def_delegators :to_r, :===
  
  # @method match(uri)
  # Alias for to_r.match . Matches this template against the given uri.
  # @yield MatchData
  # @return MatchData, Object 
  def_delegators :to_r, :match

protected
  # @private
  def tokenize!
    [LeftBound.new] + Tokenizer.new(pattern).to_a + [RightBound.new]
  end
  
  def tokens
    @tokens ||= tokenize!
  end
  
  # @private
  def extract_matchdata(matchdata)
    bc = 0
    vars = []
    tokens.each{|part|
      i = 0
      while i < part.size
        vars.push(*part.extract(i, matchdata["v#{bc}"]))
        bc += 1
        i += 1
      end
    }
    return vars
  end
  
end


