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

require 'uri_template'
require 'json'



def expand_to( variables,expected )
  return URITemplate::ExpansionMatcher.new(variables, expected)
end


describe URITemplate::RFC6570 do

  describe "( in the examples from uritemplate-test " do

    f = File.new(File.expand_path('uritemplate-test/spec-examples.json', File.dirname(__FILE__)))
    data = JSON.load( f.read )
    data.each do |label, spec|
      describe "- #{label} )" do
        variables = spec['variables']

        spec['testcases'].each do | template, results |

          it " should expand #{template} correctly " do
            results = Array(results)
            t = URITemplate::RFC6570.new( template )
            t.should expand_to( variables, results )
          end

          it " should extract the variables from #{template} correctly " do
            result = Array(results).first
            t = URITemplate::RFC6570.new( template )
            t.should expand_to( t.extract(result) , result )
          end

        end

      end
    end

  end

end

