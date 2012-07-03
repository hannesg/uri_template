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

require 'forwardable'

require 'uri_template'
require 'uri_template/utils'

# A colon based template denotes variables with a colon.
# This template type is realy basic but having just on template type was a bit weird.
module URITemplate

class Colon

  include URITemplate

  VAR = /(?:\{:([a-z]+)\}|:([a-z]+)(?![a-z]))/u

  class Token

    class Variable < self

      include URITemplate::Expression

      attr_reader :name

      def initialize(name)
        @name = name
        @variables = [name]
      end

      def expand(vars)
        return Utils.escape_url(Utils.object_to_param(vars[@name]))
      end

      def to_r
        return ['([^/]*?)'].join
      end

    end

    class Static < self

      include URITemplate::Literal

      def initialize(str)
        @string = str
      end

      def expand(_)
        return @string
      end

      def to_r
        return Regexp.escape(@string)
      end

    end

  end

  attr_reader :pattern

  # Tries to convert the value into a colon-template.
  # @example
  #   URITemplate::Colon.try_convert('/foo/:bar/').pattern #=> '/foo/:bar/'
  #   URITemplate::Colon.try_convert(URITemplate::Draft7.new('/foo/{bar}/')).pattern #=> '/foo/{:bar}/'
  def self.try_convert(x)
    if x.kind_of? String
      return new(x)
    elsif x.kind_of? self
      return x
    elsif x.kind_of? URITemplate::Draft7 and x.level == 1
      return new( x.pattern.gsub(/\{(.*?)\}/u){ "{:#{$1}}" } )
    else
      return nil
    end
  end

  def initialize(pattern)
    @pattern = pattern
  end

  # Extracts variables from an uri.
  #
  # @param uri [String]
  # @return nil,Hash
  def extract(uri)
    md = self.to_r.match(uri)
    return nil unless md
    return Hash[ *self.variables.each_with_index.map{|v,i|
      [v, Utils.unescape_url(md[i+1])]
    }.flatten(1) ]
  end

  def type
    :colon
  end

  def to_r
    @regexp ||= Regexp.new('\A' + tokens.map(&:to_r).join + '\z', Utils::KCODE_UTF8)
  end

  def tokens
    @tokens ||= tokenize!
  end

  # Tries to concatenate two templates, as if they were path segments.
  # Removes double slashes or inserts one if they are missing.
  #
  # @example
  #   tpl = URITemplate::Colon.new('/xy/')
  #   (tpl / '/z/' ).pattern #=> '/xy/z/'
  #   (tpl / 'z/' ).pattern #=> '/xy/z/'
  #   (tpl / ':z' ).pattern #=> '/xy/:z'
  #   (tpl / ':a' / 'b' ).pattern #=> '/xy/:a/b'
  #
  def /(o)
    this, other, this_converted, other_converted = URITemplate.coerce( self, o )
    if this_converted
      return this / other
    end
    return self.class.new( File.join( this.pattern, other.pattern ) )
  end

protected

  def tokenize!
    RegexpEnumerator.new(VAR).each(@pattern).map{|x|
      if x.kind_of? String
        Token::Static.new(x)
      else
        # TODO: when rubinius supports ambigious names this could be replaced with x['name'] *sigh*
        Token::Variable.new(x[1] || x[2])
      end
    }.to_a
  end

end
end
