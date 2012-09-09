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

class URITemplate::RFC6570::Expression::Unnamed < URITemplate::RFC6570::Expression

  def self_pair(_, value, max_length = 0,&block)
    if block
      ev = value.map(&block).join(self.class::LIST_CONNECTOR) 
    else
      ev = escape(value)
    end
    cut( ev, max_length ,&block)
  end

  def to_r_source
    vs = @variable_specs.size - 1
    i = 0
    source = regex_builder
    source.group do
      source.escaped_prefix
      @variable_specs.each do | var, expand , max_length |
        last = (vs == i)
        first = (i == 0)
        if expand
          source.group(true) do
            source.separated_list(first) do
              source.group do
                source.character_class('+').reluctant
                source.escaped_pair_connector
              end.length('?')
              source.character_class(max_length)
            end
          end
        else
          source.escaped_separator unless first
          source.group(true) do
            if last
              source.character_class_with_comma(max_length).reluctant
            else
              source.character_class(max_length)
            end
          end
        end
        i = i+1
      end
    end.length('?')
    return source.join
  end

private

  def after_expand(name, splitted)
    if splitted.none?{|_,b| b }
      return [ [ name, splitted.map{|a,_| a } ] ]
    else
      return [ [ name, splitted ] ]
    end
  end

end