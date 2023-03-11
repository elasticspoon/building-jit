require_relative './command/add'
require_relative './command/commit'
require_relative './command/init'
require_relative './command/status'

module Command
  Unknown = Class.new(StandardError)

  COMMANDS = {
    'init' => Init,
    'add' => Add,
    'commit' => Commit,
    'status' => Status
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
