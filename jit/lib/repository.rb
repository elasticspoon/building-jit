require_relative './database'
require_relative './index'
require_relative './refs'
require_relative './workspace'
require_relative './repository/status'
require_relative './repository/migration'
require_relative './repository/inspector'

class Repository
  def initialize(git_path)
    @git_path = git_path
  end

  def database
    @database ||= Database.new(@git_path.join('objects'))
  end

  def index
    @index ||= Index.new(@git_path.join('index'))
  end

  def refs
    @refs ||= Refs.new(@git_path)
  end

  def workspace
    @workspace ||= Workspace.new(@git_path.dirname)
  end

  def untracked_files
    workspace.list_files.filter_map do |path|
      index.top_untracked(path)
    end.sort
  end

  def status
    Status.new(self)
    # @status ||= Status.new
  end

  def migration(tree_diff)
    Migration.new(self, tree_diff)
  end
end
