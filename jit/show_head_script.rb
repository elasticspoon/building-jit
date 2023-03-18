require 'pathname'
require_relative './lib/repository'

repo = Repository.new(Pathname.new(Dir.getwd).join('.git'))

head_oid = repo.refs.read_head
commit = repo.database.load(head_oid)

def show_tree(repo, oid, prefix=Pathname.new(''))
  tree = repo.database.load(oid)

  # puts tree.inspect

  tree.entries.each do |name, entry|
    path = prefix.join(name)
    if entry.tree?
      show_tree(repo, entry.oid, path)
    else
      mode = entry.mode.to_s(8)
      puts "#{mode} #{entry.oid} #{path}"
    end
  end
end

show_tree(repo, commit.tree)
