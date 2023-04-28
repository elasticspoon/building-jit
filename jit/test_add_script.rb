require "fileutils"
require "pathname"
require "stringio"

require_relative "./lib/command"
require_relative "./lib/index"

repo_dir = File.expand_path("tmp_repo", __dir__)
io = StringIO.new
env = {}

argv = ["init", repo_dir]
commands = [Dir.getwd, env, argv, io, io, io]

cmd = Command.execute(*commands)
puts "init: #{cmd.status}"
# puts Dir.exist?('home/bandito/Documents/jit/jit/tmp_repo/.git')

path = File.join(repo_dir, "hello.txt")
flags = File::RDWR | File::CREAT
File.open(path, flags) { |f| f.puts "hello" }

commands[2] = ["add", "hello.txt"]
commands[0] = repo_dir

cmd = Command.execute(*commands)
puts "add: #{cmd.status}"

index_path = Pathname.new(repo_dir).join(".git", "index")
index = Index.new(index_path)
index.load

index.each_entry do |entry|
  puts [entry.mode.to_s(8), entry.oid, entry.path].join(" ")
end

commands[1] = {
  "GIT_AUTHOR_NAME" => "Ben Dover",
  "GIT_AUTHOR_EMAIL" => "email@example.com"
}
commands[3] = StringIO.new("commit message")
commands[2] = ["commit"]

cmd = Command.execute(*commands)
puts "commit: #{cmd.status}"

FileUtils.rm_rf(repo_dir)
