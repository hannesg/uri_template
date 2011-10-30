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
  
  # A base class for all errors which will be raised upon invalid syntax.
  module Invalid
  end
  
  # A base module for all implementation of a template section.
  # Sections are a custom extension to the uri template spec.
  # A template section ( in comparison to a template ) can be unbounded on its ends. Therefore they don't necessarily match a whole uri and can be concatenated.
  module Section
  
    include URITemplate
  
    # Same as {URITemplate.new} but for sections
    def self.new(*args)
      klass, rest = URITemplate.resolve_class(*args)
      return klass::Section.new(*rest)
    end
    
    # @abstract
    # Concatenates this section with an other section.
    def >>(other)
      raise "Please implement #>> on #{self.class.inspect}"
    end
    
    # @abstract
    # Is this section left bounded?
    def left_bound?
      raise "Please implement #left_bound? on #{self.class.inspect}"
    end
  
    # @abstract
    # Is this section right bounded?
    def right_bound?
      raise "Please implement #right_bound? on #{self.class.inspect}"
    end
  
  end
  
  # @abstract
  # Expands this uri template with the given variables.
  # The variables should be converted to strings using {Utils#object_to_param}.
  # @raise Unconvertable if a variable could not be converted.
  def expand(variables={})
    raise "Please implement #expand on #{self.class.inspect}"
  end

end
