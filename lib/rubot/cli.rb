# frozen_string_literal: true

require "optparse"
require "json"

module Rubot
  class CLI
    def self.start(args)
      new(args).run
    end

    def initialize(args)
      @args = args
      @options = {}
    end

    def run
      parse_options
      command = @args.shift
      case command
      when "list" then list_operations
      when "describe" then describe_operation(@args.shift)
      when "run" then run_operation(@args.shift, @args.shift)
      when "status" then check_status(@args.shift)
      when "tail" then tail_run(@args.shift)
      when "eval" then run_evals(@args.shift)
      when "help", nil then show_help
      else
        puts "Unknown command: #{command}"
        show_help
        exit 1
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: rubot [command] [options]"

        opts.on("-f", "--format FORMAT", "Output format (text, json)") do |f|
          @options[:format] = f
        end

        opts.on("-l", "--load PATTERN", "Glob pattern to load eval files") do |l|
          @options[:load] = l
        end

        opts.on("-t", "--tag TAG", "Filter evals by tag") do |t|
          (@options[:tags] ||= []) << t
        end

        opts.on("--fixture NAME", "Filter evals by fixture name") do |n|
          (@options[:fixtures] ||= []) << n
        end

        opts.on("-h", "--help", "Prints this help") do
          show_help
          exit
        end
      end.parse!(@args)
    end

    def run_evals(target = nil)
      load_rails_environment
      Rubot.load_eval_files(@options[:load]) if @options[:load]

      reports = Array(Rubot.run_eval(target, fixtures: @options[:fixtures], tags: @options[:tags]))

      if @options[:format] == "json"
        puts JSON.pretty_generate(reports.map(&:to_h))
      else
        reports.each do |report|
          puts report.to_s
        end
      end

      exit(1) if reports.empty? || !reports.all?(&:passed?)
    end

    def list_operations
      load_rails_environment
      ops = Rubot::Engine.operations.keys
      puts "Registered Operations:"
      ops.each { |name| puts "  - #{name}" }
    end

    def describe_operation(name)
      raise "Operation name required" unless name
      load_rails_environment
      op = Rubot::Engine.operations[name.to_sym] || raise("Operation not found: #{name}")
      puts JSON.pretty_generate(op.discover)
    end

    def run_operation(name, payload_json)
      raise "Operation name required" unless name
      load_rails_environment
      op = Rubot::Engine.operations[name.to_sym] || raise("Operation not found: #{name}")
      payload = payload_json ? JSON.parse(payload_json) : {}
      
      puts "Launching #{name}..."
      run = op.launch(payload: payload)
      puts "Run ID: #{run.id}"
      puts "Status: #{run.status}"
      
      if run.completed?
        puts "Output:"
        puts JSON.pretty_generate(run.output)
      end
    end

    def check_status(run_id)
      raise "Run ID required" unless run_id
      load_rails_environment
      run = Rubot.store.load_run(run_id) || raise("Run not found: #{run_id}")
      
      puts "Run ID: #{run.id}"
      puts "Name:   #{run.name}"
      puts "Status: #{run.status}"
      puts "Step:   #{run.current_step}"
      
      if run.terminal?
        puts "Completed At: #{run.completed_at}"
        puts "Output:"
        puts JSON.pretty_generate(run.output) if run.output
        puts "Error:"
        puts JSON.pretty_generate(run.error) if run.error
      end
    end

    def tail_run(run_id)
      raise "Run ID required" unless run_id
      load_rails_environment

      puts "Tailing run #{run_id}... (Ctrl+C to stop)"
      last_event_count = 0
      loop do
        run = Rubot.store.load_run(run_id) || raise("Run not found: #{run_id}")
        events = run.events

        if events.length > last_event_count
          events[last_event_count..].each do |event|
            ts = event.timestamp.is_a?(String) ? event.timestamp : event.timestamp&.iso8601
            puts "[#{ts}] #{event.type} @ #{event.step_name}"
            puts JSON.pretty_generate(event.payload) if event.payload && event.payload.any?
          end
          last_event_count = events.length
        end

        break if run.terminal?
        sleep 1
      end
    end

    def show_help
      puts <<~HELP
        Rubot CLI

        Usage: rubot [command] [options]

        Commands:
          list                      List all registered operations
          describe [operation]      Show discovery info for an operation
          run [operation] [json]    Launch an operation synchronously
          status [run_id]           Check status and output of a run
          tail [run_id]             Watch the event log of a run
          eval [target]             Run evals
          help                      Show this help

        Options:
          -f, --format FORMAT       Output format (text, json)
          -l, --load PATTERN        Glob pattern to load eval files
          -h, --help                Show this help
      HELP
    end

    def load_rails_environment
      return if defined?(Rails)

      # Attempt to load Rails if we are in a Rails app
      config_ru = File.expand_path("config.ru", Dir.pwd)
      if File.exist?(config_ru)
        require File.expand_path("config/environment", Dir.pwd)
      end
    end
  end
end
