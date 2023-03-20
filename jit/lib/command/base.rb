require 'pathname'
require_relative '../repository'
require_relative '../color'

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
    end

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def puts(string='')
      $stdout.puts string if @env['DEBUG']
      @stdout.puts(string)
    end

    def warn(string='')
      @stderr.puts(string)
    end

    def exit(status=0)
      @status = status
      throw :exit
    end

    def execute
      catch(:exit) { run }
    end

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join('.git'))
    end

    def fmt(string, style)
      @stdout.isatty ? Color.format(string, style) : string
    end

    def workspace_path
      repo.workspace.pathname
    end
  end
end
