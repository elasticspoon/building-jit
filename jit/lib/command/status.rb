require_relative './base'
require 'sorted_set'

module Command
  class Status < Base
    def run
      @stats = {}
      @untracked = SortedSet.new
      @changed = SortedSet.new
      @changes = {}

      repo.index.load_for_update

      scan_workspace
      detect_workspace_changes

      repo.index.write_updates

      print_results

      exit 0
    end

    private

    def print_results
      @changed.each { |path| puts "#{status_for_path(path)} #{path}" }
      @untracked.each { |path| puts "?? #{path}" }
    end

    def status_for_path(path)
      changes = @changes[path]

      status = '  '
      status = ' D' if changes.include?(:workspace_deleted)
      status = ' M' if changes.include?(:workspace_modified)

      status
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

    def detect_workspace_changes
      repo.index.each_entry { |entry| check_index_entry(entry) }
    end

    def check_index_entry(entry)
      stat = @stats[entry.path]

      return record_change(entry.path, :workspace_deleted) unless stat
      return record_change(entry.path, :workspace_modified) unless entry.stat_match?(stat)
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
        record_change(entry.path, :workspace_modified)
      end
    end

    def record_change(path, type)
      @changed.add(path)
      (@changes[path] ||= Set.new).add(type)
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
