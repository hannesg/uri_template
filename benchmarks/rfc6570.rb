require 'bundler/setup'

$LOAD_PATH << File.dirname(__FILE__)

Bundler.require(:default, :development, :benchmark)

require 'arena'

require 'addressable/template'

tests = {}

['spec-examples.json', 'extended-tests.json'].each do |file_name|

  f = File.new(File.expand_path(file_name, File.join(File.dirname(__FILE__),'..','spec','uritemplate-test')))

  data = MultiJson.load( f.read )
  tests.merge!(data)

end

a = Arena::Group.new('main') do

  repeat 10_000

  group "Expansion" do

    implementation(:addressable) do |tpl,variables|
      Addressable::Template.new(tpl).expand(variables)
    end

    implementation(:rfc6570) do |tpl, variables|
      URITemplate.new(tpl).expand(variables)
    end

    implementation(:'rfc6570+', before: ->(tpl, _){ @tpl = URITemplate.new(tpl) }) do |_, variables|
      @tpl.expand(variables)
    end

    tests.each do |label, spec|

      group label do
        variables = spec['variables']

        spec['testcases'].each do |template, correct|

          contest template do

            arguments template, variables

            check do |result|
              expect( correct.to_s ).to include(result)
            end

          end

        end
      end
    end

  end

  group "Extraction" do

    implementation(:addressable) do |tpl,uri|
      Addressable::Template.new(tpl).extract(uri)
    end

    implementation(:rfc6570) do |tpl, uri|
      URITemplate.new(tpl).extract(uri)
    end

    implementation(:'rfc6570+', before: ->(tpl, _){ @tpl = URITemplate.new(tpl) }) do |_, uri|
      @tpl.extract(uri)
    end

    tests.each do |label, spec|

      group label do
        variables = spec['variables']

        spec['testcases'].each do |template, uris|

          Array(uris).each do |uri|

            contest "#{template} - #{uri}" do

              arguments template, uri

              check do |result|
                expect( result ).to be_a(Hash)
                expect( URITemplate.new(template).expand(result) ).to eql(uri)
              end

              check :addressable do |result|
                expect( result ).to be_a(Hash)
                expect( Addressable::Template.new(template).expand(result).to_s ).to eql(uri)
              end

            end

          end

        end
      end
    end

  end

end

a.fight!( reporter: Arena::Reporter::Printer.new )