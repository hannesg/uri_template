# -*- encoding : utf-8 -*-
RSpec.shared_examples "a uri template class" do

  it "should include URITemplate" do
    expect(described_class.ancestors).to include(URITemplate)
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
    expect(inst.expand()).to be_kind_of(String)
  end

  it "should accept a hash for expand" do
    inst = described_class.new("")
    expect(inst.expand('foo' => 'bar')).to be_kind_of(String)
  end

  it "should accept anything that responds to #map for expand" do
    inst = described_class.new("")
    obj = Object.new
    def obj.map
      return [ yield("foo", "bar") ]
    end
    expect(inst.expand(obj)).to be_kind_of(String)
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
    expect(described_class.new("")).to eq(described_class.new(""))
  end

  it "should compare true to its pattern as string" do
    expect(described_class.new("")).to eq("")
  end

  it "should override #tokens" do
    expect(described_class.instance_method(:tokens).owner).not_to eq(URITemplate)
  end

  it "should override #type" do
    expect(described_class.instance_method(:type).owner).not_to eq(URITemplate)
  end

  it "should #try_convert an instance into it self" do
    inst = described_class.new("")
    expect(described_class.try_convert(inst)).to eq(inst)
  end

  it "should #try_convert a string into an instance" do
    expect(described_class.try_convert("")).to eq(described_class.new(""))
  end

  it "should refuse #try_covert for an arbitrary object" do
    expect(described_class.try_convert(Object.new)).to be_nil
  end

  it "should refuse #try_covert for an unrelated uritemplate" do
    o = Object.new
    def o.kind_of?(k)
      super || ( k == URITemplate )
    end
    expect(described_class.try_convert(o)).to be_nil
  end

  it "should #convert an instance into it self" do
    inst = described_class.new("")
    expect(described_class.convert(inst)).to eq(inst)
  end

  it "should #convert a string into an instance" do
    expect(described_class.convert("")).to eq(described_class.new(""))
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


RSpec.shared_examples "a uri template class with extraction" do

  it "should respond to extract" do
    expect(described_class.new("")).to respond_to(:extract)
  end

  it "should return nil if a pattern didn't match" do
    expect(described_class.new("x")).not_to extract.from("y")
  end

  it "should return a hash if a pattern did match" do
    expect(described_class.new("x")).to extract.from("x")
  end

  it "should return nil if passed nil" do
    expect(described_class.new("x").extract(nil)).to be_nil
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
    expect(described_class.new("x").extract("x"){|_| o }).to eq(o)
  end

end

RSpec.shared_examples "a string util helper" do

  it "escapes an empty string correctly" do
    expect(subject.escape_uri("")).to eq("")
    expect(subject.escape_url("")).to eq("")
  end

  it "escapes an all-ascii string correctly" do
    expect(subject.escape_uri("abcdef123")).to eq("abcdef123")
    expect(subject.escape_url("abcdef123")).to eq("abcdef123")
  end

  it "escapes a multibyte pct string correctly" do
    expect(subject.escape_uri("ü")).to eq("%C3%BC")
    expect(subject.escape_url("ü")).to eq("%C3%BC")
  end

  it "escapes a space correctly" do
    expect(subject.escape_uri(" ")).to eq("%20")
    expect(subject.escape_url(" ")).to eq("%20")
  end

  it "escapes a object with to_s correctly" do
    o = Object.new
    def o.to_s
      "o.to_s"
    end
    expect(subject.escape_uri(o)).to eq("o.to_s")
    expect(subject.escape_url(o)).to eq("o.to_s")
  end

  it "unescapes an empty string correctly" do
    expect(subject.unescape_uri("")).to eq("")
    expect(subject.unescape_url("")).to eq("")
  end

  it "unescapes an all-ascii string correctly" do
    expect(subject.unescape_uri("abcdef123")).to eq("abcdef123")
    expect(subject.unescape_url("abcdef123")).to eq("abcdef123")
  end

  it "unescapes a simple pct string correctly" do
    expect(subject.unescape_uri("%20%30%40")).to eq(" 0@")
    expect(subject.unescape_url("%20%30%40")).to eq(" 0@")
  end

  it "unescapes a plus correctly" do
    expect(subject.unescape_uri("+")).to eq("+")
    expect(subject.unescape_url("+")).to eq(" ")
  end

  it "unescapes a object with to_s correctly" do
    o = Object.new
    def o.to_s
      "o.to_s"
    end
    expect(subject.unescape_uri(o)).to eq("o.to_s")
    expect(subject.unescape_url(o)).to eq("o.to_s")
  end

  it "unescapes a single %" do
    expect(subject.unescape_uri("%")).to eq("%")
    expect(subject.unescape_url("%")).to eq("%")
  end

  it "unescapes a borked pct" do
    expect(subject.unescape_uri("%fg")).to eq("%fg")
    expect(subject.unescape_url("%fg")).to eq("%fg")
  end

  it "unescapes a too short pct" do
    expect(subject.unescape_uri("%f")).to eq("%f")
    expect(subject.unescape_url("%f")).to eq("%f")
  end
end
