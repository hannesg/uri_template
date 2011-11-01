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
#    (c) 2011 by Hannes Georg
#

require 'uri_template'

variables = {
  'dom' => "example.com",
  'dub' => "me/too",
  'hello' => "Hello World!",
  'half' => "50%",
  'var' => "value",
  'who' => "fred",
  'base' => "http://example.com/home/",
  'path' => "/foo/bar",
  'list' => [ "red", "green", "blue" ],
  'keys' => { "semi" => ";" , "dot" => "." , "comma" => ","},
  'v' => "6",
  'x' => "1024",
  'y' => "768",
  'empty' => "",
  'empty_keys' => [],
  'undef' => nil,
  'host' => "www.myhost.com",
  'segments' => ["path","to"],
  'file' => "file",
  'ext' => "ext",
  'args' => {"a"=>"b"}
}

expansion_results = {"{var}"=>"value",
 "{hello}"=>"Hello%20World%21",
 "{half}"=>"50%25",
 "O{empty}X"=>"OX",
 "O{undef}X"=>"OX",
 "{x,y}"=>"1024,768",
 "{x,hello,y}"=>"1024,Hello%20World%21,768",
 "?{x,empty}"=>"?1024,",
 "?{x,undef}"=>"?1024",
 "?{undef,y}"=>"?768",
 "{var:3}"=>"val",
 "{var:30}"=>"value",
 "{list}"=>"red,green,blue",
 "{list*}"=>"red,green,blue",
 "{keys}"=>"semi,%3B,dot,.,comma,%2C",
 "{keys*}"=>"semi=%3B,dot=.,comma=%2C",
 "{+var}"=>"value",
 "{+hello}"=>"Hello%20World!",
 "{+half}"=>"50%25",
 "{base}index"=>"http%3A%2F%2Fexample.com%2Fhome%2Findex",
 "{+base}index"=>"http://example.com/home/index",
 "O{+empty}X"=>"OX",
 "O{+undef}X"=>"OX",
 "{+path}/here"=>"/foo/bar/here",
 "here?ref={+path}"=>"here?ref=/foo/bar",
 "up{+path}{var}/here"=>"up/foo/barvalue/here",
 "{+x,hello,y}"=>"1024,Hello%20World!,768",
 "{+path,x}/here"=>"/foo/bar,1024/here",
 "{+path:6}/here"=>"/foo/b/here",
 "{+list}"=>"red,green,blue",
 "{+list*}"=>"red,green,blue",
 "{+keys}"=>"semi,;,dot,.,comma,,",
 "{+keys*}"=>"semi=;,dot=.,comma=,",
 "{#var}"=>"#value",
 "{#hello}"=>"#Hello%20World!",
 "{#half}"=>"#50%25",
 "foo{#empty}"=>"foo#",
 "foo{#undef}"=>"foo",
 "{#x,hello,y}"=>"#1024,Hello%20World!,768",
 "{#path,x}/here"=>"#/foo/bar,1024/here",
 "{#path:6}/here"=>"#/foo/b/here",
 "{#list}"=>"#red,green,blue",
 "{#list*}"=>"#red,green,blue",
 "{#keys}"=>"#semi,;,dot,.,comma,,",
 "{#keys*}"=>"#semi=;,dot=.,comma=,",
 "{.who}"=>".fred",
 "{.who,who}"=>".fred.fred",
 "{.half,who}"=>".50%25.fred",
 "www{.dom}"=>"www.example.com",
 "X{.var}"=>"X.value",
 "X{.empty}"=>"X.",
 "X{.undef}"=>"X",
 "X{.var:3}"=>"X.val",
 "X{.list}"=>"X.red,green,blue",
 "X{.list*}"=>"X.red.green.blue",
 "X{.keys}"=>"X.semi,%3B,dot,.,comma,%2C",
 "X{.keys*}"=>"X.semi=%3B.dot=..comma=%2C",
 "X{.empty_keys}"=>"X",
 "X{.empty_keys*}"=>"X",
 "{/who}"=>"/fred",
 "{/who,who}"=>"/fred/fred",
 "{/half,who}"=>"/50%25/fred",
 "{/who,dub}"=>"/fred/me%2Ftoo",
 "{/var}"=>"/value",
 "{/var,empty}"=>"/value/",
 "{/var,undef}"=>"/value",
 "{/var,x}/here"=>"/value/1024/here",
 "{/var:1,var}"=>"/v/value",
 "{/list}"=>"/red,green,blue",
 "{/list*}"=>"/red/green/blue",
 "{/list*,path:4}"=>"/red/green/blue/%2Ffoo",
 "{/keys}"=>"/semi,%3B,dot,.,comma,%2C",
 "{/keys*}"=>"/semi=%3B/dot=./comma=%2C",
 "{;who}"=>";who=fred",
 "{;half}"=>";half=50%25",
 "{;empty}"=>";empty",
 "{;v,empty,who}"=>";v=6;empty;who=fred",
 "{;v,bar,who}"=>";v=6;who=fred",
 "{;x,y}"=>";x=1024;y=768",
 "{;x,y,empty}"=>";x=1024;y=768;empty",
 "{;x,y,undef}"=>";x=1024;y=768",
 "{;hello:5}"=>";hello=Hello",
 "{;list}"=>";list=red,green,blue",
 "{;list*}"=>";red;green;blue",
 "{;keys}"=>";keys=semi,%3B,dot,.,comma,%2C",
 "{;keys*}"=>";semi=%3B;dot=.;comma=%2C",
 "{?who}"=>"?who=fred",
 "{?half}"=>"?half=50%25",
 "{?x,y}"=>"?x=1024&y=768",
 "{?x,y,empty}"=>"?x=1024&y=768&empty=",
 "{?x,y,undef}"=>"?x=1024&y=768",
 "{?var:3}"=>"?var=val",
 "{?list}"=>"?list=red,green,blue",
 "{?list*}"=>"?red&green&blue",
 "{?keys}"=>"?keys=semi,%3B,dot,.,comma,%2C",
 "{?keys*}"=>"?semi=%3B&dot=.&comma=%2C",
 "{&who}"=>"&who=fred",
 "{&half}"=>"&half=50%25",
 "?fixed=yes{&x}"=>"?fixed=yes&x=1024",
 "{&x,y,empty}"=>"&x=1024&y=768&empty=",
 "{&x,y,undef}"=>"&x=1024&y=768",
 "{&var:3}"=>"&var=val",
 "{&list}"=>"&list=red,green,blue",
 "{&list*}"=>"&red&green&blue",
 "{&keys}"=>"&keys=semi,%3B,dot,.,comma,%2C",
 "{&keys*}"=>"&semi=%3B&dot=.&comma=%2C",
 
 "{&list,keys*}"=>"&list=red,green,blue&semi=%3B&dot=.&comma=%2C",
 
 "{&hello}" => "&hello=Hello%20World%21",
 
 "http://{+host}{/segments*}/{file}{.ext*}{?args*}" => "http://www.myhost.com/path/to/file.ext?a=b"
}

