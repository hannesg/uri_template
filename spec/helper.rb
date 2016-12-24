# -*- encoding : utf-8 -*-
require 'bundler'
Bundler.setup(:default,:development)

if $0 !~ /mutant\z/
  # using coverage in mutant is pointless
  begin
    require 'simplecov'
    require 'simplecov-console'
    require 'coveralls'
    # the console output needs this to work:
    ROOT = File.expand_path('../lib',File.dirname(__FILE__))
    SimpleCov.start do
      add_filter '/spec'
      formatter SimpleCov::Formatter::MultiFormatter[
        Coveralls::SimpleCov::Formatter,
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::Console
      ]
      refuse_coverage_drop
      nocov_token "nocov"
    end
  rescue LoadError
    warn 'Not using simplecov.'
  end
end

Bundler.require(:default,:development)

require 'uri_template'

unless URITemplate::Utils.using_escape_utils?
  warn 'Not using escape_utils.'
end
if RUBY_DESCRIPTION =~ /\Ajruby/ and "".respond_to? :force_encoding
  # jruby produces ascii encoded json hashes :(
  def force_all_utf8(x)
    if x.kind_of? String
      return x.dup.force_encoding("UTF-8")
    elsif x.kind_of? Array
      return x.map{|a| force_all_utf8(a) }
    elsif x.kind_of? Hash
      return Hash[ x.map{|k,v| [force_all_utf8(k),force_all_utf8(v)]} ]
    else
      return x
    end
  end
else
  def force_all_utf8(x)
    return x
  end
end

class URITemplate::ExpansionMatcher

  def initialize( variables, expected = nil )
    @variables = variables
    @expected = expected
  end

  def matches?( actual )
    @actual = actual
    s = @actual.expand(@variables)
    # only in 1.8.7 Array("") is []
    ex = @expected == "" ? [""] : Array(@expected)
    return ex.any?{|e| e === s }
  end

  def to(expected)
    @expected = expected
    return self
  end

  def failure_message
    return [@actual.inspect, ' should not expand to ', @actual.expand(@variables).inspect ,' but ', @expected.inspect, ' when given the following variables: ',"\n", @variables.inspect ].join
  end

end

class URITemplate::PartialExpansionMatcher

  def initialize( variables, expected = nil )
    @variables = variables
    @expected = Array(expected)
  end

  def matches?( actual )
    @actual = actual
    s = @actual.expand_partial(@variables)
    return Array(@expected).any?{|e| e == s }
  end

  def to(expected)
    @expected = Array(expected)
    return self
  end

  def failure_message
    return [@actual.to_s, ' should not partially expand to ', @actual.expand_partial(@variables).to_s.inspect ,' but ', Array(@expected).map(&:to_s).to_s, ' when given the following variables: ',"\n", @variables.inspect ].join
  end

end
class URITemplate::ExtractionMatcher

  def initialize( variables = nil, uri = '', fuzzy = true )
    @variables = variables.nil? ? variables : Hash[ variables.map{|k,v| [k.to_s, v]} ]
    @fuzzy = fuzzy
    @uri = uri
  end

  def from( uri )
    @uri = uri
    return self
  end

  def matches?( actual )
    @message = []
    v = actual.extract(@uri)
    if v.nil?
      @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but didn\' extract anything.']
      return false
    end
    if @variables.nil?
      return true
    end
    if !@fuzzy
      @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but got ',v.inspect]
      return @variables == v
    else
      tpl_variable_names = actual.variables
      diff = []
      @variables.each do |key,val|
        if tpl_variable_names.include? key
          if val != v[key]
            diff << [key, val, v[key] ]
          end
        end
      end
      v.each do |key,val|
        if !@variables.key? key
          diff << [key, nil, val]
        end
      end
      if !diff.empty?
        @message = [actual.inspect,' should extract ',@variables.inspect,' from ',@uri.inspect,' but got ',v.inspect]
        diff.each do |key, should, actual|
          @message << "\n\t" << key << ":\tshould: " << should.inspect << ", is: " << actual.inspect
        end
      end
      return diff.empty?
    end
  end

  def failure_message
    return @message.join
  end

end

RSpec::Matchers.class_eval do

  def expand(variables = {})
    return URITemplate::ExpansionMatcher.new(variables)
  end

  def expand_partially(variables = {})
    return URITemplate::PartialExpansionMatcher.new(variables)
  end

  def expand_to( variables,expected )
    return URITemplate::ExpansionMatcher.new(variables, expected)
  end

  def extract( *args )
    return URITemplate::ExtractionMatcher.new(*args)
  end

  def extract_from( variables, uri)
    return URITemplate::ExtractionMatcher.new(variables, uri)
  end
end

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # This allows you to limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata. When nothing
  # is tagged with `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include `:focus`
  # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  config.filter_run_when_matching :focus

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  config.disable_monkey_patching!

  # This setting enables warnings. It's recommended, but in some cases may
  # be too noisy due to issues in dependencies.
  #config.warnings = true

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the n slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 5

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed
end
