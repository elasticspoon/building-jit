require 'fileutils'
require 'pathname'
require_relative './workspace'
require_relative './database'

command = ARGV.shift

case command
when 'init'
	path = ARGV.fetch(0, Dir.getwd)


	root_path = Pathname.new(File.expand_path(path))
	git_path = root_path.join('.git')

	['objects', 'refs'].each do |dir|
		begin 
			FileUtils.mkdir_p(git_path.join(dir))
		rescue Errno::EACCES => error
			$stderr.puts "fatal #{error.message}"
			exit 1
		end
	end

	puts "Initialized empty JIT repository in #{git_path}"
	exit 0
when 'commit'
	root_path = Pathname.new(Dir.getwd)
	git_path = root_path.join('.git')
	db_path = git_path.join('objects')

	workspace = Workspace.new(root_path)
	database = Database.new(db_path)

	entries = workspace.list_files.each do |path|
		data = workspace.read_file(path)
		blob = Blob.new(data)

		database.store(blob)

		Entry.new(path, blob.oid)
	end

	tree = Tree.new(entries)
	database.store(tree)

	puts "tree: #{tree.oid}" 
else 
	$stderr.puts "jit: '#{command}' is not a JIT command."
	exit 1
end

