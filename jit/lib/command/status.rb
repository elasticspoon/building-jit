require_relative './base'
require_relative '../sorted_hash'

module Command
  class Status < Base
    PORCELAIN_STATUS = {
      added: 'A',
      deleted: 'D',
      modified: 'M'
    }.freeze

    LONG_STATUS = {
      added: 'new file:',
      deleted: 'deleted:',
      modified: 'modified:'
    }.freeze

    LABEL_WIDTH = 12

    def run
      @stats = {}
      @untracked = SortedSet.new
      @changed = SortedSet.new
      @changes = {}
      @workspace_changes = SortedHash.new
      @index_changes = SortedHash.new

      repo.index.load_for_update

      scan_workspace
      load_head_tree
      check_index_entries
      collect_deleted_head_files

      repo.index.write_updates

      print_results

      exit 0
    end

    private

    def collect_deleted_head_files
      @head_tree.each_key do |path|
        record_change(path, @index_changes, :deleted) unless repo.index.tracked_file?(path)
      end
    end

    def print_results
      if @args.first == '--porcelain'
        print_porcelain_format
      else
        print_long_format
      end
    end

    def print_porcelain_format
      @changed.each { |path| puts "#{status_for_path(path)} #{path}" }
      @untracked.each { |path| puts "?? #{path}" }
    end

    def print_long_format
      print_changes('Changes to be committed', @index_changes, :green)
      print_changes('Changes not staged for commit', @workspace_changes, :red)
      print_changes('Untracked files', @untracked, :red)

      print_commit_status
    end

    def print_changes(message, change_hash, color)
      return if change_hash.empty?

      puts message
      puts
      change_hash.each do |path, change|
        long_status = change ? LONG_STATUS[change].ljust(LABEL_WIDTH, ' ') : ''
        puts "\t#{fmt(long_status + path, color)}"
      end
      puts
    end

    def print_commit_status
      return if @index_changes.any?

      if @workspace_changes.any?
        puts 'no changes added to commit'
      elsif @untracked.any?
        puts 'no changes added for commit but untracked files present'
      else
        puts 'nothing to commit, working tree clean'
      end
    end

    def load_head_tree
      @head_tree = {}

      head_oid = repo.refs.read_head
      return unless head_oid

      head_commit = repo.database.load(head_oid)
      read_tree(head_commit.tree)
    end

    def read_tree(tree_oid, pathname=Pathname.new(''))
      tree = repo.database.load(tree_oid)

      tree.entries.each do |name, entry|
        entry_path = pathname.join(name)
        if entry.tree?
          read_tree(entry.oid, entry_path)
        else
          @head_tree[entry_path.to_s] = entry
        end
      end
    end

    def status_for_path(path)
      left = PORCELAIN_STATUS.fetch(@index_changes[path], ' ')
      right = PORCELAIN_STATUS.fetch(@workspace_changes[path], ' ')

      left + right
    end

    def scan_workspace(prefix=nil)
      repo.workspace.list_dir(prefix).each do |path, stat|
        if repo.index.tracked?(path)
          @stats[path] = stat if stat.file?
          scan_workspace(path) if stat.directory?
        elsif trackable_file?(path, stat)
          path += File::SEPARATOR if stat.directory?
          @untracked << path
        end
      end
    end

    def check_index_entries
      repo.index.each_entry do |entry|
        check_entry_against_workspace(entry)
        check_entry_against_head(entry)
      end
    end

    def check_entry_against_head(entry)
      commited_entry = @head_tree[entry.path]

      if commited_entry
        unless commited_entry.oid == entry.oid && commited_entry.mode == entry.mode
          record_change(entry.path, @index_changes, :modified)
        end
      else
        record_change(entry.path, @index_changes, :added)
      end
    end

    def check_entry_against_workspace(entry)
      stat = @stats[entry.path]
      return record_change(entry.path, @workspace_changes, :deleted) unless stat
      return record_change(entry.path, @workspace_changes, :modified) unless entry.stat_match?(stat)
      return if entry.times_match?(stat)

      check_database_for_object(entry, stat)
    end

    def check_database_for_object(entry, stat)
      data = repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid = repo.database.hash_object(blob)

      if oid == entry.oid
        repo.index.update_entry_stat(entry, stat)
      else
        record_change(entry.path, @workspace_changes, :modified)
      end
    end

    def record_change(path, target_hash, type)
      @changed.add(path)
      target_hash[path] = type
    end

    def trackable_file?(path, stat)
      return false unless stat

      return !repo.index.tracked?(path) if stat.file?
      return false unless stat.directory? # false if not file or dir.

      items = sort_files_first(repo.workspace.list_dir(path))

      items.any? do |i_path, i_stat|
        trackable_file?(i_path, i_stat)
      end
    end

    def file_dir_sort(item)
      item[1].file? ? 0 : 1
    end

    def sort_files_first(hash)
      hash.sort do |a, b|
        file_a = a[1].file? ? 0 : 1
        file_b = b[1].file? ? 0 : 1
        file_a <=> file_b
      end
    end
  end
end
