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

class URITemplate::RFC6570::Expression::Named < URITemplate::RFC6570::Expression

  alias self_pair pair

  def to_r_source
    source = regex_builder
    source.group do
      source.escaped_prefix
      first = true
      @variable_specs.each do | var, expand , max_length |
        if expand
          source.group(true) do
            source.separated_list(first) do
              source.character_class('+')
                .escaped_pair_connector
                .character_class_with_comma(max_length)
            end
          end
        else
          source.group do
            source.escaped_separator unless first
            source << Regexp.escape(var)
            source.group(true) do
              source.escaped_pair_connector
              source.character_class_with_comma(max_length)
              source << '|' unless self.class::PAIR_IF_EMPTY
            end
          end.length('?')
        end
        first = false
      end
    end.length('?')
    return source.join
  end

  def extract(position,matched)
    name, expand, max_length = @variable_specs[position]
    if matched.nil?
      return [[ name , matched ]]
    end
    if expand
      it = URITemplate::RegexpEnumerator.new(self.class.hash_extractor(max_length))
      splitted = it.each(matched)
        .reject{|match| match[1].nil? }
        .map do |match|
          [ decode(match[1]), decode(match[2], false) ]
        end
      result = URITemplate::Utils.pair_array_to_hash2( splitted )
      if result.size == 1 && result[0][0] == name
        return result
      else
        return [ [ name , result ] ]
      end
    end

    return [ [ name, decode( matched[1..-1] ) ] ]
  end

end