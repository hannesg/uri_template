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

  class RegexBuilder

    def initialize(expression_class)
      @expression_class = expression_class
      @source = []
    end

    def <<(arg)
      @source << arg
      self
    end

    def push(*args)
      @source.push(*args)
      self
    end

    def escaped_pair_connector
      self << Regexp.escape(@expression_class::PAIR_CONNECTOR)
    end

    def escaped_separator
      self << Regexp.escape(@expression_class::SEPARATOR)
    end

    def escaped_prefix
      self << Regexp.escape(@expression_class::PREFIX)
    end

    def join
      return @source.join
    end

    def length(*args)
      self << format_length(*args)
    end

    def character_class_with_comma(max_length=0, min = 0)
      self << @expression_class::CHARACTER_CLASS[:class_with_comma] << format_length(max_length, min)
    end

    def character_class(max_length=0, min = 0)
      self << @expression_class::CHARACTER_CLASS[:class] << format_length(max_length, min)
    end

    def reluctant
      self << '?'
    end

    def group(capture = false)
      self << '('
      self << '?:' unless capture
      yield
      self << ')'
    end

    def negative_lookahead
      self << '(?!'
      yield
      self << ')'
    end

    def lookahead
      self << '(?='
      yield
      self << ')'
    end

    def capture(&block)
      group(true, &block)
    end

    def separated_list(first = true, length = 0, min = 1, &block)
      if first
        yield
        min -= 1
      end
      self.push('(?:').escaped_separator
      yield
      self.push(')').length(length, min)
    end

  private

    def format_length(len, min = 0)
      return len if len.kind_of? String
      return '{'+min.to_s+','+len.to_s+'}' if len.kind_of?(Numeric) and len > 0
      return '*' if min == 0
      return '+' if min == 1
      return '{'+min.to_s+',}'
    end


  end

end