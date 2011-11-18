require 'rubygems'
gem 'addressable'
require 'addressable/uri'
require 'addressable/template'

$LOAD_PATH << File.expand_path('../lib',File.dirname(__FILE__))

gem 'rbench'
require 'rbench'
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

  {:addressable=>'', :uri_template=>'',:variables=>{},:result=>'',:name=>'Empty string'},
  {:addressable=>'{simple_string}', :uri_template=>'{simple_string}',:variables=>{'simple_string'=>"noneedtoescape"},:result=>'noneedtoescape',:name=>'One simple variable'},
  {:addressable=>'{escaped_string}', :uri_template=>'{escaped_string}',:variables=>{'escaped_string'=>'/ /%/ ?+'},:result=>'%2F%20%2F%25%2F%20%3F%2B',:name=>'One escaped variable'},
  {:addressable=>'{missing}', :uri_template=>'{missing}',:variables=>{},:result=>'',:name=>"One missing variable"},
  
  {:addressable=>'{-prefix|/|segments}', :uri_template=>'{/segments*}',:variables=>{'segments'=>['a','b','c']}, :result=>'/a/b/c',:name=>"Path segments"},
  {:addressable=>'?{-join|&|one,two,three}', :uri_template=>'{?one,two,three}',:variables=>{'one'=>1,'two'=>2,'three'=>3}, :result=>'?one=1&two=2&three=3', :name=>"Arguments"},
  
  {:addressable=>'http://{host}/{-suffix|/|segments}?{-join|&|one,two,bogus}#{fragment}',
   :uri_template=>'http://{host}{/segments*}/{?one,two,bogus}{#fragment}',
   :variables => variables,
   :result => 'http://example.com/a/b/c/?one=1&two=2#foo',
   :name => 'Full URI'},
  
  {:addressable=>'/foo/{-suffix|/|segments}bar?{-join|&|one,two,bogus}',
   :uri_template=>'/foo{/segments*}/bar{?one,two,bogus}',
   :variables => variables,
   :result => '/foo/a/b/c/bar?one=1&two=2',
   :name => 'Segments and Arguments'}
   
  
]

extractions = expansions + [

  {:addressable=>'/foo/{-suffix|/|segments}bar?{-join|&|one,two,bogus}',
   :uri_template=>'/foo{/segments*}/bar{?one,two,bogus}',
   :variables => variables,
   :result => '/foo/a/b/c/baz?one=1&two=2',
   :name => 'Segments and Arguments ( not extractable )'}

]

expansions.each do |exp|
  
  str = Addressable::Template.new(exp[:addressable]).expand(exp[:variables]).to_s
  raise "Unexpected result: #{str.inspect} with addressable" unless str == exp[:result]
  
  puts Addressable::Template.new(exp[:addressable]).extract(exp[:result]).inspect

  str = URITemplate::Draft7.new(exp[:uri_template]).expand(exp[:variables])
  raise "Unexpected result: #{str.inspect} with uri_template" unless str == exp[:result]
  
  puts URITemplate::Draft7.new(exp[:uri_template]).extract(exp[:result]).inspect
  
end


RBench.run(100_000) do

  column :addressable, :title => 'Addressable'
  column :addressable_cached, :title => 'Addressable*'
  column :draft7, :title => 'Draft7'
  column :draft7_cached, :title => 'Draft7*'
  
  group "Expansion" do
  
    expansions.each do |exp|
      report( exp[:name] ) do
        
        addressable{ Addressable::Template.new(exp[:addressable]).expand(exp[:variables]) }
        draft7{ URITemplate::Draft7.new(exp[:uri_template]).expand(exp[:variables]) }
        
        a = Addressable::Template.new(exp[:addressable])
        u = URITemplate::Draft7.new(exp[:uri_template])
        
        addressable_cached{ a.expand(exp[:variables]) }
        draft7_cached{ u.expand(exp[:variables]) }
        
      end
    end
    
  end
  
  group "Extraction" do
  
    extractions.each do |exp|
      report( exp[:name] ) do
        
        addressable{ Addressable::Template.new(exp[:addressable]).extract(exp[:result]) }
        draft7{ URITemplate::Draft7.new(exp[:uri_template]).extract(exp[:result]) }
        
        a = Addressable::Template.new(exp[:addressable])
        u = URITemplate::Draft7.new(exp[:uri_template])
        
        addressable_cached{ a.extract(exp[:result]) }
        draft7_cached{ u.extract(exp[:result]) }
        
      end
    end
    
  
  end
end
=begin
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
=end
