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

# A base module for all implementations of a uri template.
module URITemplate

  autoload :Utils, 'uri_template/utils'
  autoload :Draft7, 'uri_template/draft7'
  
  # A hash with all available implementations.
  # Currently the only implementation is :draft7. But there also aliases :default and :latest available. This should make it possible to add newer specs later.
  # @see resolve_class
  VERSIONS = {
    :draft7 => :Draft7,
    :default => :Draft7,
    :latest => :Draft7
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
  # Returns an array with two {URITemplate}s and two booleans indicating which of the two were converted or raises an {ArgumentError}.
  #
  # @example
  #   URITemplate.coerce( URITemplate.new(:draft7,'{x}'), '{y}' ) #=> [URITemplate.new(:draft7,'{x}'), URITemplate.new(:draft7,'{y}'), false, true]
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
    raise ArgumentError, "Expected at least on URITemplate, but got #{a.inspect} and #{b.inspect}" unless a.kind_of? URITemplate or b.kind_of? URITemplate
    raise ArgumentError, "Cannot coerce #{a.inspect} and #{b.inspect} into a common representation."
  end
  
  # A base class for all errors which will be raised upon invalid syntax.
  module Invalid
  end
  
  # @abstract
  # Expands this uri template with the given variables.
  # The variables should be converted to strings using {Utils#object_to_param}.
  # @raise {Unconvertable} if a variable could not be converted to a string.
  def expand(variables={})
    raise "Please implement #expand on #{self.class.inspect}."
  end
  
  # @abstract
  # Returns the type of this template. The type is a symbol which can be used in {.resolve_class} to resolve the type of this template.
  def type
    raise "Please implement #type on #{self.class.inspect}."
  end

end
