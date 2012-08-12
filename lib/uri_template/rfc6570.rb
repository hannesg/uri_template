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

require 'strscan'
require 'set'
require 'forwardable'

require 'uri_template'
require 'uri_template/utils'

# A uri template which should comply with the rfc 6570 ( http://tools.ietf.org/html/rfc6570 ).
# @note
#   Most specs and examples refer to this class directly, because they are acutally refering to this specific implementation. If you just want uri templates, you should rather use the methods on {URITemplate} to create templates since they will select an implementation.
class URITemplate::RFC6570

  TYPE = :rfc6570

  include URITemplate
  extend Forwardable

  # @private
  Utils = URITemplate::Utils

  if SUPPORTS_UNICODE_CHARS
    # @private
    #                           \/ - unicode ctrl-chars
    LITERAL = /([^"'%<>\\^`{|}\u0000-\u001F\u007F-\u009F\s]|%[0-9a-fA-F]{2})+/u
  else
    # @private
    LITERAL = Regexp.compile('([^"\'%<>\\\\^`{|}\x00-\x1F\x7F-\x9F\s]|%[0-9a-fA-F]{2})+',Utils::KCODE_UTF8)
  end

  # @private
  CHARACTER_CLASSES = {

    :unreserved => {
      :class => '(?:[A-Za-z0-9\-\._]|%[0-9a-fA-F]{2})', 
      :grabs_comma => false
    },
    :unreserved_reserved_pct => {
      :class => '(?:[A-Za-z0-9\-\._:\/?#\[\]@!\$%\'\(\)*+,;=]|%[0-9a-fA-F]{2})',
      :grabs_comma => true
    },

    :varname => {
      :class => '(?:[a-zA-Z_]|%[0-9a-fA-F]{2})(?:[a-zA-Z_\.]|%[0-9a-fA-F]{2})*?',
      :class_name => 'c_vn_'
    }

  }

  # Specifies that no processing should be done upon extraction.
  # @see #extract
  NO_PROCESSING = []

  # Specifies that the extracted values should be processed.
  # @see #extract
  CONVERT_VALUES = [:convert_values]

  # Specifies that the extracted variable list should be processed.
  # @see #extract
  CONVERT_RESULT = [:convert_result]

  # Default processing. Means: convert values and the list itself.
  # @see #extract
  DEFAULT_PROCESSING = CONVERT_VALUES + CONVERT_RESULT

  # @private
  VAR = Regexp.compile(<<'__REGEXP__'.strip, Utils::KCODE_UTF8)
((?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2})(?:\.?(?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2}))*)(\*)?(?::(\d+))?
__REGEXP__

  # @private
  EXPRESSION = Regexp.compile(<<'__REGEXP__'.strip, Utils::KCODE_UTF8)
