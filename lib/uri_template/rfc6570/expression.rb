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

require 'uri_template/rfc6570'

class URITemplate::RFC6570

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
            result.push( self_pair(var, vars[var], max_length) )
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
          value = self.class::CHARACTER_CLASS[:class_with_comma] + ( (max_length > 0) ? '{0,'+max_length.to_s+'}' : '*' )
          if expand
            #if self.class::PAIR_IF_EMPTY
            pair = "#{self.class::CHARACTER_CLASS[:class]}+?#{Regexp.escape(self.class::PAIR_CONNECTOR)}#{value}"

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
            value = self.class::CHARACTER_CLASS[:class] + ( (max_length > 0) ? '{0,'+max_length.to_s+'}' : '*' )

            pair = "(?:#{self.class::CHARACTER_CLASS[:class]}+?#{Regexp.escape(self.class::PAIR_CONNECTOR)})?#{value}"

            value = "#{pair}(?:#{Regexp.escape(self.class::SEPARATOR)}#{pair})*"
          elsif last
            # the last will slurp lists
            value = "#{self.class::CHARACTER_CLASS[:class_with_comma]}#{(max_length > 0)?'{0,'+max_length.to_s+'}':'*?'}"
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
            pair = "(#{self::CHARACTER_CLASS[:class]}+?)#{Regexp.escape(self::PAIR_CONNECTOR)}(#{value})"
          else
            pair = "(#{self::CHARACTER_CLASS[:class]}+?#{Regexp.escape(self::PAIR_CONNECTOR)})?(#{value})"
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
      elsif hsh.none? && !self.class::NAMED
        []
      else
        [ (self.class::NAMED ? escape(name)+self.class::PAIR_CONNECTOR : '' ) + hsh.map{|key,value| escape(key)+self.class::LIST_CONNECTOR+escape(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end

    def transform_array(name, ary, expand , max_length)
      if expand
        self.class::NAMED ? ary.map{|value| pair(name,value) } : ary.map{|value| escape(value) }
      elsif ary.none? && !self.class::NAMED
        []
      else
        [ (self.class::NAMED ? escape(name)+self.class::PAIR_CONNECTOR : '' ) + ary.map{|value| escape(value) }.join(self.class::LIST_CONNECTOR) ]
      end
    end

  public

    class Named < self

      alias self_pair pair

    end

    class Unnamed < self

      def self_pair(_, value, max_length = 0)
        cut( escape(value), max_length )
      end

    end

    class Basic < Unnamed

    end

    class Reserved < Unnamed

      CHARACTER_CLASS = CHARACTER_CLASSES[:unreserved_reserved_pct]
      OPERATOR = '+'.freeze
      BASE_LEVEL = 2

      def escape(x)
        Utils.escape_uri(Utils.object_to_param(x))
      end

      def unescape(x)
        Utils.unescape_uri(x)
      end

      def scheme?
        true
      end

      def host?
        true
      end

    end

    class Fragment < Unnamed

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

    class Label < Unnamed

      SEPARATOR = '.'.freeze
      PREFIX = '.'.freeze
      OPERATOR = '.'.freeze
      BASE_LEVEL = 3

    end

    class Path < Unnamed

      SEPARATOR = '/'.freeze
      PREFIX = '/'.freeze
      OPERATOR = '/'.freeze
      BASE_LEVEL = 3

      def starts_with_slash?
        true
      end

    end

    class PathParameters < Named

      SEPARATOR = ';'.freeze
      PREFIX = ';'.freeze
      NAMED = true
      PAIR_IF_EMPTY = false
      OPERATOR = ';'.freeze
      BASE_LEVEL = 3

    end

    class FormQuery < Named

      SEPARATOR = '&'.freeze
      PREFIX = '?'.freeze
      NAMED = true
      OPERATOR = '?'.freeze
      BASE_LEVEL = 3

    end

    class FormQueryContinuation < Named

      SEPARATOR = '&'.freeze
      PREFIX = '&'.freeze
      NAMED = true
      OPERATOR = '&'.freeze
      BASE_LEVEL = 3

    end

  end

  # @private
  OPERATORS = {
    ''  => Expression::Basic,
    '+' => Expression::Reserved,
    '#' => Expression::Fragment,
    '.' => Expression::Label,
    '/' => Expression::Path,
    ';' => Expression::PathParameters,
    '?' => Expression::FormQuery,
    '&' => Expression::FormQueryContinuation
  }

end