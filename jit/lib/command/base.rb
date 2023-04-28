require "pathname"
require_relative "../repository"
require_relative "../revision"
require_relative "../color"
require_relative "../pager"

module Command
  class Base
    attr_reader :status

    def initialize(dir, env, args, stdin, stdout, stderr)
      @dir = dir
      @env = env
      @args = args
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @isatty = @stdout.isatty
    end

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def puts(string = "")
      $stdout.puts string if @env["DEBUG"]
      @stdout.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def warn(string = "")
      @stderr.puts(string)
    end

    def exit(status = 0)
      @status = status
      throw :exit
    end

    def execute
      catch(:exit) { run }

      return unless defined? @pager

      @stdout.close_write
      @pager.wait
    end

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join(".git"))
    end

    def fmt(string, style)
      @isatty ? Color.format(string, style) : string
    end

    def workspace_path
      repo.workspace.pathname
    end

    def setup_pager
      return if defined? @pager
      return unless @isatty

      @pager = Pager.new(@env, @stdout, @stderr)
      @stdout = @pager.input
    end
  end
end
