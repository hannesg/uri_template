# -*- encoding : utf-8 -*-
describe URITemplate::Utils do

  describe "pure escape + native encoding", :if => "".respond_to?(:encoding) do

    subject do
      o = Object.new
      o.extend(URITemplate::Utils::Escaping::Pure)
      o.extend(URITemplate::Utils::StringEncoding::Encode)
      o
    end

    it_should_behave_like "a string util helper"

    it "doesn't say it uses escape_utils" do
      should_not be_using_escape_utils
    end

    it "converts to ascii" do
      result = subject.to_ascii("foo".encode(Encoding::UTF_8))
      result.encoding.should == Encoding::ASCII
      result.should == "foo".encode(Encoding::ASCII)
    end

    it "converts to utf8" do
      result = subject.to_utf8("foo".encode(Encoding::ASCII))
      result.encoding.should == Encoding::UTF_8
      result.should == "foo".encode(Encoding::UTF_8)
    end

    it "unescapes a multibyte pct string correctly" do
      subject.unescape_uri("%C3%BC").should == "ü"
      subject.unescape_url("%C3%BC").should == "ü"
    end

    it "ignores case for pct encodes" do
      subject.unescape_uri("%c3%Bc").should == "ü"
      subject.unescape_url("%c3%Bc").should == "ü"
    end
  end

  describe "pure escape + fallback encoding" do

    subject do
      o = Object.new
      o.extend(URITemplate::Utils::Escaping::Pure)
      o.extend(URITemplate::Utils::StringEncoding::Fallback)
      o
    end

    it_should_behave_like "a string util helper"

    it "doesn't say it uses escape_utils" do
      should_not be_using_escape_utils
    end

    it "passes thru to_ascii" do
      subject.to_ascii("foo").should == "foo"
    end

    it "converts to utf8" do
      subject.to_utf8("foo").should == "foo"
    end
  end

  describe "escape_utils + native encoding" , :if => URITemplate::Utils.using_escape_utils? && "".respond_to?(:encoding) do

    subject do
      o = Object.new
      o.extend(URITemplate::Utils::Escaping::EscapeUtils)
      o.extend(URITemplate::Utils::StringEncoding::Encode)
      o
    end

    it_should_behave_like "a string util helper"

    it "says it uses escape_utils" do
      should be_using_escape_utils
    end

    it "converts to ascii" do
      result = subject.to_ascii("foo".encode(Encoding::UTF_8))
      result.encoding.should == Encoding::ASCII
      result.should == "foo".encode(Encoding::ASCII)
    end

    it "converts to utf8" do
      result = subject.to_utf8("foo".encode(Encoding::ASCII))
      result.encoding.should == Encoding::UTF_8
      result.should == "foo".encode(Encoding::UTF_8)
    end

    it "unescapes a multibyte pct string correctly" do
      subject.unescape_uri("%C3%BC").should == "ü"
      subject.unescape_url("%C3%BC").should == "ü"
    end

    it "ignores case for pct encodes" do
      subject.unescape_uri("%c3%Bc").should == "ü"
      subject.unescape_url("%c3%Bc").should == "ü"
    end
  end

  describe "escape_utils + fallback encoding" , :if => URITemplate::Utils.using_escape_utils? do

    subject do
      o = Object.new
      o.extend(URITemplate::Utils::Escaping::EscapeUtils)
      o.extend(URITemplate::Utils::StringEncoding::Fallback)
      o
    end

    it_should_behave_like "a string util helper"

    it "says it uses escape_utils" do
      should be_using_escape_utils
    end

    it "passes thru to_ascii" do
      subject.to_ascii("foo").should == "foo"
    end

    it "converts to utf8" do
      subject.to_utf8("foo").should == "foo"
    end
  end

  describe URITemplate::RegexpEnumerator do

    subject{URITemplate::RegexpEnumerator}

    it "yields if called with block" do
      enum = subject.new(/b/)
      expect{|b| enum.each("aba",&b) }.to yield_successive_args("a", MatchData, "a")
    end

    it "returns an iterator if called without block" do
      enum = subject.new(/b/).each("aba")
      enum.should be_a(Enumerable)
      expect{|b| enum.each(&b) }.to yield_successive_args("a", MatchData, "a")
    end

    it "should yield the rest if match is empty" do
      enum = subject.new(//)
      expect{|b| enum.each("foo",&b) }.to yield_successive_args(MatchData, "foo")
    end

    it "should raise if match is empty and told to do so" do
      enum = subject.new(//, :rest => :raise)
      expect{
        enum.each("foo"){}
      }.to raise_error(/matched an empty string/)
    end

  end

  it "should raise on basic object", :if => (defined? BasicObject) do
    expect do
      URITemplate::Utils.object_to_param(BasicObject.new)
    end.to raise_error(URITemplate::Unconvertable)
  end

  it "should raise when an object is not convertable to string" do
    obj = Object.new
    class << obj
      undef to_s
    end
    expect do
      URITemplate::Utils.object_to_param(obj)
    end.to raise_error(URITemplate::Unconvertable)
  end

end
