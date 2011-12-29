describe URITemplate::Colon do

  it "should work with simple expressions" do

    tpl = URITemplate.new(:colon, '/foo/:bar/')

    tpl.expand('bar'=>'baz').should == '/foo/baz/'

  end

  it "should work with bracketed expressions" do

    tpl = URITemplate.new(:colon, '/foo/{:bar}a/')

    tpl.expand('bar'=>'baz').should == '/foo/baza/'

  end

  it "should extract as expected" do

    tpl = URITemplate.new(:colon, '/foo/{:bar}a/')

    tpl.extract('/foo/baza/').should == {'bar'=>'baz'}

  end

  it "should return nil if not matchable" do

    tpl = URITemplate.new(:colon, '/foo/{:bar}a/')

    tpl.extract('/foo/foo/').should == nil

  end

end
