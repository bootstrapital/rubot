# frozen_string_literal: true

module Rubot
  class Eval
    Fixture = Struct.new(:name, :input, :subject, :context, :expected, :metadata, :block, keyword_init: true)
    Threshold = Struct.new(:score_name, :min, :max, :equals, keyword_init: true)

    class Report
      attr_reader :eval_class, :results

      def initialize(eval_class:, results:)
        @eval_class = eval_class
        @results = results
      end

      def passed?
        results.all?(&:passed?)
      end

      def total_count
        results.length
      end

      def passed_count
        results.count(&:passed?)
      end

      def failed_count
        total_count - passed_count
      end

      def to_h
        {
          eval_class: eval_class.name,
          passed: passed?,
          total_count: total_count,
          passed_count: passed_count,
          failed_count: failed_count,
          results: results.map(&:to_h)
        }
      end

      def to_s
        lines = []
        lines << "#{eval_class.name}: #{passed? ? 'PASS' : 'FAIL'} (#{passed_count}/#{total_count})"
        results.each do |result|
          status = result.passed? ? "PASS" : "FAIL"
          score_summary = result.scores.map { |name, value| "#{name}=#{format('%.3f', value)}" }.join(", ")
          lines << "- #{result.fixture_name}: #{status}#{score_summary.empty? ? '' : " [#{score_summary}]"}"
          result.failures.each do |failure|
            lines << "  #{failure}"
          end
        end
        lines.join("\n")
      end
    end

    class Result
      attr_reader :fixture_name, :run, :scores, :failures, :metadata

      def initialize(fixture_name:, run:, scores:, failures:, metadata:)
        @fixture_name = fixture_name
        @run = run
        @scores = scores
        @failures = failures
        @metadata = metadata
      end

      def passed?
        failures.empty?
      end

      def to_h
        {
          fixture_name: fixture_name,
          passed: passed?,
          run_id: run.id,
          run_status: run.status,
          output: run.output,
          scores: scores,
          failures: failures,
          metadata: metadata
        }
      end
    end

    class Context
      attr_reader :eval, :fixture, :run, :output, :expected, :metadata

      def initialize(eval:, fixture:, run:)
        @eval = eval
        @fixture = fixture
        @run = run
        @output = run.output
        @expected = fixture[:expected]
        @metadata = fixture[:metadata]
      end
    end

    class << self
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@rubot_eval_target, @rubot_eval_target)
        subclass.instance_variable_set(:@rubot_eval_fixtures, fixtures.dup)
        subclass.instance_variable_set(:@rubot_eval_scores, scores.dup)
        subclass.instance_variable_set(:@rubot_eval_thresholds, thresholds.dup)
      end

      def target(runnable = nil)
        @rubot_eval_target = runnable if runnable
        @rubot_eval_target
      end

      def fixture(name, input: nil, subject: nil, context: {}, expected: nil, metadata: {}, tags: [], &block)
        fixtures << Fixture.new(
          name: name.to_sym,
          input: input,
          subject: subject,
          context: context,
          expected: expected,
          metadata: metadata.merge(tags: Array(tags)),
          block: block
        )
      end

      def score(name, &block)
        raise ArgumentError, "score requires a block" unless block

        scores[name.to_sym] = block
      end

      def assert_threshold(score_name, min: nil, max: nil, equals: nil)
        thresholds << Threshold.new(score_name: score_name.to_sym, min:, max:, equals:)
      end

      def fixtures
        @rubot_eval_fixtures ||= []
      end

      def scores
        @rubot_eval_scores ||= {}
      end

      def thresholds
        @rubot_eval_thresholds ||= []
      end

      def run(fixtures: nil, tags: nil)
        new.run(fixtures:, tags:)
      end
    end

    def run(fixtures: nil, tags: nil)
      raise Rubot::ExecutionError, "#{self.class.name} must define a target" unless self.class.target

      selected_fixtures = self.class.fixtures
      if fixtures
        fixture_names = Array(fixtures).map(&:to_sym)
        selected_fixtures = selected_fixtures.select { |fixture| fixture_names.include?(fixture.name) }
      end

      if tags
        tags = Array(tags).map(&:to_sym)
        selected_fixtures = selected_fixtures.select do |fixture|
          f_tags = Array(fixture.metadata[:tags]).map(&:to_sym)
          (f_tags & tags).any?
        end
      end

      return nil if selected_fixtures.empty?

      results = selected_fixtures.map do |fixture_definition|
        execute_fixture(fixture_definition)
      end

      Report.new(eval_class: self.class, results: results)
    end

    private

    def execute_fixture(fixture_definition)
      fixture = resolve_fixture(fixture_definition)
      run = execute_target(fixture)
      context = Context.new(eval: self, fixture:, run:)
      scores = evaluate_scores(context)
      failures = evaluate_failures(context, scores)
      Result.new(
        fixture_name: fixture[:name],
        run: run,
        scores: scores,
        failures: failures,
        metadata: fixture[:metadata]
      )
    end

    def resolve_fixture(fixture_definition)
      base = {
        name: fixture_definition.name,
        input: fixture_definition.input || {},
        subject: fixture_definition.subject,
        context: fixture_definition.context || {},
        expected: fixture_definition.expected,
        metadata: fixture_definition.metadata || {}
      }

      return base unless fixture_definition.block

      dynamic = instance_exec(&fixture_definition.block) || {}
      base.merge(Rubot::HashUtils.symbolize(dynamic))
    end

    def execute_target(fixture)
      runnable = self.class.target

      if runnable.is_a?(Class) && runnable < Rubot::Operation
        runnable.launch(
          payload: fixture[:input],
          subject: fixture[:subject],
          context: fixture[:context],
          trigger: fixture[:trigger]
        )
      else
        Rubot.run(runnable, input: fixture[:input], subject: fixture[:subject], context: fixture[:context])
      end
    end

    def evaluate_scores(context)
      return default_scores(context) if self.class.scores.empty?

      self.class.scores.each_with_object({}) do |(name, evaluator), memo|
        value = invoke_evaluator(evaluator, context)
        memo[name] = normalize_score(value)
      end
    end

    def default_scores(context)
      return {} if context.expected.nil?

      { output_match: context.output == context.expected ? 1.0 : 0.0 }
    end

    def evaluate_failures(context, scores)
      failures = []
      failures << "run status was #{context.run.status}" unless context.run.completed?
      failures.concat(threshold_failures(scores))
      failures << "expected output #{context.expected.inspect}, got #{context.output.inspect}" if expected_mismatch?(context, scores)
      failures
    end

    def threshold_failures(scores)
      self.class.thresholds.filter_map do |threshold|
        score = scores[threshold.score_name]
        next "missing score #{threshold.score_name}" if score.nil?
        next "#{threshold.score_name} was #{score}, expected #{threshold.equals}" unless threshold.equals.nil? || score == threshold.equals
        next "#{threshold.score_name} was #{score}, expected >= #{threshold.min}" unless threshold.min.nil? || score >= threshold.min
        next "#{threshold.score_name} was #{score}, expected <= #{threshold.max}" unless threshold.max.nil? || score <= threshold.max

        nil
      end
    end

    def expected_mismatch?(context, scores)
      return false if context.expected.nil?
      return false if scores[:output_match] == 1.0
      return false if self.class.scores.key?(:output_match)

      context.output != context.expected
    end

    def invoke_evaluator(evaluator, context)
      evaluator.arity == 1 ? evaluator.call(context) : instance_exec(context, &evaluator)
    end

    def normalize_score(value)
      return 1.0 if value == true
      return 0.0 if value == false

      Float(value)
    rescue ArgumentError, TypeError
      raise Rubot::ValidationError, "Eval scores must be numeric or boolean"
    end
  end

  class << self
    def load_eval_files(*patterns)
      patterns = patterns.flatten.compact.reject(&:empty?)
      patterns = default_eval_file_patterns if patterns.empty?

      patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq.sort.each do |path|
        require File.expand_path(path)
      end
    end

    def run_eval(eval_or_name = nil, fixtures: nil, tags: nil)
      reports = resolve_evals(eval_or_name).map { |klass| klass.run(fixtures: fixtures, tags: tags) }.compact
      reports.length == 1 && eval_or_name ? reports.first : reports
    end

    private

    def default_eval_file_patterns
      [
        "evals/**/*.rb",
        "test/support/evals/**/*.rb"
      ]
    end

    def resolve_evals(eval_or_name)
      return discover_evals if eval_or_name.nil? || eval_or_name == ""

      return [eval_or_name] if eval_or_name.is_a?(Class) && eval_or_name < Rubot::Eval

      [eval_or_name.to_s.constantize]
    rescue NameError => e
      raise ExecutionError, "Unable to resolve eval #{eval_or_name}: #{e.message}"
    end

    def discover_evals
      ObjectSpace.each_object(Class).select do |klass|
        klass < Rubot::Eval && klass.name && !klass.fixtures.empty?
      end.sort_by(&:name)
    end
  end
end
