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

shared_examples "a uri template class" do

  it "should include URITemplate" do
    described_class.ancestors.should include(URITemplate)
  end

  it "should be constructible from an empty string" do
    expect{
      described_class.new("")
    }.to_not raise_error
  end

  it "should raise when argument is an object" do
    expect{
      described_class.new(Object.new)
    }.to raise_error(ArgumentError)
  end

  it "should have expand without args" do
    inst = described_class.new("")
    inst.expand().should be_kind_of(String)
  end

  it "should accept a hash for expand" do
    inst = described_class.new("")
    inst.expand('foo' => 'bar').should be_kind_of(String)
  end

  it "should accept anything that responds to #map for expand" do
    inst = described_class.new("")
    obj = Object.new
    def obj.map
      return [ yield("foo", "bar") ]
    end
    inst.expand(obj).should be_kind_of(String)
  end

  it "should warn if expand is called with an array" do
    inst = described_class.new("")
    inst.should_receive(:warn) do |message|
      message.should =~ /Passing variables as an Array to URITemplate#expand/
      nil
    end
    inst.expand([]).should be_kind_of(String)
  end


  it "should raise if the argument responds to #map but returns garbage" do
    inst = described_class.new("")
    obj = Object.new
    def obj.map
      return [ Object.new ]
    end
    expect{
      inst.expand(obj)
    }.to raise_error(ArgumentError, /variables.map/)
  end

  it "should compare true if the pattern is the same" do
    described_class.new("").should == described_class.new("")
  end

  it "should compare true to its pattern as string" do
    described_class.new("").should == ""
  end

  it "should override #tokens" do
    described_class.instance_method(:tokens).owner.should_not eq(URITemplate)
  end

  it "should override #type" do
    described_class.instance_method(:type).owner.should_not eq(URITemplate)
  end

  it "should #try_convert an instance into it self" do
    inst = described_class.new("")
    described_class.try_convert(inst).should == inst
  end

  it "should #try_convert a string into an instance" do
    described_class.try_convert("").should == described_class.new("")
  end

  it "should refuse #try_covert for an arbitrary object" do
    described_class.try_convert(Object.new).should be_nil
  end

  it "should refuse #try_covert for an unrelated uritemplate" do
    o = Object.new
    def o.kind_of?(k)
      super || ( k == URITemplate )
    end
    described_class.try_convert(o).should be_nil
  end

  it "should #convert an instance into it self" do
    inst = described_class.new("")
    described_class.convert(inst).should == inst
  end

  it "should #convert a string into an instance" do
    described_class.convert("").should == described_class.new("")
  end

  it "should refuse #covert for an arbitrary object" do
    expect{
      described_class.convert(Object.new)
    }.to raise_error(ArgumentError,/converted into a URITemplate/)
  end

  it "should refuse #try_covert for an unrelated uritemplate" do
    o = Object.new
    def o.kind_of?(k)
      super || ( k == URITemplate )
    end
    expect{
      described_class.convert(o)
    }.to raise_error(ArgumentError,/converted into a URITemplate/)
  end

end


shared_examples "a uri template class with extraction" do

  it "should respond to extract" do
    described_class.new("").should respond_to(:extract)
  end

  it "should return nil if a pattern didn't match" do
    described_class.new("x").should_not extract.from("y")
  end

  it "should return a hash if a pattern did match" do
    described_class.new("x").should extract.from("x")
  end

  it "should return nil if passed nil" do
    described_class.new("x").extract(nil).should be_nil
  end

  it "should not yield if a pattern didn't match" do
    expect{|b|
      described_class.new("x").extract("y", &b)
    }.not_to yield_control
  end

  it "should not yield if passed nil" do
    expect{|b|
      described_class.new("x").extract(nil, &b)
    }.not_to yield_control
  end

  it "should yield a hash if a pattern did match" do
    expect{|b|
     described_class.new("x").extract("x", &b)
    }.to yield_with_args(Hash)
  end

  it "should return the result of the block" do
    o = Object.new
    described_class.new("x").extract("x"){|_| o }.should == o
  end

end

shared_examples "a string util helper" do

  it "escapes an empty string correctly" do
    subject.escape_uri("").should == ""
    subject.escape_url("").should == ""
  end

  it "escapes an all-ascii string correctly" do
    subject.escape_uri("abcdef123").should == "abcdef123"
    subject.escape_url("abcdef123").should == "abcdef123"
  end

  it "escapes a multibyte pct string correctly" do
    subject.escape_uri("ü").should == "%C3%BC"
    subject.escape_url("ü").should == "%C3%BC"
  end

  it "escapes a space correctly" do
    subject.escape_uri(" ").should == "%20"
    subject.escape_url(" ").should == "%20"
  end

  it "escapes a object with to_s correctly" do
    o = Object.new
    def o.to_s
      "o.to_s"
    end
    subject.escape_uri(o).should == "o.to_s"
    subject.escape_url(o).should == "o.to_s"
  end

  it "unescapes an empty string correctly" do
    subject.unescape_uri("").should == ""
    subject.unescape_url("").should == ""
  end

  it "unescapes an all-ascii string correctly" do
    subject.unescape_uri("abcdef123").should == "abcdef123"
    subject.unescape_url("abcdef123").should == "abcdef123"
  end

  it "unescapes a simple pct string correctly" do
    subject.unescape_uri("%20%30%40").should == " 0@"
    subject.unescape_url("%20%30%40").should == " 0@"
  end

  it "unescapes a plus correctly" do
    subject.unescape_uri("+").should == "+"
    subject.unescape_url("+").should == " "
  end

  it "unescapes a object with to_s correctly" do
    o = Object.new
    def o.to_s
      "o.to_s"
    end
    subject.unescape_uri(o).should == "o.to_s"
    subject.unescape_url(o).should == "o.to_s"
  end

  it "unescapes a single %" do
    subject.unescape_uri("%").should == "%"
    subject.unescape_url("%").should == "%"
  end

  it "unescapes a borked pct" do
    subject.unescape_uri("%fg").should == "%fg"
    subject.unescape_url("%fg").should == "%fg"
  end

  it "unescapes a too short pct" do
    subject.unescape_uri("%f").should == "%f"
    subject.unescape_url("%f").should == "%f"
  end
end