extraction_results = {"{var}"=>[["var", "value"]],
 "{hello}"=>[["hello", "Hello World!"]],
 "{half}"=>[["half", "50%"]],
 "O{empty}X"=>[["empty", ""]],
 "O{undef}X"=>[["undef", ""]],
 "{x,y}"=>[["x", "1024"], ["y", "768"]],
 "{x,hello,y}"=>[["x", "1024"], ["hello", "Hello World!"], ["y", "768"]],
 "?{x,empty}"=>[["x", "1024"], ["empty", ""]],
 "?{x,undef}"=>[["x", "1024"], ["undef", nil]],
 "?{undef,y}"=>[["undef", "768"], ["y", nil]],
 "{var:3}"=>[["var", "val"]],
 "{var:30}"=>[["var", "value"]],
 "{list}"=>[["list", ["red", "green", "blue"]]],
 "{list*}"=>[["list", ["red", "green", "blue"]]],
 "{keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{keys*}"=>[["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 "{+var}"=>[["var", "value"]],
 "{+hello}"=>[["hello", "Hello World!"]],
 "{+half}"=>[["half", "50%"]],
 "{base}index"=>[["base", "http://example.com/home/"]],
 "{+base}index"=>[["base", "http://example.com/home/"]],
 "O{+empty}X"=>[["empty", ""]],
 "O{+undef}X"=>[["undef", ""]],
 "{+path}/here"=>[["path", "/foo/bar"]],
 "here?ref={+path}"=>[["path", "/foo/bar"]],
 "up{+path}{var}/here"=>[["path", "/foo/"], ["var", "barvalue"]],
 "{+x,hello,y}"=>[["x", "1024"], ["hello", "Hello World!"], ["y", "768"]],
 "{+path,x}/here"=>[["path", "/foo/bar"], ["x", "1024"]],
 "{+path:6}/here"=>[["path", "/foo/b"]],
 "{+list}"=>[["list", ["red", "green", "blue"]]],
 "{+list*}"=>[["list", ["red", "green", "blue"]]],
 "{+keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{+keys*}"=>[["keys", [["semi",";"],["dot","."], ["comma",","]]]],
 "{#var}"=>[["var", "value"]],
 "{#hello}"=>[["hello", "Hello World!"]],
 "{#half}"=>[["half", "50%"]],
 "foo{#empty}"=>[["empty", ""]],
 "foo{#undef}"=>[["undef", nil]],
 "{#x,hello,y}"=>[["x", "1024"], ["hello", "Hello World!"], ["y", "768"]],
 "{#path,x}/here"=>[["path", "/foo/bar"], ["x", "1024"]],
 "{#path:6}/here"=>[["path", "/foo/b"]],
 "{#list}"=>[["list", ["red", "green", "blue"]]],
 "{#list*}"=>[["list", ["red", "green", "blue"]]],
 "{#keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{#keys*}"=>[["keys", [["semi",";"], ["dot", "."], ["comma",","]]]],
 "{.who}"=>[["who", "fred"]],
 "{.who,who}"=>[["who", "fred"], ["who", "fred"]],
 "{.half,who}"=>[["half", "50%"], ["who", "fred"]],
 "www{.dom}"=>[["dom", "example.com"]],
 "X{.var}"=>[["var", "value"]],
 "X{.empty}"=>[["empty", ""]],
 "X{.undef}"=>[["undef", nil]],
 "X{.var:3}"=>[["var", "val"]],
 "X{.list}"=>[["list", ["red", "green", "blue"]]],
 "X{.list*}"=>[["list", ["red", "green", "blue"]]],
 "X{.keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "X{.keys*}"=>[["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 "X{.empty_keys}"=>[["empty_keys", nil]],
 "X{.empty_keys*}"=>[["empty_keys", nil]],
 "{/who}"=>[["who", "fred"]],
 "{/who,who}"=>[["who", "fred"], ["who", "fred"]],
 "{/half,who}"=>[["half", "50%"], ["who", "fred"]],
 "{/who,dub}"=>[["who", "fred"], ["dub", "me/too"]],
 "{/var}"=>[["var", "value"]],
 "{/var,empty}"=>[["var", "value"], ["empty", ""]],
 "{/var,undef}"=>[["var", "value"], ["undef", nil]],
 "{/var,x}/here"=>[["var", "value"], ["x", "1024"]],
 "{/var:1,var}"=>[["var", "v"], ["var", "value"]],
 "{/list}"=>[["list", ["red", "green", "blue"]]],
 "{/list*}"=>[["list", ["red", "green", "blue"]]],
 "{/list*,path:4}"=>
  [["list", ["red", "green", "blue", "/foo"]], ["path", nil]],
 "{/keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{/keys*}"=>[["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 "{;who}"=>[["who", "fred"]],
 "{;half}"=>[["half", "50%"]],
 "{;empty}"=>[["empty", ""]],
 "{;v,empty,who}"=>[["v", "6"], ["empty", ""], ["who", "fred"]],
 "{;v,bar,who}"=>[["v", "6"], ["bar", nil], ["who", "fred"]],
 "{;x,y}"=>[["x", "1024"], ["y", "768"]],
 "{;x,y,empty}"=>[["x", "1024"], ["y", "768"], ["empty", ""]],
 "{;x,y,undef}"=>[["x", "1024"], ["y", "768"], ["undef", nil]],
 "{;hello:5}"=>[["hello", "Hello"]],
 "{;list}"=>[["list", ["red", "green", "blue"]]],
 "{;list*}"=>[["list", ["red", "green", "blue"]]],
 "{;keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{;keys*}"=>[["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 "{?who}"=>[["who", "fred"]],
 "{?half}"=>[["half", "50%"]],
 "{?x,y}"=>[["x", "1024"], ["y", "768"]],
 "{?x,y,empty}"=>[["x", "1024"], ["y", "768"], ["empty", ""]],
 "{?x,y,undef}"=>[["x", "1024"], ["y", "768"], ["undef", nil]],
 "{?var:3}"=>[["var", "val"]],
 "{?list}"=>[["list", ["red", "green", "blue"]]],
 "{?list*}"=>[["list", ["red", "green", "blue"]]],
 "{?keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{?keys*}"=>[["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 "{&who}"=>[["who", "fred"]],
 "{&half}"=>[["half", "50%"]],
 "?fixed=yes{&x}"=>[["x", "1024"]],
 "{&x,y,empty}"=>[["x", "1024"], ["y", "768"], ["empty", ""]],
 "{&x,y,undef}"=>[["x", "1024"], ["y", "768"], ["undef", nil]],
 "{&var:3}"=>[["var", "val"]],
 "{&list}"=>[["list", ["red", "green", "blue"]]],
 "{&list*}"=>[["list", ["red", "green", "blue"]]],
 "{&keys}"=>[["keys", ["semi", ";", "dot", ".", "comma",","]]],
 "{&keys*}"=>[["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 
 "{&hello}" => [["hello","Hello World!"]],
 
 "{&list,keys*}"=>[["list",["red","green","blue"]],["keys", [["semi", ";"], ["dot", "."], ["comma", ","]]]],
 
 "http://{+host}{/segments*}/{file}{.ext*}{?args*}" => [ ['host','www.myhost.com'],['segments',['path','to']],['file','file'],['ext',['ext']],['args',[['a','b']]]]
}




describe URITemplate::Draft7 do

  describe "basic expansion" do

  expansion_results.each{|pattern, exp|
  
    it "should expand #{pattern.inspect} to #{exp.inspect}" do
      p = URITemplate::Draft7.new(pattern)
      URITemplate::Draft7.valid?(pattern).should == true
      s = p.expand(variables)
      s.should == exp
    end
    
  }
  
  end
  
  describe "basic extraction" do

  extraction_results.each{|pattern, exp|
  
    it "should extract #{pattern.inspect} from #{expansion_results[pattern].inspect}" do
      p = URITemplate::Draft7.new(pattern)
      v = p.extract_simple(expansion_results[pattern])
      v.should_not be_nil
      v.should == exp
      
      # make some easy transformations
      tv = p.extract(expansion_results[pattern])
      p.expand(tv).should == expansion_results[pattern]
      
    end
    
  }
  
  end
  
  describe "edge-cases" do
  
    it "should work with empty strings" do
    
      p = URITemplate::Draft7.new('')
      p.should === ''
      p.should_not === 'x'
      
      rep = URITemplate::Draft7::Section.new(p.send(:tokens))
      rep.to_s.should == ""
      
    end
    
    it "should raise on no template" do
    
      lambda{ URITemplate::Draft7.new() }.should raise_error(ArgumentError)
    
    end
  
    it "should raise on random object" do
    
      lambda{ URITemplate::Draft7.new(Object.new) }.should raise_error(ArgumentError)
    
    end
  
    it "should raise on foreign match data extraction" do
    
      tpl = URITemplate::Draft7.new('tpl')
      md = /something else/.match('something else')
      md.should_not be_nil
      
      lambda{ tpl.extract(md) }.should raise_error(ArgumentError)
    
    end
    
    it "should pass nil thru extraction" do
    
      tpl = URITemplate::Draft7.new('tpl')
      tpl.extract(nil).should be_nil
    
    end
    
    it "should not extract newlines" do
    
      tpl = URITemplate::Draft7.new('{x}')
      tpl.extract("\n").should_not == {'x'=>"\n"}
      tpl.extract("%0A").should == {'x'=>"\n"}
    
    end
    
  end
  
  describe "bogus templates" do
  
    it "should raise on open expansions" do
    
      lambda{ URITemplate::Draft7.new('bogus{var') }.should raise_error(URITemplate::Invalid)
      lambda{ URITemplate::Draft7.new('bogus}var') }.should raise_error(URITemplate::Invalid)
    
    end
    
    it "should raise on non-uri characters" do
    
      lambda{ URITemplate::Draft7.new("\n") }.should raise_error(URITemplate::Invalid)
      lambda{ URITemplate::Draft7.new(" ") }.should raise_error(URITemplate::Invalid)
      lambda{ URITemplate::Draft7.new("\r") }.should raise_error(URITemplate::Invalid)
    
    end
  
  end
  
  describe "general usage" do
  
    it "should parse variable names correctly" do
      
      p = URITemplate::Draft7.new('{a,b,c}{x,y}{c,a,b}{b,c,a}')
      p.variables.should == ['x','y','b','c','a']
      
    end
    
    it "should yield on extract correctly" do
    
      p = URITemplate::Draft7.new('/foo/{bar}')
      fn = mock()
      fn.should_receive(:call).once
      
      p.extract('/foo/baz'){|a|
        fn.call(a)
        a.should == {'bar'=>'baz'}
      }
      
    end
  
  end
  
  describe "chaining" do
  
    it "should work with empty chains" do
      
      chain = URITemplate::Draft7::Section.try_convert("…")
      chain.send(:tokens).should have(2).item
      
      chain.should === 'foobar'
      
      combo = chain >> '…/xy'
      
      combo.should_not === 'foobar'
      
      combo.should === '/xy'
      
      rechain = URITemplate::Draft7::Section.new(chain.send(:tokens))
      
      rechain.to_s.should == "…"
      
    end
    
    it "should work with multiple empty chains" do
      
      chain = URITemplate::Draft7::Section.try_convert("…")
      
      combo = chain >> '……'
      
      combo.should == chain
      
      combo2 = chain >> "…"
      
      combo2.should === ""
      combo2.should_not === "a"
      
    end
    
    it "should work" do
      
      chain = URITemplate::Draft7::Section.try_convert("/bla…")
      
      combination = chain >> "…/file{?args*}"
      
      combination.to_s.should == "/bla/file{?args*}"
      
    end
    
    it "should support expansions" do
    
      chain = URITemplate::Draft7::Section.try_convert("/bla/{foo}/…")
      chain.expand('foo'=>'bar').should == '/bla/bar/'
    
    end
  
  end
  
  describe "fuzzing" do
  
    module ValidExpressionFuzzer
      
      VARCHAR = ('a'..'z').to_a + ('A'..'Z').to_a + ['_']
      
      VARCHAR2 = VARCHAR + ['.']
      
      def self.fuzz
        '{' + URITemplate::Draft7::OPERATORS.keys.sample + (1+rand(10)).times.map{ fuzz_var }.join(',') + '}'
      end
      
      def self.fuzz_var
        ( [ VARCHAR.sample ] + rand(20).times.map{ VARCHAR2.sample } ).join
      end
    
    end
    
    module ValidLiteralFuzzer
      
      def self.fuzz
        rand(50).times.map{ (65 + rand(25)).chr }.join
      end
      
    end
    
    10.times do
    
      str = rand(10).times.map{ ValidExpressionFuzzer.fuzz + ValidLiteralFuzzer.fuzz }.join
      it "should handle #{str.inspect} correctly" do
        t = URITemplate::Draft7.new(URITemplate::Draft7.try_convert(str).send(:tokens))
        t.to_s.should == str
      end
      
    end
    
  end

end

