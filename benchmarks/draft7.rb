require 'rubygems'
gem 'addressable'
require 'addressable/uri'
require 'addressable/template'

$LOAD_PATH << File.expand_path('../lib',File.dirname(__FILE__))

require 'benchmark'
require 'uri_template'

variables = {
  'simple_string'=>'noneedtoescape',
  'escaped_string'=>'/ /%/ ?+',
  'segments'=>['a','b','c'],
  'one'=>1,'two'=>2,'three'=>3,
  'host'=>'example.com',
  'fragment'=>'foo'

}

expansions = [

  {:addressable=>'', :uri_template=>'',:variables=>{},:result=>''},
  {:addressable=>'{simple_string}', :uri_template=>'{simple_string}',:variables=>variables,:result=>'noneedtoescape'},
  {:addressable=>'{escaped_string}', :uri_template=>'{escaped_string}',:variables=>variables,:result=>'%2F%20%2F%25%2F%20%3F%2B'},
  {:addressable=>'{missing}', :uri_template=>'{missing}',:variables=>variables,:result=>''},
  
  {:addressable=>'{-prefix|/|segments}', :uri_template=>'{/segments*}',:variables=>variables, :result=>'/a/b/c'},
  {:addressable=>'?{-join|&|one,two,three}', :uri_template=>'{?one,two,three}',:variables=>variables, :result=>'?one=1&two=2&three=3'},
  
  {:addressable=>'http://{host}/{-suffix|/|segments}?{-join|&|one,two,bogus}#{fragment}',
   :uri_template=>'http://{host}{/segments*}/{?one,two,bogus}{#fragment}',
   :variables => variables,
   :result => 'http://example.com/a/b/c/?one=1&two=2#foo'}
   
  
]

n = 1_000

expansions.each do |exp|
  
  str = Addressable::Template.new(exp[:addressable]).expand(exp[:variables]).to_s
  raise "Unexpected result: #{str.inspect} with addressable" unless str == exp[:result]
  
  puts Addressable::Template.new(exp[:addressable]).extract(exp[:result]).inspect

  str = URITemplate::Draft7.new(exp[:uri_template]).expand(exp[:variables])
  raise "Unexpected result: #{str.inspect} with uri_template" unless str == exp[:result]
  
  puts URITemplate::Draft7.new(exp[:uri_template]).extract(exp[:result]).inspect
  
end


expansions.each do |exp|
  
  puts "#{exp[:addressable].inspect} vs #{exp[:uri_template].inspect} => #{exp[:result].inspect}"
  
  Benchmark.bm do |bm|
    bm.report('Addressable'){ n.times{
      Addressable::Template.new(exp[:addressable]).expand(exp[:variables])
    }}
    bm.report('UriTemplate '){ n.times{
      URITemplate::Draft7.new(exp[:uri_template]).expand(exp[:variables])
    }}
    
    a = Addressable::Template.new(exp[:addressable])
    u = URITemplate::Draft7.new(exp[:uri_template])
    
    bm.report('Addressable*'){ n.times{
      a.expand(exp[:variables])
    }}
    bm.report('UriTemplate*'){ n.times{
      u.expand(exp[:variables])
    }}
  end
  
end

expansions.each do |exp|
  
  puts "#{exp[:result].inspect} => #{exp[:addressable].inspect} vs #{exp[:uri_template].inspect}"
  
  Benchmark.bm do |bm|
    bm.report('Addressable'){ n.times{
      Addressable::Template.new(exp[:addressable]).extract(exp[:result])
    }}
    bm.report('UriTemplate '){ n.times{
      URITemplate::Draft7.new(exp[:uri_template]).extract(exp[:result])
    }}
    
    a = Addressable::Template.new(exp[:addressable])
    u = URITemplate::Draft7.new(exp[:uri_template])
    
    bm.report('Addressable*'){ n.times{
      a.extract(exp[:result])
    }}
    bm.report('UriTemplate*'){ n.times{
      u.extract(exp[:result])
    }}
  end
  
end

