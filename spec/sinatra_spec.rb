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

describe URITemplate::SinatraExtension do

  begin
    require 'sinatra'
  rescue LoadError
    pending "Sinatra not installed. Bundle with `bundle install development_sinatra`."
    next
  end

  require 'rack'

  let(:app) do
    c = Class.new(Sinatra::Base)
    c.register(URITemplate::SinatraExtension)
    c
  end

  let(:instance) do
    app.new!
  end

  def route(pattern, *args,&block)
    app.class_eval do
      return route('GET', pattern, *args) do |*args2|
        @params_on_call = params.dup
        @args_on_call = args2
        @found_pattern = pattern
        next block.call(*args2) if block
        next 200
      end
    end
  end

  def call(env,*args)
    if( !env.kind_of? Hash )
      env = Rack::MockRequest.env_for(env,*args)
    end
    begin
      return @response = instance.call!(env)
    rescue => e
      @exception = e
    end
  end

  def params
    instance.instance_variable_get(:@params_on_call)
  end

  def args
    instance.instance_variable_get(:@args_on_call)
  end

  def pattern
    instance.instance_variable_get(:@found_pattern)
  end

  describe "routing" do

    it "should work" do

      route URITemplate.new('/foo/{foo}')

      call '/foo/bar'

      params['foo'].should == 'bar'
      params['captures'].should == ['bar']
      args.should == ['bar']

    end

    it "should work with multiple variables" do

      route URITemplate.new('/{bar}/{foo}')

      call '/rab/oof'

      args.should == ['rab','oof']

    end

    it "should not break plain strings" do

      route "/foo/:foo"

      call "/foo/bar"

      args.should == ['bar']

    end

    describe "given a route with a query" do

      before(:each) do
        route URITemplate.new('/{bar}/{foo}{?argz*}')
      end

      it "should nil if no queries is given" do
        call '/rab/oof'
        args.should == ['rab','oof',nil]
      end

      it "should contain the query args if given" do
        call '/rab/oof?a=b'
        args.should == ['rab','oof',{'a'=>'b'}]
      end

    end

  end

end
