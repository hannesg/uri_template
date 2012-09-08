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

# A base module for all implementations of a uri template.
module URITemplate

  # @api private
  # Should we use \u.... or \x.. in regexps?
  SUPPORTS_UNICODE_CHARS = begin
                             if "string".respond_to? :encoding
                               rx = eval('Regexp.compile("\u0020")')
                               !!(rx =~ " ")
                             else
                               rx = eval('/\u0020/')
                               !!(rx =~ " ")
                             end
                           rescue SyntaxError
                             false
                           end

  # @api private
  # Should we use quantifier modifier in regexps?
  SUPPORTS_QUANTIFIER_MODIFIER =  begin
                                    /a+?/.match('aa').to_s == 1
                                  rescue SyntaxError
                                    false
                                  end

  # @api private
  QUANTIFY_POSSESSIVE = SUPPORTS_QUANTIFIER_MODIFIER ? '+' : ''

  # @api private
  SCHEME_REGEX = /\A[a-z]+:/i.freeze

  # @api private
  HOST_REGEX = /\A(?:[a-z]+:)?\/\/[^\/]+/i.freeze

  # @api private
  URI_SPLIT = /\A(?:([a-z]+):)?#{QUANTIFY_POSSESSIVE}(?:\/\/)?#{QUANTIFY_POSSESSIVE}([^\/]+)?/i.freeze

  # This should make it possible to do basic analysis independently from the concrete type.
  module Token

    EMPTY_ARRAY = [].freeze

    def variables
      EMPTY_ARRAY
    end

    # Number of variables in this token
    def size
      variables.size
    end

    def starts_with_slash?
      false
    end

    def ends_with_slash?
      false
    end

  end

  # A module which all literal tokens should include.
  module Literal

    include Token

    SLASH = ?/

    attr_reader :string

    def literal?
      true
    end

    def expression?
      false
    end

    def size
      0
    end

    def expand(_)
      return string
    end

    def starts_with_slash?
      string[0] == SLASH
    end

    def ends_with_slash?
      string[-1] == SLASH
    end

    alias to_s string

  end

  # A module which all non-literal tokens should include.
  module Expression

    include Token

    attr_reader :variables

    def literal?
      false
    end

    def expression?
      true
    end

    def scheme?
      false
    end

    def host?
      false
    end

    def expand(variables)
      raise "Please implement #expand(variables) on #{self.class.inspect}."
    end

    def to_s
      raise "Please implement #to_s on #{self.class.inspect}."
    end

  end

  autoload :Utils, 'uri_template/utils'
  autoload :RFC6570, 'uri_template/rfc6570'
  autoload :Colon, 'uri_template/colon'

  # A hash with all available implementations.
  # @see resolve_class
  VERSIONS = {
    :rfc6570 => :RFC6570,
    :default => :RFC6570,
    :colon => :Colon,
    :latest => :RFC6570
  }

  # Looks up which implementation to use.
  # Extracts all symbols from args and looks up the first in {VERSIONS}.
  #
  # @return Array an array of the class to use and the unused parameters.
  # 
  # @example
  #   URITemplate.resolve_class() #=> [ URITemplate::RFC6570, [] ]
  #   URITemplate.resolve_class(:colon) #=> [ URITemplate::Colon, [] ]
  #   URITemplate.resolve_class("template",:rfc6570) #=> [ URITemplate::RFC6570, ["template"] ]
  # 
  # @raise ArgumentError when no class was found.
  #
  def self.resolve_class(*args)
    symbols, rest = args.partition{|x| x.kind_of? Symbol }
    version = symbols.fetch(0, :default)
    raise ArgumentError, "Unknown template version #{version.inspect}, defined versions: #{VERSIONS.keys.inspect}" unless VERSIONS.key?(version)
    return self.const_get(VERSIONS[version]), rest
  end

  # Creates an uri template using an implementation.
  # The args should at least contain a pattern string.
  # Symbols in the args are used to determine the actual implementation.
  #
  # @example
  #   tpl = URITemplate.new('{x}') # a new template using the default implementation
  #   tpl.expand('x'=>'y') #=> 'y'
  #
  # @example
  #   tpl = URITemplate.new(:colon,'/:x') # a new template using the colon implementation
  # 
  def self.new(*args)
    klass, rest = resolve_class(*args)
    return klass.new(*rest)
  end

  # Tries to convert the given argument into an {URITemplate}.
  # Returns nil if this fails.
  #
  # @return [nil|{URITemplate}]
  def self.try_convert(x)
    if x.kind_of? URITemplate
      return x
    elsif x.kind_of? String
      return URITemplate.new(x)
    else
      return nil
    end
  end

  # Same as {.try_convert} but raises an ArgumentError when the given argument could not be converted.
  # 
  # @raise ArgumentError if the argument is unconvertable
  # @return {URITemplate}
  def self.convert(x)
    o = self.try_convert(x)
    if o.nil?
      raise ArgumentError, "Expected to receive something that can be converted to an URITemplate, but got #{x.inspect}"
    end
    return o
  end

  # Tries to coerce two URITemplates into a common representation.
  # Returns an array with two {URITemplate}s and two booleans indicating which of the two were converted or raises an ArgumentError.
  #
  # @example
  #   URITemplate.coerce( URITemplate.new(:rfc6570,'{x}'), '{y}' ) #=> [URITemplate.new(:rfc6570,'{x}'), URITemplate.new(:rfc6570,'{y}'), false, true]
  #   URITemplate.coerce( '{y}', URITemplate.new(:rfc6570,'{x}') ) #=> [URITemplate.new(:rfc6570,'{y}'), URITemplate.new(:rfc6570,'{x}'), true, false]
  def self.coerce(a,b)
    if a.kind_of? URITemplate
      if a.class == b.class
        return [a,b,false,false]
      end
      b_as_a = a.class.try_convert(b)
      if b_as_a
        return [a,b_as_a,false,true]
      end
    end
    if b.kind_of? URITemplate
      a_as_b = b.class.try_convert(a)
      if a_as_b
        return [a_as_b, b, true, false]
      end
    end
    bc = self.try_convert(b)
    if bc.kind_of? URITemplate
      a_as_b = bc.class.try_convert(a)
      if a_as_b
        return [a_as_b, bc, true, true]
      end
    end
    raise ArgumentError, "Expected at least on URITemplate, but got #{a.inspect} and #{b.inspect}" unless a.kind_of? URITemplate or b.kind_of? URITemplate
    raise ArgumentError, "Cannot coerce #{a.inspect} and #{b.inspect} into a common representation."
  end

  # Applies a method to a URITemplate with another URITemplate as argument.
  # This is a useful shorthand since both URITemplates are automatically coerced.
  #
  # @example
  #   tpl = URITemplate.new('foo')
  #   URITemplate.apply( tpl, :/, 'bar' ).pattern #=> 'foo/bar'
  #   URITemplate.apply( 'baz', :/, tpl ).pattern #=> 'baz/foo'
  #   URITemplate.apply( 'bla', :/, 'blub' ).pattern #=> 'bla/blub'
  # 
  def self.apply(a, method, b, *args)
    a,b,_,_ = self.coerce(a,b)
    a.send(method,b,*args)
  end

  # A base class for all errors which will be raised upon invalid syntax.
  module Invalid
  end

  # A base class for all errors which will be raised when a variable value
  # is not allowed for a certain expansion.
  module InvalidValue
  end

  # Expands this uri template with the given variables.
  # The variables should be converted to strings using {Utils#object_to_param}.
  #
  # The keys in the variables hash are converted to
  # strings in order to support the Ruby 1.9 hash syntax.
  #
  # @raise {Unconvertable} if a variable could not be converted to a string.
  # @param variables [Hash]
  # @return String
  def expand(variables = {})
    raise ArgumentError, "Expected something that returns to :map, but got: #{variables.inspect}" unless variables.respond_to? :map

    # Stringify variables
    variables = Hash[variables.map{ |k, v| [k.to_s, v] }]

    tokens.map{|part|
      part.expand(variables)
    }.join
  end

  # @abstract
  # Returns the type of this template. The type is a symbol which can be used in {.resolve_class} to resolve the type of this template.
  def type
    raise "Please implement #type on #{self.class.inspect}."
  end

  # @abstract
  # Returns the tokens of this templates. Tokens should include either {Literal} or {Expression}.
  def tokens
    raise "Please implement #tokens on #{self.class.inspect}."
  end

  # Returns an array containing all variables. Repeated variables are ignored. The concrete order of the variables may change.
  # @example
  #   URITemplate.new('{foo}{bar}{baz}').variables #=> ['foo','bar','baz']
  #   URITemplate.new('{a}{c}{a}{b}').variables #=> ['a','c','b']
  #
  # @return Array
  def variables
    @variables ||= tokens.select(&:expression?).map(&:variables).flatten.uniq
  end

  # Returns the number of static characters in this template.
  # This method is useful for routing, since it's often pointful to use the url with fewer variable characters.
  # For example 'static' and 'sta\\{var\\}' both match 'static', but in most cases 'static' should be prefered over 'sta\\{var\\}' since it's more specific.
  #
  # @example
  #   URITemplate.new('/xy/').static_characters #=> 4
  #   URITemplate.new('{foo}').static_characters #=> 0
  #   URITemplate.new('a{foo}b').static_characters #=> 2
  #
  # @return Numeric
  def static_characters
    @static_characters ||= tokens.select(&:literal?).map{|t| t.string.size }.inject(0,:+)
  end

  # Returns whether this uri-template includes a host name
  #
  # This method is usefull to check wheter this template will generate 
  # or match a uri with a host.
  #
  # @see #scheme?
  #
  # @example
  #   URITemplate.new('/foo').host? #=> false
  #   URITemplate.new('//example.com/foo').host? #=> true
  #   URITemplate.new('//{host}/foo').host? #=> true
  #   URITemplate.new('http://example.com/foo').host? #=> true
  #   URITemplate.new('{scheme}://example.com/foo').host? #=> true
  #
  def host?
    return scheme_and_host[1]
  end

  # Returns whether this uri-template includes a scheme
  #
  # This method is usefull to check wheter this template will generate 
  # or match a uri with a scheme.
  # 
  # @see #host?
  #
  # @example
  #   URITemplate.new('/foo').scheme? #=> false
  #   URITemplate.new('//example.com/foo').scheme? #=> false
  #   URITemplate.new('http://example.com/foo').scheme? #=> true
  #   URITemplate.new('{scheme}://example.com/foo').scheme? #=> true
  #
  def scheme?
    return scheme_and_host[0]
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
    if other.host? or other.scheme?
      raise ArgumentError, "Expected to receive a relative template but got an absoulte one: #{other.inspect}. If you think this is a bug, please report it."
    end

    return self if other.tokens.none?
    return other if self.tokens.none?

    if self.tokens.last.ends_with_slash? and other.tokens.first.starts_with_slash?
      if self.tokens.last.literal?
        return self.class.new( (self.tokens[0..-2] + [ self.tokens.last.to_s[0..-2] ] + other.tokens).join )
      elsif other.tokens.first.literal?
        return self.class.new( (self.tokens + [ other.tokens.first.to_s[1..-1] ] + other.tokens[1..-1]).join )
      else
        raise ArgumentError, "Cannot remove double slashes from #{self.inspect} and #{other.inspect}."
      end
    elsif !self.tokens.last.ends_with_slash? and !other.tokens.first.starts_with_slash?
      return self.class.new( (self.tokens + ['/'] + other.tokens).join)
    end
    return self.class.new( (self.tokens + other.tokens).join )
  end

  # @api private
  def scheme_and_host
    return @scheme_and_host if @scheme_and_host
    read_chars = ""
    @scheme_and_host = [false,false]
    tokens.each do |token|
      if token.expression?
        read_chars << "x"
        if token.scheme?
          read_chars << ':'
        end
        if token.host?
          read_chars << '//'
        end
        read_chars << "x"
      elsif token.literal?
        read_chars << token.string
      end
      if read_chars =~ SCHEME_REGEX
        @scheme_and_host = [true, true]
        break
      elsif read_chars =~ HOST_REGEX
        @scheme_and_host[1] = true
        break
      elsif read_chars =~ /(^|[^:\/])\/(?!\/)/
        break
      end
    end
    return @scheme_and_host
  end

  private :scheme_and_host

  alias absolute? host?

  # Opposite of {#absolute?}
  def relative?
    !absolute?
  end

end
