# -*- encoding : utf-8 -*-
require 'uri_template'
require 'uri_template_shared'

RSpec.describe URITemplate::RFC6570 do

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
                expect(t).to expand(variables).to( results )
              end

              it " should partially expand #{template} correctly with variables", expand: :partially do
                results = Array(results)
                t = URITemplate::RFC6570.new( template )
                pt = t.expand_partial(variables)
                expect( pt ).to expand({}).to( results )
              end

              it " should partially expand #{template} correctly without variables", expand: :partially do
                t = URITemplate::RFC6570.new( template )
                expect( t ).to expand_partially({}).to( t )
              end

              Array(results).each do |result|

                it " should extract the variables from #{result} correctly " do
                  t = URITemplate::RFC6570.new( template )
                  expect(t).to extract.from(result)
                  expect(t).to expand_to( t.extract(result) , RUBY_VERSION > "1.9" ? result : results )
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
      expect{ URITemplate::RFC6570.new('{var.}') }.to raise_error(URITemplate::Invalid)
      expect{ URITemplate::RFC6570.new('{..var.}') }.to raise_error(URITemplate::Invalid)
    end

  end

  describe "expansion" do

    it "should refuse to expand a complex variable with length limit" do

      t = URITemplate::RFC6570.new("{?assoc:1}")
      expect(t).to expand("assoc"=>{'foo'=>'bar'}).to('?assoc=f')

    end

    it "should refuse to expand a array variable with length limit" do

      t = URITemplate::RFC6570.new("{?array:1}")
      expect(t).to expand("array"=>["a","b"]).to('?array=a')

    end

    it 'should expand assocs with dots' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      expect(t).to expand("assoc" => {'.'=>'dot'}).to('?.=dot')

    end

    it 'should expand assocs with minus' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      expect(t).to expand("assoc" => {'-'=>'minus'}).to('?-=minus')

    end

    it 'should expand assocs when using array expansion' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      expect(t).to expand([{'.'=>'dot'}]).to('?.=dot')

    end

    it 'should expand empty arrays' do
      t = URITemplate::RFC6570.new("{arr}")
      expect(t).to expand('arr' => []).to("")
    end

  end

  describe "partial expansion", expand: :partially do

    it "expands a simple expression partially without variables" do
      t = URITemplate::RFC6570.new('{x}')
      expect( t ).to expand_partially.to( t )
    end

    it "expands a simple expression partially with variables" do
      t = URITemplate::RFC6570.new('{x}')
      expect( t ).to expand_partially('x'=>'a').to( URITemplate::RFC6570.new('a{x}') )
    end

    it "expands a simple expression with multiple parts partially without variables" do
      t = URITemplate::RFC6570.new('{x,y}')
      expect( t ).to expand_partially.to( t )
    end

    it "expands a simple expression with multiple parts partially with variables" do
      t = URITemplate::RFC6570.new('{x,y}')
      expect( t ).to expand_partially('x'=>'a').to( URITemplate::RFC6570.new('a{x,y}') )
    end

    it "expands a simple expression with multiple parts partially with variables" do
      t = URITemplate::RFC6570.new('{x,y}')
      expect( t ).to expand_partially('y'=>'a').to( URITemplate::RFC6570.new('{x},a{y}') )
    end

    it "expands a fragment expression partially without variables" do
      t = URITemplate::RFC6570.new('{#x}')
      expect( t ).to expand_partially.to( t )
    end

    it "expands a fragment expression partially with variables" do
      t = URITemplate::RFC6570.new('{#x}')
      expect( t ).to expand_partially('x'=>'a').to( URITemplate::RFC6570.new('#a{+x}') )
    end

    it "expands a simple expression with multiple parts partially without variables" do
      t = URITemplate::RFC6570.new('{#x,y}')
      expect( t ).to expand_partially.to( t )
    end

    it "expands a simple expression with multiple parts partially with variables" do
      t = URITemplate::RFC6570.new('{#x,y}')
      expect( t ).to expand_partially('x'=>'a').to( URITemplate::RFC6570.new('#a{+x,y}') )
    end

    it "expands a simple expression with multiple parts partially with variables" do
      t = URITemplate::RFC6570.new('{#x,y}')
      expect( t ).to expand_partially('y'=>'a').to( URITemplate::RFC6570.new('#{+x},a{+y}') )
    end

    it "expands a form query with an explode" do
      t = URITemplate::RFC6570.new('{?x*}')
      expect( t ).to expand_partially('x'=>{'a'=>'b','c'=>'d'}).to( URITemplate::RFC6570.new('?a=b&c=d{&x*}') )
    end
  end

  describe "extraction" do

    it ' should ignore draf7-style lists' do

      t = URITemplate::RFC6570.new("{?list*}")
      expect(t.extract('?a&b&c')).to be_nil
      expect(t).to extract('list'=>%w{a b c}).from('?list=a&list=b&list=c')

    end

    it 'should extract multiple reserved lists' do

      t = URITemplate::RFC6570.new("{+listA*,listB*}")
      expect(t).to extract('listA'=>%w{a b c},'listB'=>%w{d}).from('a,b,c,d')

    end

    it 'should extract assocs with dots' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      expect(t).to extract("assoc" => {'.'=>'dot'}).from('?.=dot')

    end

    it 'should extract assocs with minus' do

      t = URITemplate::RFC6570.new("{?assoc*}")
      expect(t).to extract("assoc" => {'-'=>'minus'}).from('?-=minus')

    end

    it 'should extract from it\'s owns regex\' match ' do

      t = URITemplate::RFC6570.new("{simple}")
      expect(t).to extract("simple" => "yes").from(t.to_r.match("yes"))

    end

    it "accepts CONVERT_VALUES arg" do
      t = URITemplate::RFC6570.new('{?assoc*}')
      expect(t.extract('?a=b&c=d', URITemplate::RFC6570::CONVERT_RESULT)).to eq({'assoc' => [['a','b'],['c','d']] })
    end

    it "accepts CONVERT_RESULT arg" do
      t = URITemplate::RFC6570.new('{?assoc*}')
      expect(t.extract('?a=b&c=d', URITemplate::RFC6570::CONVERT_VALUES)).to eq([['assoc', {'a'=>'b','c'=>'d'}]])
    end

    it "correctly refuses wrong MatchData", :if => //.match("").respond_to?(:regexp) do
      t = URITemplate::RFC6570.new('a')
      expect do
        t.extract(/b/.match("b"))
      end.to raise_error(ArgumentError, /not generated by this/)
    end

    it "correctly refuses an random object" do
      expect do
        URITemplate::RFC6570.new("a").extract(Object.new)
      end.to raise_error(ArgumentError, /but got/)
    end

  end

  describe "extract_simple" do

    it "extracts without postproccessing" do
      t = URITemplate::RFC6570.new('{?assoc*}')
      expect(t.extract_simple('?a=b&c=d')).to eq([['assoc',[['a','b'],['c','d']]]])
    end

  end

  describe "conversion" do

    it ' should convert simple colon templates' do

      expect(URITemplate::RFC6570.try_convert( URITemplate::Colon.new(':var') )).not_to be_nil

    end

    it ' should convert colon templates with correct escaping' do

      tpl = URITemplate::RFC6570.try_convert( URITemplate::Colon.new('öö') )
      expect(tpl).not_to be_nil

      expect(tpl).to extract.from('%C3%B6%C3%B6')

    end

    it ' should raise when conversion is not possible' do

      expect{
        URITemplate::RFC6570.convert( Object.new )
      }.to raise_error(ArgumentError)

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
      failure_message do |actual|
        "expected that #{actual.inspect} is a template with level #{expected}, but is #{actual.level}(according to RFC6570)"
      end
    end

    it "should be correctly determined for {var}" do
      expect(URITemplate::RFC6570.new("{var}")).to have_level(1)
    end
    it "should be correctly determined for O{empty}X" do
      expect(URITemplate::RFC6570.new("O{empty}X")).to have_level(1)
    end
    it "should be correctly determined for {x,y}" do
      expect(URITemplate::RFC6570.new("{x,y}")).to have_level(3)
    end
    it "should be correctly determined for {var:3}" do
      expect(URITemplate::RFC6570.new("{var:3}")).to have_level(4)
    end
    it "should be correctly determined for {list*}" do
      expect(URITemplate::RFC6570.new("{list*}")).to have_level(4)
    end
    it "should be correctly determined for {+var}" do
      expect(URITemplate::RFC6570.new("{+var}")).to have_level(2)
    end
    it "should be correctly determined for {+x,hello,y}" do
      expect(URITemplate::RFC6570.new("{+x,hello,y}")).to have_level(3)
    end
    it "should be correctly determined for {+path:6}/here" do
      expect(URITemplate::RFC6570.new("{+path:6}/here")).to have_level(4)
    end
    it "should be correctly determined for {+list*}" do
      expect(URITemplate::RFC6570.new("{+list*}")).to have_level(4)
    end
    it "should be correctly determined for {#var}" do
      expect(URITemplate::RFC6570.new("{#var}")).to have_level(2)
    end
    it "should be correctly determined for {#x,hello,y}" do
      expect(URITemplate::RFC6570.new("{#x,hello,y}")).to have_level(3)
    end
    it "should be correctly determined for {#path:6}/here" do
      expect(URITemplate::RFC6570.new("{#path:6}/here")).to have_level(4)
    end
    it "should be correctly determined for {#list*}" do
      expect(URITemplate::RFC6570.new("{#list*}")).to have_level(4)
    end
    it "should be correctly determined for {.who}" do
      expect(URITemplate::RFC6570.new("{.who}")).to have_level(3)
    end
    it "should be correctly determined for {.who,who}" do
      expect(URITemplate::RFC6570.new("{.who,who}")).to have_level(3)
    end
    it "should be correctly determined for X{.list*}" do
      expect(URITemplate::RFC6570.new("X{.list*}")).to have_level(4)
    end
    it "should be correctly determined for {/who}" do
      expect(URITemplate::RFC6570.new("{/who}")).to have_level(3)
    end
    it "should be correctly determined for {/who,who}" do
      expect(URITemplate::RFC6570.new("{/who,who}")).to have_level(3)
    end
  end

  describe 'host?' do

    it 'should be true if a reserved expansion is present' do

      tpl = URITemplate::RFC6570.new("{+foo}")

      expect(tpl.host?).to be true

    end

  end

  describe 'scheme?' do

    it 'should be true if a reserved expansion is present' do

      tpl = URITemplate::RFC6570.new("{+foo}")

      expect(tpl.scheme?).to be true

    end

  end

end

