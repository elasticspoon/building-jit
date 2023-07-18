class Repository
  class Inspector
    def initialize(repository)
      @repo = repository
    end

    def trackable_file?(path, stat)
      return false unless stat

      return !@repo.index.tracked?(path) if stat.file?
      return false unless stat.directory? # false if not file or dir.

      items = sort_files_first(@repo.workspace.list_dir(path))

      items.any? do |i_path, i_stat|
        trackable_file?(i_path, i_stat)
      end
    end

    def compare_index_to_workspace(entry, stat)
      return :untracked unless entry
      return :deleted unless stat
      return :modified unless entry.stat_match?(stat)
      return nil if entry.times_match?(stat)

      data = @repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid = @repo.database.hash_object(blob)

      return if entry.oid == oid

      :modified
    end

    def compare_tree_to_index(item, entry)
      # entry cannot be nil because we call entry.path
      # and it generally makes no sense
      return nil unless item || entry

      return :added unless item
      return :deleted unless entry

      return nil if entry.mode == item.mode && entry.oid == item.oid

      :modified
    end

    private

    def sort_files_first(hash)
      hash.sort do |a, b|
        file_a = a[1].file? ? 0 : 1
        file_b = b[1].file? ? 0 : 1
        file_a <=> file_b
      end
    end
  end
end
