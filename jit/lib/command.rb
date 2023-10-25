require_relative 'command/add'
require_relative 'command/commit'
require_relative 'command/init'
require_relative 'command/status'
require_relative 'command/diff'
require_relative 'command/branch'
require_relative 'command/checkout'
require_relative 'command/log'

module Command
  Unknown = Class.new(StandardError)

  COMMANDS = {
    'init' => Init,
    'add' => Add,
    'commit' => Commit,
    'status' => Status,
    'diff' => Diff,
    'branch' => Branch,
    'checkout' => Checkout,
    'log' => Log
  }

  def self.execute(dir, env, argv, stdin, stdout, stderr)
    name = argv.shift
    args = argv

    raise Unknown, "'#{name} is not a jit command." unless COMMANDS.key?(name)

    command_class = COMMANDS[name]
    command = command_class.new(dir, env, args, stdin, stdout, stderr)
    command.execute

    command
  end
end
