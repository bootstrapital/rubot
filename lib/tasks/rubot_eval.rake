namespace :rubot do
  desc "Run Rubot evals (use TARGET=MyEval or rubot:eval[MyEval])"
  task :eval, [:target] do |_task, args|
    Rubot.load_eval_files(*ENV.fetch("LOAD", "").split(File::PATH_SEPARATOR))
    reports = Array(Rubot.run_eval(args[:target] || ENV["TARGET"] || ENV["EVAL"]))

    reports.each do |report|
      puts report.to_s
    end

    abort("Rubot evals failed") unless reports.all?(&:passed?)
  end
end
