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
require 'uri_template_shared'

describe URITemplate::RFC6570 do

  it_should_behave_like "a uri template class"

  it_should_behave_like "a uri template class with extraction"

  ['spec-examples.json', 'extended-tests.json', 'negative-tests.json'].each do |file_name|

  describe "( in the examples from uritemplate-test " do

    f = File.new(File.expand_path(file_name, File.join(File.dirname(__FILE__),'./uritemplate-test')))
    data = MultiJson.load( f.read )
    data.each do |label, spec|
      describe "- #{label} )" do
        variables = force_all_utf8( spec['variables'] )

        spec['testcases'].each do | template, results |

          describe template do

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
                t.should expand(variables).to( results )
              end

              Array(results).each do |result|

                it " should extract the variables from #{result} correctly " do
                  t = URITemplate::RFC6570.new( template )
                  t.should extract.from(result)
                  t.should expand_to( t.extract(result) , RUBY_VERSION > "1.9" ? result : results )
                end

              end

            else
              warn "Ignoring template #{template}"
            end

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

    it 'should expand assocs with dots' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      t.should expand("assoc" => {'.'=>'dot'}).to('?.=dot')

    end

    it 'should expand assocs with minus' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      t.should expand("assoc" => {'-'=>'minus'}).to('?-=minus')

    end

    it 'should expand empty arrays' do
      t = URITemplate::RFC6570.new("{arr}")
      t.should expand('arr' => []).to("")
    end

  end

  describe "extraction" do

    it ' should ignore draf7-style lists' do

      t = URITemplate::RFC6570.new("{?list*}")
      t.extract('?a&b&c').should be_nil
      t.should extract('list'=>%w{a b c}).from('?list=a&list=b&list=c')

    end

    it 'should extract multiple reserved lists' do

      t = URITemplate::RFC6570.new("{+listA*,listB*}")
      t.should extract('listA'=>%w{a b c},'listB'=>%w{d}).from('a,b,c,d')

    end

    it 'should extract assocs with dots' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      t.should extract("assoc" => {'.'=>'dot'}).from('?.=dot')

    end

    it 'should extract assocs with minus' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      t.should extract("assoc" => {'-'=>'minus'}).from('?-=minus')

    end

    it 'should extract from it\'s owns regex\' match ' do

      t = URITemplate::RFC6570.new("{simple}")
      t.should extract("simple" => "yes").from(t.to_r.match("yes"))

    end

    it "accepts CONVERT_VALUES arg" do
      t = URITemplate::RFC6570.new('{?assoc*}')
      t.extract('?a=b&c=d', URITemplate::RFC6570::CONVERT_RESULT).should == {'assoc' => [['a','b'],['c','d']] }
    end
    
    it "accepts CONVERT_RESULT arg" do
      t = URITemplate::RFC6570.new('{?assoc*}')
      t.extract('?a=b&c=d', URITemplate::RFC6570::CONVERT_VALUES).should == [['assoc', {'a'=>'b','c'=>'d'}]]
    end

  end

  describe "extract_simple" do

    it "extracts without postproccessing" do
      t = URITemplate::RFC6570.new('{?assoc*}')
      t.extract_simple('?a=b&c=d').should == [['assoc',[['a','b'],['c','d']]]]
    end

  end

  describe "conversion" do

    it ' should convert simple colon templates' do

      URITemplate::RFC6570.try_convert( URITemplate::Colon.new(':var') ).should_not be_nil

    end

    it ' should convert colon templates with correct escaping' do

      tpl = URITemplate::RFC6570.try_convert( URITemplate::Colon.new('öö') )
      tpl.should_not be_nil

      tpl.should extract.from('%C3%B6%C3%B6')

    end

    it ' should raise when conversion is not possible' do

      expect{
        URITemplate::RFC6570.convert( Object.new )
      }.to raise_error

    end

  end

  describe "level of" do

    matcher :have_level do |expected|
      match do |actual|
        actual.level == expected
      end
      description do
        "be a template with level #{expected} (according to RFC6570)"
      end
      failure_message_for_should do |actual|
        "expected that #{actual.inspect} is a template with level #{expected}, but is #{actual.level}(according to RFC6570)"
      end
    end

    it "should be correctly determined for {var}" do
      URITemplate::RFC6570.new("{var}").should have_level(1)
    end
    it "should be correctly determined for O{empty}X" do
      URITemplate::RFC6570.new("O{empty}X").should have_level(1)
    end
    it "should be correctly determined for {x,y}" do
      URITemplate::RFC6570.new("{x,y}").should have_level(3)
    end
    it "should be correctly determined for {var:3}" do
      URITemplate::RFC6570.new("{var:3}").should have_level(4)
    end
    it "should be correctly determined for {list*}" do
      URITemplate::RFC6570.new("{list*}").should have_level(4)
    end
    it "should be correctly determined for {+var}" do
      URITemplate::RFC6570.new("{+var}").should have_level(2)
    end
    it "should be correctly determined for {+x,hello,y}" do
      URITemplate::RFC6570.new("{+x,hello,y}").should have_level(3)
    end
    it "should be correctly determined for {+path:6}/here" do
      URITemplate::RFC6570.new("{+path:6}/here").should have_level(4)
    end
    it "should be correctly determined for {+list*}" do
      URITemplate::RFC6570.new("{+list*}").should have_level(4)
    end
    it "should be correctly determined for {#var}" do
      URITemplate::RFC6570.new("{#var}").should have_level(2)
    end
    it "should be correctly determined for {#x,hello,y}" do
      URITemplate::RFC6570.new("{#x,hello,y}").should have_level(3)
    end
    it "should be correctly determined for {#path:6}/here" do
      URITemplate::RFC6570.new("{#path:6}/here").should have_level(4)
    end
    it "should be correctly determined for {#list*}" do
      URITemplate::RFC6570.new("{#list*}").should have_level(4)
    end
    it "should be correctly determined for {.who}" do
      URITemplate::RFC6570.new("{.who}").should have_level(3)
    end
    it "should be correctly determined for {.who,who}" do
      URITemplate::RFC6570.new("{.who,who}").should have_level(3)
    end
    it "should be correctly determined for X{.list*}" do
      URITemplate::RFC6570.new("X{.list*}").should have_level(4)
    end
    it "should be correctly determined for {/who}" do
      URITemplate::RFC6570.new("{/who}").should have_level(3)
    end
    it "should be correctly determined for {/who,who}" do
      URITemplate::RFC6570.new("{/who,who}").should have_level(3)
    end
  end

  describe 'host?' do 

    it 'should be true if a reserved expansion is present' do

      tpl = URITemplate::RFC6570.new("{+foo}")

      tpl.host?.should be_true

    end

  end

  describe 'scheme?' do 

    it 'should be true if a reserved expansion is present' do

      tpl = URITemplate::RFC6570.new("{+foo}")

      tpl.scheme?.should be_true

    end

  end

end

