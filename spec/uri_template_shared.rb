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

  it "should return not yield if a pattern didn't match" do
    called = false
    described_class.new("x").extract("y") do |match|
      called = true
    end
    called.should be_false
  end

  it "should yield a hash if a pattern did match" do
    called = false
    described_class.new("x").extract("x") do |match|
      called = true
      match.should be_kind_of(Hash)
    end
    called.should be_true
  end

  it "should return the result of the block" do
    o = Object.new
    described_class.new("x").extract("x"){|_| o }.should == o
  end

end
