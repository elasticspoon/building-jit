require_relative "./base"

module Command
  class Init < Base
    DEFAULT_BRANCH = "main".freeze

    def run
      path = @args.fetch(0, @dir)

      root_path = expanded_pathname(path)
      git_path = root_path.join(".git")

      %w[objects refs/heads].each do |dir|
        FileUtils.mkdir_p(git_path.join(dir))
      rescue Errno::EACCES => e
        warn "fatal: #{e.message}"
        exit 1
      end

      refs = Refs.new(git_path)
      path = File.join("refs", "heads", DEFAULT_BRANCH)
      refs.update_head("ref: #{path}")

      puts "Initialized empty JIT repository in #{git_path}"
      exit 0
    end

    private

    def define_options
    end
  end
end
