# -*- encoding: utf-8 -*-

gem 'rspec-expectations'
require 'rspec-expectations'

module Arena


  class Result < Struct.new(:type, :time, :repetitions, :exception)

  end

  class CheckContext < Struct.new(:code, :exception)

    include RSpec::Matchers

    def reset!
      self.exception = nil
    end

    def check(ret, result)
      begin
        instance_exec(ret, result, &code)
      rescue Interrupt
        raise
      rescue Exception => e
        self.exception = e
        return false
      end
      return true
    end

  end

  class RunContext

    attr :arguments

    attr_accessor :repeat

    def initialize(*arguments, &block)
      @results = {}
      @expected = block
      @arguments = arguments
      @repeat = 1
    end

    def run(options = {}, &block)
      result = Result.new(:success, 0.0, repeat, nil)
      begin
        instance_exec(*arguments, &options[:before]) if options[:before]
        repeat.times do
          reset!
          time = Time.now
          ret = instance_exec(*arguments,&block)
          result.time += (Time.now - time)
          exp = CheckContext.new(@expected, nil)
          if !exp.check(ret, @results)
            result.type = :incorrect
            result.exception = exp.exception
            return result
          end
        end
        instance_exec(*arguments, &options[:after]) if options[:after]
      rescue Interrupt
        raise
      rescue Exception => e
        result.type = :error
        result.exception = e
      end
      return result
    end

  private

    def reset!
      @results = {}
    end

    def result(name = :value, value)
      @results[name] = value
    end

  end


  class Implementation

    attr_accessor :name, :code, :before, :after

    def initialize(name, options = {}, &block)
      self.name = name
      self.code = block
      self.before = options.fetch(:before){ proc{} }
      self.after = options.fetch(:after){ proc{} }
    end

  end

  class Contest

    attr_accessor :name, :spec, :subcontests

    NO_SPEC = proc{}.freeze

    def initialize(name, options = {}, &block)
      self.name = name
      self.arguments = []
      self.spec = Hash.new( NO_SPEC )
      self.subcontests = []
      repeat options.fetch(:repetitions){ 1 }
      instance_eval(&block)
    end

    def run_context(for_implementation)
      cont = RunContext.new(*arguments, &spec[for_implementation])
      cont.repeat = repeat
      return cont
    end

  private

    def arguments(*args)
      return @arguments if args.none?
      self.arguments = args
    end

    def arguments=(args)
      @arguments = args
    end

    def repeat(*args)
      return @repeat if args.none?
      @repeat = args[0]
    end

    def check(*args,&block)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      if args.any?
        args.each do |arg|
          self.spec[arg.to_sym] = block
        end
      else
        self.spec.default = block
      end
    end

    def subcontest(&block)

    end

  end

  class Group

    attr_accessor :name, :contests, :implementations, :groups

    def initialize(name, options = {}, &block)
      @name = name
      @contests = []
      @implementations = options.fetch(:implementations){ {} }
      @groups = []
      @repeat = options.fetch(:repeat){ 1 }
      instance_eval(&block)
    end

    def fight!(options = {})
      options = options.dup
      options[:reporter] ||= Reporter::Collector.new
      options[:reporter].start(self)
      fight(options)
      return options[:reporter].finish
    end

    def fight(options)
      reporter = options[:reporter]
      reporter.before_group(self)
      @groups.each do |group|
        group.fight(options)
      end
      @contests.each do |contest|
        reporter.before_contest(contest)
        @implementations.each do |name, impl|
          reporter.before_implementation(impl)
          reporter.report( contest, impl, contest.run_context(name).run(:before => impl.before, :after => impl.after, &impl.code) )
          reporter.after_implementation(impl)
        end
        reporter.after_contest(contest)
      end
      reporter.after_group(self)
    end

  private

    def group(name, &block)
      @groups << Group.new(name, :repeat => repeat, :implementations => implementations.dup, &block)
    end

    def repeat(*args)
      return @repeat if args.none?
      @repeat = args[0]
    end

    def implementation(*args, &block)
      impl = Implementation.new(*args,&block)
      @implementations[impl.name] = impl
    end

    def contest(name, options = {}, &block)
      @contests << Contest.new(name, {:repetitions => repeat }.merge(options), &block)
    end

  end

  class Reporter

    def start(main_group)
    end

    def report(contest, impl, result)
    end

    def finish
    end

    def before_group( _ )
    end

    def after_group( _ )
    end

    def before_implementation( _ )
    end

    def after_implementation( _ )
    end

    def before_contest( _ )
    end

    def after_contest( _ )
    end

    class Collector < self

      def initialize
        @results = []
      end

      def report(*args)
        @results << args
      end

      def finish
        return @results
      end

    end

    class Printer < self

      def initialize(io = STDOUT)
        @io = io
        @max_len = 0
        @indent = 0
        @implementations = []
        @footnotes = []
      end

      def start(main_group)
        collect!(main_group)
      end

      def finish
        @io << '-----------------------'
        @footnotes.each_with_index do |error, i|
          @io << "\n" << i+1 << ': ' << error.to_s
        end
      end

      def before_group(group)
        if @indent == 0
          @io << '╤ '
        else
          @io << '│ ' * ( @indent - 1) << '╞═╤ '
        end
        
        @io << group.name.ljust(@max_len - (@indent * 2) + 1 )
        
        if group.contests.any?
          @implementations.each do |name|
            @io << ' | ' << name.to_s.ljust(20)
          end
        end
        @io << "\n"
        @indent += 1
      end

      def after_group(group)
        @indent -= 1
        @io << '│ ' * @indent << '└ ' << group.name << "\n"
      end

      def before_contest(contest)
        @io << '│ ' * (@indent - 1) << '╞ ' << contest.name.ljust(@max_len - @indent)
      end

      def after_contest(contest)
        @io << "\n"
      end

      def report(contest, implemetation, result)
        @io << ' | '
        if result.type == :success
          @io << '%17.2f /s' % ( result.repetitions / result.time )
        elsif result.type == :incorrect
          @footnotes << result.exception
          @io << "incorrect result#{superscript @footnotes.size}".ljust(20)
        else
          @footnotes << result.exception
          @io << "throws exception#{superscript @footnotes.size}".ljust(20)
        end
      end

    private

      SUPERSCRIPTS = {
        '0' => '⁰',
        '1' => '¹',
        '2' => '²',
        '3' => '³',
        '4' => '⁴',
        '5' => '⁵',
        '6' => '⁶',
        '7' => '⁷',
        '8' => '⁸',
        '9' => '⁹'
      }

      def superscript(i)
        i.to_i.to_s.gsub(/\d/){|m| SUPERSCRIPTS[m.to_s] }
      end

      def collect!(group, indent = 0)
        @implementations |= group.implementations.keys
        @max_len = [@max_len, group.name.length + (indent * 2)].max
        group.groups.each do |subgroup|
          collect!(subgroup, indent + 1)
        end
        group.contests.each do |contest|
          @max_len = [@max_len, contest.name.length + (indent + 1) * 2].max
        end
      end

    end

  end

end