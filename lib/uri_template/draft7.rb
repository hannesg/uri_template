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


# A uri template which should comply with the uri template spec draft 7 ( http://tools.ietf.org/html/draft-gregorio-uritemplate-07 ).
# This class is here for backward compatibility. There is already a newer draft of the spec and an rfc.
class URITemplate::Draft7 < URITemplate::RFC6570

  TYPE = :draft7

  CHARACTER_CLASSES = URITemplate::RFC6570::CHARACTER_CLASSES 

  Utils = URITemplate::Utils

  class Expression < URITemplate::RFC6570::Expression

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
        found_value = false
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
          if match[1]
            found_value = true
            splitted << [ match[1][0..-2], decode(match[2] + rest , false) ]
          else
            splitted << [ match[2] + rest, nil ]
          end
          rest = match.post_match
        end
        if !found_value
          return [ [ name, splitted.map{|n,v| decode(n , false) } ] ]
        else
          return [ [ name, splitted ] ]
        end
      elsif self.class::NAMED
        return [ [ name, decode( matched[1..-1] ) ] ]
      end

      return [ [ name,  decode( matched ) ] ]
    end

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
            pair = "(?:#{CHARACTER_CLASSES[:varname][:class]}#{Regexp.escape(self.class::PAIR_CONNECTOR)})?#{value}"

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

  protected

    def transform_array(name, ary, expand , max_length)
      if expand
        ary.map{|value| escape(value) }
      elsif ary.none?
        []
      else
        [ (self.class::NAMED ? escape(name)+self.class::PAIR_CONNECTOR : '' ) + ary.map{|value| escape(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end

    module ClassMethods

      def hash_extractor(max_length)
        @hash_extractors ||= {}
        @hash_extractors[max_length] ||= begin
          value = "#{self::CHARACTER_CLASS[:class]}#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*?'}"
          pair = "(#{CHARACTER_CLASSES[:varname][:class]}#{Regexp.escape(self::PAIR_CONNECTOR)})?(#{value})"
          source = "\\A#{Regexp.escape(self::SEPARATOR)}?" + pair + "(\\z|#{Regexp.escape(self::SEPARATOR)}(?!#{Regexp.escape(self::SEPARATOR)}))"
          Regexp.new( source , Utils::KCODE_UTF8)
        end
      end

    end

    extend ClassMethods

    class Reserved < self

      CHARACTER_CLASS = URITemplate::RFC6570::CHARACTER_CLASSES[:unreserved_reserved_pct]
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

      CHARACTER_CLASS = URITemplate::RFC6570::CHARACTER_CLASSES[:unreserved_reserved_pct]
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

end