\{([+#\./;?&]?)((?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2})(?:\.?(?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2}))*\*?(?::\d+)?(?:,(?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2})(?:\.?(?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2}))*\*?(?::\d+)?)*)\}
__REGEXP__

  # @private
  URI = Regexp.compile(<<__REGEXP__.strip, Utils::KCODE_UTF8)
\\A(#{LITERAL.source}|#{EXPRESSION.source})*\\z
__REGEXP__

  SLASH = ?/

  # @private
  class Token
  end

  # @private
  class Literal < Token

    include URITemplate::Literal

    def initialize(string)
      @string = string
    end

    def level
      1
    end

    def arity
      0
    end

    def to_r_source(*_)
      Regexp.escape(@string)
    end

    def to_s
      @string
    end

  end


  # @private
  class Expression < Token

    include URITemplate::Expression

    attr_reader :variables, :max_length

    def initialize(vars)
      @variable_specs = vars
      @variables = vars.map(&:first)
      @variables.uniq!
    end

    PREFIX = ''.freeze
    SEPARATOR = ','.freeze
    PAIR_CONNECTOR = '='.freeze
    PAIR_IF_EMPTY = true
    LIST_CONNECTOR = ','.freeze
    BASE_LEVEL = 1

    CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved]

    NAMED = false
    OPERATOR = ''

    def level
      if @variable_specs.none?{|_,expand,ml| expand || (ml > 0) }
        if @variable_specs.size == 1
          return self.class::BASE_LEVEL
        else
          return 3
        end
      else
        return 4
      end
    end

    def expands?
      @variable_specs.any?{|_,expand,_| expand }
    end

    def arity
      @variable_specs.size
    end

    def expand( vars )
      result = []
      @variable_specs.each{| var, expand , max_length |
        unless vars[var].nil?
          if vars[var].kind_of?(Hash) or Utils.pair_array?(vars[var])
            if max_length && max_length > 0
              raise InvalidValue::LengthLimitInapplicable.new(var,vars[var])
            end
            result.push( *transform_hash(var, vars[var], expand, max_length) )
          elsif vars[var].kind_of? Array
            if max_length && max_length > 0
              raise InvalidValue::LengthLimitInapplicable.new(var,vars[var])
            end
            result.push( *transform_array(var, vars[var], expand, max_length) )
          else
            if self.class::NAMED
              result.push( pair(var, vars[var], max_length) )
            else
              result.push( cut( escape(vars[var]), max_length ) )
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
      return '{' + self.class::OPERATOR + @variable_specs.map{|name,expand,max_length| name + (expand ? '*': '') + (max_length > 0 ? (':' + max_length.to_s) : '') }.join(',') + '}'
    end

    #TODO: certain things after a slurpy variable will never get matched. therefore, it's pointless to add expressions for them
    #TODO: variables, which appear twice could be compacted, don't they?
    def to_r_source
      source = []
      first = true
      vs = @variable_specs.size - 1
      i = 0
      if self.class::NAMED
        @variable_specs.each{| var, expand , max_length |
          value = "(?:#{self.class::CHARACTER_CLASS[:class]}|,)#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*'}"
          if expand
            #if self.class::PAIR_IF_EMPTY
            pair = "#{CHARACTER_CLASSES[:varname][:class]}#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value}"

            if first
              source << "((?:#{pair})(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*)"
            else
              source << "((?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*)"
            end
          else
            if self.class::PAIR_IF_EMPTY
              pair = "#{Regexp.escape(var)}(#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value})"
            else
              pair = "#{Regexp.escape(var)}(#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value}|)"
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
        @variable_specs.each{| var, expand , max_length |
          last = (vs == i)
          if expand
            # could be list or map, too
            value = "#{self.class::CHARACTER_CLASS[:class]}#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*'}"

            pair = "(?:#{CHARACTER_CLASSES[:varname][:class]}#{Regexp.escape(self.class::PAIR_CONNECTOR)})?#{value}"

            value = "#{pair}(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*"
          elsif last
            # the last will slurp lists
            if self.class::CHARACTER_CLASS[:grabs_comma]
              value = "#{self.class::CHARACTER_CLASS[:class]}#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*?'}"
            else
              value = "(?:#{self.class::CHARACTER_CLASS[:class]}|,)#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*?'}"
            end
          else
            value = "#{self.class::CHARACTER_CLASS[:class]}#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*?'}"
          end
          if first
            source << "(#{value})"
            first = false
          else
            source << "(?:#{Regexp.escape(self.class::SEPARATOR)}(#{value}))?"
          end
          i = i+1
        }
      end
      return '(?:' + Regexp.escape(self.class::PREFIX) + source.join + ')?'
    end

    def extract(position,matched)
      name, expand, max_length = @variable_specs[position]
      if matched.nil?
        return [[ name , matched ]]
      end
      if expand
        #TODO: do we really need this? - this could be stolen from rack
        ex = self.class.hash_extractor(max_length)
        rest = matched
        splitted = []
        if self.class::NAMED
          # 1 = name
          # 2 = value
          # 3 = rest
          until rest.size == 0
            match = ex.match(rest)
            if match.nil?
              raise "Couldn't match #{rest.inspect} againts the hash extractor. This is definitly a Bug. Please report this ASAP!"
            end
            if match.post_match.size == 0
              rest = match[3].to_s
            else
              rest = ''
            end
            splitted << [ decode(match[1]), decode(match[2] + rest , false) ]
            rest = match.post_match
          end
          result = Utils.pair_array_to_hash2( splitted )
          if result.size == 1 && result[0][0] == name
            return result
          else
            return [ [ name , result ] ]
          end
        else
          found_value = false
          # 1 = name and seperator
          # 2 = value
          # 3 = rest
          until rest.size == 0
            match = ex.match(rest)
            if match.nil?
              raise "Couldn't match #{rest.inspect} againts the hash extractor. This is definitly a Bug. Please report this ASAP!"
            end
            if match.post_match.size == 0
              rest = match[3].to_s
            else
              rest = ''
            end
            if match[1]
              found_value = true
              splitted << [ decode(match[1][0..-2]), decode(match[2] + rest , false) ]
            else
              splitted << [ decode(match[2] + rest), nil ]
            end
            rest = match.post_match
          end
          if !found_value
            return [ [ name, splitted.map{|n,v| decode(n , false) } ] ]
          else
            return [ [ name, splitted ] ]
          end
        end
      elsif self.class::NAMED
        return [ [ name, decode( matched[1..-1] ) ] ]
      end

      return [ [ name,  decode( matched ) ] ]
    end

  protected

    module ClassMethods

      def hash_extractor(max_length)
        @hash_extractors ||= {}
        @hash_extractors[max_length] ||= begin
          value = "#{self::CHARACTER_CLASS[:class]}#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*?'}"
          if self::NAMED
            pair = "(#{CHARACTER_CLASSES[:varname][:class]})#{Regexp.escape(self::PAIR_CONNECTOR)}(#{value})"
          else
            pair = "(#{CHARACTER_CLASSES[:varname][:class]}#{Regexp.escape(self::PAIR_CONNECTOR)})?(#{value})"
          end
          source = "\\A#{Regexp.escape(self::SEPARATOR)}?" + pair + "(\\z|#{Regexp.escape(self::SEPARATOR)}(?!#{Regexp.escape(self::SEPARATOR)}))"
          Regexp.new( source , Utils::KCODE_UTF8)
        end
      end

    end

    extend ClassMethods

    def escape(x)
      Utils.escape_url(Utils.object_to_param(x))
    end

    def unescape(x)
      Utils.unescape_url(x)
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
            if m.post_match.size == 0
              r << m[1]
            else
              r << m[1][0..-2]
            end
          elsif m[2]
            r << unescape(m[2])
          end
          v = m.post_match
        end
        case(r.size)
          when 0 then ''
          when 1 then r.first
          else r
        end
      else
        unescape(x)
      end
    end

    def cut(str,chars)
      if chars > 0
        md = Regexp.compile("\\A#{self.class::CHARACTER_CLASS[:class]}{0,#{chars.to_s}}", Utils::KCODE_UTF8).match(str)
        #TODO: handle invalid matches
        return md[0]
      else
        return str
      end
    end

    def pair(key, value, max_length = 0)
      ek = key
      ev = escape(value)
      if !self.class::PAIR_IF_EMPTY and ev.size == 0
        return ek
      else
        return ek + self.class::PAIR_CONNECTOR + cut( ev, max_length )
      end
    end

    def transform_hash(name, hsh, expand , max_length)
      if expand
        hsh.map{|key,value| pair(escape(key),value) }
      elsif hsh.none?
        []
      else
        [ (self.class::NAMED ? escape(name)+self.class::PAIR_CONNECTOR : '' ) + hsh.map{|key,value| escape(key)+self.class::LIST_CONNECTOR+escape(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end

    def transform_array(name, ary, expand , max_length)
      if expand
        self.class::NAMED ? ary.map{|value| pair(name,value) } : ary.map{|value| escape(value) }
      elsif ary.none?
        []
      else
        [ (self.class::NAMED ? escape(name)+self.class::PAIR_CONNECTOR : '' ) + ary.map{|value| escape(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end

    class Reserved < self

      CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved_reserved_pct]
      OPERATOR = '+'.freeze
      BASE_LEVEL = 2

      def escape(x)
        Utils.escape_uri(Utils.object_to_param(x))
      end

      def unescape(x)
        Utils.unescape_uri(x)
      end

    end

    class Fragment < self

      CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved_reserved_pct]
      PREFIX = '#'.freeze
      OPERATOR = '#'.freeze
      BASE_LEVEL = 2

      def escape(x)
        Utils.escape_uri(Utils.object_to_param(x))
      end

      def unescape(x)
        Utils.unescape_uri(x)
      end

    end

    class Label < self

      SEPARATOR = '.'.freeze
      PREFIX = '.'.freeze
      OPERATOR = '.'.freeze
      BASE_LEVEL = 3

    end

    class Path < self

      SEPARATOR = '/'.freeze
      PREFIX = '/'.freeze
      OPERATOR = '/'.freeze
      BASE_LEVEL = 3

    end

    class PathParameters < self

      SEPARATOR = ';'.freeze
      PREFIX = ';'.freeze
      NAMED = true
      PAIR_IF_EMPTY = false
      OPERATOR = ';'.freeze
      BASE_LEVEL = 3

    end

    class FormQuery < self

      SEPARATOR = '&'.freeze
      PREFIX = '?'.freeze
      NAMED = true
      OPERATOR = '?'.freeze
      BASE_LEVEL = 3

    end

    class FormQueryContinuation < self

      SEPARATOR = '&'.freeze
      PREFIX = '&'.freeze
      NAMED = true
      OPERATOR = '&'.freeze
      BASE_LEVEL = 3

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
      @pattern = source
      @position = position
      super("Invalid expression found in #{source.inspect} at #{position}: '#{source[position..-1]}'")
    end

  end

  class InvalidValue < StandardError

    include URITemplate::InvalidValue

    attr_reader :variable, :value

    def initialize(variable, value)
      @variable = variable
      @value = value
      super(generate_message())
    end
  protected

    def generate_message()
      return "The template variable " + variable.inspect + " cannot expand the given value "+ value.inspect
    end

  end

  class InvalidValue::LengthLimitInapplicable < InvalidValue

  protected
    def generate_message()
      return "The template variable "+variable.inspect+" has a length limit and therefore cannot expand an associative value ("+value.inspect+")."
    end

  end

  # @private
  class Tokenizer

    include Enumerable

    attr_reader :source

    def initialize(source, ops)
      @source = source
      @operators = ops
    end

    def each
      if !block_given?
        return Enumerator.new(self)
      end
      scanner = StringScanner.new(@source)
      until scanner.eos?
        expression = scanner.scan(EXPRESSION)
        if expression
          vars = scanner[2].split(',').map{|name|
            match = VAR.match(name)
            # 1 = varname
            # 2 = explode
            # 3 = length
            [ match[1], match[2] == '*', match[3].to_i ]
          }
          yield @operators[scanner[1]].new(vars)
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

  # The class methods for all rfc6570 templates.
  module ClassMethods

    # Tries to convert the given param in to a instance of {RFC6570}
    # It basically passes thru instances of that class, parses strings and return nil on everything else.
    #
    # @example
    #   URITemplate::RFC6570.try_convert( Object.new ) #=> nil
    #   tpl = URITemplate::RFC6570.new('{foo}')
    #   URITemplate::RFC6570.try_convert( tpl ) #=> tpl
    #   URITemplate::RFC6570.try_convert('{foo}') #=> tpl
    #   URITemplate::RFC6570.try_convert(URITemplate.new(:colon, ':foo')) #=> tpl
    #   URITemplate::RFC6570.try_convert(URITemplate.new(:draft7, '{foo}')) #=> tpl
    #   # Draft7 and RFC6570 handle expansion of named variables a bit differently:
    #   URITemplate::RFC6570.try_convert(URITemplate.new(:draft7, '{?list*}')) #=> nil
    #   # This pattern is invalid, so it wont be parsed:
    #   URITemplate::RFC6570.try_convert('{foo') #=> nil
    #
    def try_convert(x)
      if x.class == self
        return x
      elsif x.kind_of? String and valid? x
        return new(x)
      elsif x.kind_of? URITemplate::Colon
        return nil if x.tokens.any?{|tk| tk.kind_of? URITemplate::Colon::Token::Splat }
        return new( x.tokens.map{|tk|
          if tk.literal?
            Literal.new(tk.string)
          else
            Expression.new([[tk.variables.first, false, 0]])
          end
        })
      elsif (x.class == URITemplate::Draft7 and self == URITemplate::RFC6570) or (x.class == URITemplate::RFC6570 and self == URITemplate::Draft7)
        if x.tokens.none?{|t| t.class::NAMED and t.expands? }
          return self.new(x.to_s)
        end
      else
        return nil
      end
    end

    # Like {.try_convert}, but raises an ArgumentError, when the conversion failed.
    # 
    # @raise ArgumentError
    def convert(x)
      o = self.try_convert(x)
      if o.nil?
        raise ArgumentError, "Expected to receive something that can be converted to an #{self.class}, but got: #{x.inspect}."
      else
        return o
      end
    end

    # Tests whether a given pattern is a valid template pattern.
    # @example
    #   URITemplate::RFC6570.valid? 'foo' #=> true
    #   URITemplate::RFC6570.valid? '{foo}' #=> true
    #   URITemplate::RFC6570.valid? '{foo' #=> false
    def valid?(pattern)
      URI === pattern
    end

  end

  extend ClassMethods

  attr_reader :options

  # @param pattern_or_tokens [String,Array] either a pattern as String or an Array of tokens
  # @param options [Hash] some options
  # @option :lazy [true,false] If true the pattern will be parsed on first access, this also means that syntax errors will not be detected unless accessed.
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

  # @method expand(variables = {})
  # Expands the template with the given variables.
  # The expansion should be compatible to uritemplate spec draft 7 ( http://tools.ietf.org/html/draft-gregorio-uritemplate-07 ).
  # @note
  #   All keys of the supplied hash should be strings as anything else won't be recognised.
  # @note
  #   There are neither default values for variables nor will anything be raised if a variable is missing. Please read the spec if you want to know how undefined variables are handled.
  # @example
  #   URITemplate::RFC6570.new('{foo}').expand('foo'=>'bar') #=> 'bar'
  #   URITemplate::RFC6570.new('{?args*}').expand('args'=>{'key'=>'value'}) #=> '?key=value'
  #   URITemplate::RFC6570.new('{undef}').expand() #=> ''
  #
  # @param variables [Hash]
  # @return String

  # Compiles this template into a regular expression which can be used to test whether a given uri matches this template. This template is also used for {#===}.
  #
  # @example
  #   tpl = URITemplate::RFC6570.new('/foo/{bar}/')
  #   regex = tpl.to_r
  #   regex === '/foo/baz/' #=> true
  #   regex === '/foz/baz/' #=> false
  # 
  # @return Regexp
  def to_r
    @regexp ||= begin
      source = tokens.map(&:to_r_source)
      source.unshift('\A')
      source.push('\z')
      Regexp.new( source.join, Utils::KCODE_UTF8)
    end
  end

  # Extracts variables from a uri ( given as string ) or an instance of MatchData ( which was matched by the regexp of this template.
  # The actual result depends on the value of post_processing.
  # This argument specifies whether pair arrays should be converted to hashes.
  # 
  # @example Default Processing
  #   URITemplate::RFC6570.new('{var}').extract('value') #=> {'var'=>'value'}
  #   URITemplate::RFC6570.new('{&args*}').extract('&a=1&b=2') #=> {'args'=>{'a'=>'1','b'=>'2'}}
  #   URITemplate::RFC6570.new('{&arg,arg}').extract('&arg=1&arg=2') #=> {'arg'=>'2'}
  #
  # @example No Processing
  #   URITemplate::RFC6570.new('{var}').extract('value', URITemplate::RFC6570::NO_PROCESSING) #=> [['var','value']]
  #   URITemplate::RFC6570.new('{&args*}').extract('&a=1&b=2', URITemplate::RFC6570::NO_PROCESSING) #=> [['args',[['a','1'],['b','2']]]]
  #   URITemplate::RFC6570.new('{&arg,arg}').extract('&arg=1&arg=2', URITemplate::RFC6570::NO_PROCESSING) #=> [['arg','1'],['arg','2']]
  #
  # @raise Encoding::InvalidByteSequenceError when the given uri was not properly encoded.
  # @raise Encoding::UndefinedConversionError when the given uri could not be converted to utf-8.
  # @raise Encoding::CompatibilityError when the given uri could not be converted to utf-8.
  #
  # @param uri_or_match [String,MatchData] Uri_or_MatchData A uri or a matchdata from which the variables should be extracted.
  # @param post_processing [Array] Processing Specifies which processing should be done.
  # 
  # @note
  #   Don't expect that an extraction can fully recover the expanded variables. Extract rather generates a variable list which should expand to the uri from which it were extracted. In general the following equation should hold true:
  #     a_tpl.expand( a_tpl.extract( an_uri ) ) == an_uri
  #
  # @example Extraction cruces
  #   two_lists = URITemplate::RFC6570.new('{listA*,listB*}')
  #   uri = two_lists.expand('listA'=>[1,2],'listB'=>[3,4]) #=> "1,2,3,4"
  #   variables = two_lists.extract( uri ) #=> {'listA'=>["1","2","3","4"],'listB'=>nil}
  #   # However, like said in the note:
  #   two_lists.expand( variables ) == uri #=> true
  #
  # @note
  #   The current implementation drops duplicated variables instead of checking them.
  #   
  #   
  def extract(uri_or_match, post_processing = DEFAULT_PROCESSING )
    if uri_or_match.kind_of? String
      m = self.to_r.match(uri_or_match)
    elsif uri_or_match.kind_of?(MatchData)
      if uri_or_match.respond_to?(:regexp) and uri_or_match.regexp != self.to_r
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
      result = extract_matchdata(m, post_processing)
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

  # Compares two template patterns.
  def ==(o)
    this, other, this_converted, _ = URITemplate.coerce( self, o )
    if this_converted
      return this == other
    end
    return this.pattern == other.pattern
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

  # The type of this template.
  #
  # @example
  #   tpl1 = URITemplate::RFC6570.new('/foo')
  #   tpl2 = URITemplate.new( tpl1.pattern, tpl1.type )
  #   tpl1 == tpl2 #=> true
  #
  # @see {URITemplate#type}
  def type
    self.class::TYPE
  end

  # Returns the level of this template according to the draft ( http://tools.ietf.org/html/draft-gregorio-uritemplate-07#section-1.2 ). Higher level means higher complexity.
  # Basically this is defined as:
  # 
  # * Level 1: no operators, one variable per expansion, no variable modifiers
  # * Level 2: '+' and '#' operators, one variable per expansion, no variable modifiers
  # * Level 3: all operators, multiple variables per expansion, no variable modifiers
  # * Level 4: all operators, multiple variables per expansion, all variable modifiers
  #
  # @example
  #   URITemplate::RFC6570.new('/foo/').level #=> 1
  #   URITemplate::RFC6570.new('/foo{bar}').level #=> 1
  #   URITemplate::RFC6570.new('/foo{#bar}').level #=> 2
  #   URITemplate::RFC6570.new('/foo{.bar}').level #=> 3
  #   URITemplate::RFC6570.new('/foo{bar,baz}').level #=> 3
  #   URITemplate::RFC6570.new('/foo{bar:20}').level #=> 4
  #   URITemplate::RFC6570.new('/foo{bar*}').level #=> 4
  #
  # Templates of lower levels might be convertible to other formats while templates of higher levels might be incompatible. Level 1 for example should be convertible to any other format since it just contains simple expansions.
  #
  def level
    tokens.map(&:level).max
  end

  # Tries to concatenate two templates, as if they were path segments.
  # Removes double slashes or insert one if they are missing.
  #
  # @example
  #   tpl = URITemplate::RFC6570.new('/xy/')
  #   (tpl / '/z/' ).pattern #=> '/xy/z/'
  #   (tpl / 'z/' ).pattern #=> '/xy/z/'
  #   (tpl / '{/z}' ).pattern #=> '/xy{/z}'
  #   (tpl / 'a' / 'b' ).pattern #=> '/xy/a/b'
  #
  def /(o)
    this, other, this_converted, _ = URITemplate.coerce( self, o )
    if this_converted
      return this / other
    end
    klass = self.class
    if other.absolute?
      raise ArgumentError, "Expected to receive a relative template but got an absoulte one: #{other.inspect}. If you think this is a bug, please report it."
    end

    if other.pattern == ''
      return self
    end
    # Merge!
    # Analyze the last token of this an the first token of the next and try to merge them
    if self.tokens.last.kind_of?(klass::Literal)
      if self.tokens.last.string[-1] == SLASH # the last token ends with an /
        if other.tokens.first.kind_of? klass::Literal
          # both seems to be paths, merge them!
          if other.tokens.first.string[0] == SLASH
            # strip one '/'
            return self.class.new( self.tokens[0..-2] + [ klass::Literal.new(self.tokens.last.string + other.tokens.first.string[1..-1]) ] + other.tokens[1..-1] )
          else
            # no problem, but we can merge them
            return self.class.new( self.tokens[0..-2] + [ klass::Literal.new(self.tokens.last.string + other.tokens.first.string) ] + other.tokens[1..-1] )
          end
        elsif other.tokens.first.kind_of? klass::Expression::Path
          # this will automatically insert '/'
          # so we can strip one '/'
          return self.class.new( self.tokens[0..-2] + [ klass::Literal.new(self.tokens.last.string[0..-2]) ] + other.tokens )
        end
      elsif other.tokens.first.kind_of? klass::Literal
        # okay, this template does not end with /, but the next starts with a literal => merge them!
        if other.tokens.first.string[0] == SLASH
          return self.class.new( self.tokens[0..-2] + [ klass::Literal.new(self.tokens.last.string + other.tokens.first.string)] + other.tokens[1..-1] )
        else
          return self.class.new( self.tokens[0..-2] + [ klass::Literal.new(self.tokens.last.string + '/' + other.tokens.first.string)] + other.tokens[1..-1] )
        end
      end
    end

    if other.tokens.first.kind_of?(klass::Literal)
      if other.tokens.first.string[0] == SLASH
        return self.class.new( self.tokens + other.tokens )
      else
        return self.class.new( self.tokens + [ klass::Literal.new('/' + other.tokens.first.string)]+ other.tokens[1..-1] )
      end
    elsif other.tokens.first.kind_of?(klass::Expression::Path)
      return self.class.new( self.tokens + other.tokens )
    else
      return self.class.new( self.tokens + [ klass::Literal.new('/')] + other.tokens )
    end
  end

  # Returns an array containing a the template tokens.
  def tokens
    @tokens ||= tokenize!
  end

protected
  # @private
  def tokenize!
    self.class::Tokenizer.new(pattern, self.class::OPERATORS).to_a
  end

  def arity
    @arity ||= tokens.inject(0){|a,t| a + t.arity }
  end

  # @private
  def extract_matchdata(matchdata, post_processing)
    bc = 1
    vars = []
    tokens.each{|part|
      next if part.literal?
      i = 0
      pa = part.arity
      while i < pa
        vars << part.extract(i, matchdata[bc])
        bc += 1
        i += 1
      end
    }
    if post_processing.include? :convert_result
      if post_processing.include? :convert_values
        vars.flatten!(1)
        return Hash[*vars.map!{|k,v| [k,Utils.pair_array_to_hash(v)] }.flatten(1) ]
      else
        vars.flatten!(2)
        return Hash[*vars]
      end
    else
      if post_processing.include? :convert_value
        vars.flatten!(1)
        return vars.collect{|k,v| [k,Utils.pair_array_to_hash(v)] }
      else
        return vars.flatten(1)
      end
    end
  end

end
