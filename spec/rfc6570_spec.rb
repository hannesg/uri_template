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
#    (c) 2011 - 2012 by Hannes Georg
#

require 'uri_template'

describe URITemplate::RFC6570 do

  ['spec-examples.json', 'extended-tests.json', 'negative-tests.json'].each do |file_name|

  describe "( in the examples from uritemplate-test " do

    f = File.new(File.expand_path(file_name, File.join(File.dirname(__FILE__),'uritemplate-test')))
    data = MultiJson.load( f.read )
    data.each do |label, spec|
      describe "- #{label} )" do
        variables = spec['variables']

        spec['testcases'].each do | template, results |

          # NOTE: this negative test case is not that cool
          if template == '/vars/:var'
            results = "/vars/:var"
          end

          if results == false
 
            it " should say that #{template} is borked" do
              begin
                URITemplate::RFC6570.new(template).expand(variables)
              rescue URITemplate::Invalid, URITemplate::InvalidValue
              else
                fail "expected URITemplate::Invalid or URITemplate::InvalidValue but nothing was raised"
              end
            end

          elsif results.kind_of? String or results.kind_of? Array

            it " should expand #{template} correctly " do
              results = Array(results)
              t = URITemplate::RFC6570.new( template )
              t.should expand_to( variables, results )
            end

            it " should extract the variables from #{template} correctly " do
              result = Array(results).first
              t = URITemplate::RFC6570.new( template )
              t.should expand_to( t.extract(result) , RUBY_VERSION > "1.9" ? result : results )
            end

          else
            warn "Ignoring template #{template}"
          end

        end

      end
    end
  end
  end

  describe "syntax" do

    it "should refuse variables with terminal dots" do
      lambda{ URITemplate::RFC6570.new('{var.}') }.should raise_error(URITemplate::Invalid)
      lambda{ URITemplate::RFC6570.new('{..var.}') }.should raise_error(URITemplate::Invalid)
    end

  end

  describe "expansion" do

    it "should refuse to expand a complex variable with length limit" do

      t = URITemplate::RFC6570.new("{?assoc:10}")
      lambda{ t.expand("assoc"=>{'foo'=>'bar'}) }.should raise_error

    end

    it "should refuse to expand a array variable with length limit" do

      t = URITemplate::RFC6570.new("{?array:10}")
      lambda{ t.expand("array"=>["a","b"]) }.should raise_error

    end

  end

  describe "extraction" do

    it ' should ignore draf7-style lists' do

      t = URITemplate::RFC6570.new("{?list*}")
      t.extract('?a&b&c').should be_nil
      t.should extract_from({'list'=>%w{a b c}}, '?list=a&list=b&list=c')

    end

  end

  describe "conversion" do

    it ' should convert most draft7 templates' do

      URITemplate::RFC6570.try_convert( URITemplate::Draft7.new('{var}') ).should_not be_nil

    end

    it ' should convert simple colon templates' do

      URITemplate::RFC6570.try_convert( URITemplate::Colon.new(':var') ).should_not be_nil

    end

    it ' should convert colon templates with correct escaping' do

      tpl = URITemplate::RFC6570.try_convert( URITemplate::Colon.new('öö') )
      tpl.should_not be_nil

      tpl.should extract.from('%C3%B6%C3%B6')

    end

  end

end

