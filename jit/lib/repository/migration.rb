class Repository
  class Migration
    MESSAGES = {
      stale_file: [
        'Your local changes to the following files would be overwritten by checkout:',
        'Please commit your changes or stash them before you switch branches.'
      ],
      stale_directory: [
        'Updating the following directories would lose untracked files in them',
        "\n"
      ],
      untracked_overwritten: [
        'The following untracked working tree files would be overwritten by checkout:',
        'Please move or remove them before you switch branches.'
      ],
      untracked_removed: [
        'The following untracked working tree files would be removed by checkout:',
        'Please move or remove them before you switch branches.'
      ]
    }.freeze

    Conflict = Class.new(StandardError)

    attr_reader :changes, :mkdirs, :rmdirs, :errors

    def initialize(repository, tree_diff)
      @repo = repository
      @diff = tree_diff

      @changes = { create: [], update: [], destroy: [] }
      @mkdirs = Set.new
      @rmdirs = Set.new

      @inspector = Inspector.new(repository)
      @errors = []

      @conflicts = {
        stale_file: SortedSet.new,
        stale_directory: SortedSet.new,
        untracked_overwritten: SortedSet.new,
        untracked_removed: SortedSet.new
      }
    end

    def apply_changes
      plan_changes
      update_workspace
      update_index
    end

    def blob_data(oid)
      @repo.database.load(oid).data
    end

    private

    def plan_changes
      @diff.each do |path, (old_entry, new_entry)|
        check_for_conflict(path, old_entry, new_entry)
        record_change(path, old_entry, new_entry)
      end

      collect_errors
    end

    def collect_errors
      @conflicts.each do |type, paths|
        next if paths.empty?

        header, footer = MESSAGES[type]
        error_paths = paths.map { |p| "\t#{p}" }

        @errors.push([header, *error_paths, footer].join("\n"))
      end
    end

    def check_for_conflict(path, old_entry, new_entry)
      entry = @repo.index.entry_for_path(path)

      if index_differs_from_trees(entry, old_entry, new_entry)
        @conflicts[:stale_file].add(path.to_s)
        return nil
      end

      stat = @repo.workspace.stat_file(path)
      type = get_error_type(stat, old_entry, new_entry)

      if stat.nil?
        parent = untracked_parent(path)
        @conflicts[type].add(entry ? path.to_s : parent.to_s) if parent
      elsif stat.file?
        changed = @inspector.compare_index_to_workspace(entry, stat)
        @conflicts[type].add(path.to_s) if changed
      elsif stat.directory?
        trackable = @inspector.trackable_file?(path, stat)
        @conflicts[type].add(path.to_s) if trackable
      end
    end

    def index_differs_from_trees(entry, old_entry, new_entry)
      @inspector.compare_tree_to_index(old_entry, entry) &&
        @inspector.compare_tree_to_index(new_entry, entry)
    end

    def untracked_parent(path)
      path.dirname.ascend.find do |parent|
        next if parent.to_s == '.'

        parent_stat = @repo.workspace.stat_file(parent)
        next unless parent_stat&.file?

        @inspector.trackable_file?(parent, parent_stat)
      end
    end

    def get_error_type(stat, entry, item)
      if entry
        :stale_file
      elsif item
        :untracked_overwritten
      elsif stat&.directory?
        :untracked_directory
      else
        :untracked_removed
      end
    end

    def record_change(path, old_entry, new_entry)
      if new_entry.nil?
        @rmdirs.merge(path.dirname.descend)
        action = :destroy
      elsif old_entry.nil?
        @mkdirs.merge(path.dirname.descend)
        action = :create
      else
        @mkdirs.merge(path.dirname.descend)
        action = :update
      end
      @changes[action].push([path, new_entry])
    end

    def update_workspace
      @repo.workspace.apply_migration(self)
    end

    def update_index
      @changes[:destroy].each do |path, _|
        @repo.index.remove(path)
      end

      %i[create update].each do |action|
        @changes[action].each do |path, entry|
          stat = @repo.workspace.stat_file(path)
          @repo.index.add(path, entry.oid, stat)
        end
      end
    end
  end
end