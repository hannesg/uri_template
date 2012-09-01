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

  # @private
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

  # This should make it possible to do basic analysis independently from the concrete type.
  module Token

    def size
      variables.size
    end

  end

  # A module which all literal tokens should include.
  module Literal

    include Token

    attr_reader :string

    def literal?
      true
    end

    def expression?
      false
    end

    def variables
      []
    end

    def size
      0
    end

    def expand(*_)
      return string
    end

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

  end

  autoload :Utils, 'uri_template/utils'
  autoload :Draft7, 'uri_template/draft7'
  autoload :RFC6570, 'uri_template/rfc6570'
  autoload :Colon, 'uri_template/colon'

  # A hash with all available implementations.
  # Currently the only implementation is :draft7. But there also aliases :default and :latest available. This should make it possible to add newer specs later.
  # @see resolve_class
  VERSIONS = {
    :draft7 => :Draft7,
    :rfc6570 => :RFC6570,
    :default => :Draft7,
    :colon => :Colon,
    :latest => :RFC6570
  }

  # Looks up which implementation to use.
  # Extracts all symbols from args and looks up the first in {VERSIONS}.
  #
  # @return Array an array of the class to use and the unused parameters.
  # @example
  #   URITemplate.resolve_class() #=> [ URITemplate::Draft7, [] ]
  #   URITemplate.resolve_class(:draft7) #=> [ URITemplate::Draft7, [] ]
  #   URITemplate.resolve_class("template",:draft7) #=> [ URITemplate::Draft7, ["template"] ]
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
  #   tpl = URITemplate.new(:draft7,'{x}') # a new template using the draft7 implementation
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
  #   URITemplate.coerce( URITemplate.new(:draft7,'{x}'), '{y}' ) #=> [URITemplate.new(:draft7,'{x}'), URITemplate.new(:draft7,'{y}'), false, true]
  #   URITemplate.coerce( '{y}', URITemplate.new(:draft7,'{x}') ) #=> [URITemplate.new(:draft7,'{y}'), URITemplate.new(:draft7,'{x}'), true, false]
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
  # @param variables Hash
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

  # Returns whether this uri-template matches the host name
  #
  # @example
  #   URITemplate.new('/foo').host? #=> false
  #   URITemplate.new('//example.com/foo').host? #=> true
  #   URITemplate.new('//{host}/foo').host? #=> true
  #   URITemplate.new('http://example.com/foo').host? #=> true
  #
  def host?
    return @host unless @host.nil?
    read_chars = ""
    tokens.each do |token|
      if token.expression?
        read_chars << "x"
      elsif token.literal?
        read_chars << token.string
      end
      if read_chars =~ /^([a-z]+:)?\/\//i
        return @host = true
      elsif read_chars =~ /(^|[^:\/])\/(?!\/)/
        return @host = false
      end
    end
    return @host = false
  end

  # Returns whether this uri-template matches the proto
  #
  # @example
  #   URITemplate.new('/foo').proto? #=> false
  #   URITemplate.new('//example.com/foo').proto? #=> false
  #   URITemplate.new('http://example.com/foo').proto? #=> true
  #   URITemplate.new('{proto}://example.com/foo').proto? #=> true
  #
  def proto?
    return @proto unless @proto.nil?
    read_chars = ""
    tokens.each do |token|
      if token.expression?
        read_chars << "x"
      elsif token.literal?
        read_chars << token.string
      end
      if read_chars =~ /^[a-z]+:\/\//i
        return @proto = true
      elsif read_chars =~ /(^|[^:\/])\/(?!\/)/
        return @proto = false
      end
    end

    return @proto = false
  end


  alias absolute? host?

  # Opposite of {#absolute?}
  def relative?
    !absolute?
  end

end
