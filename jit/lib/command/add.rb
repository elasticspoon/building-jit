require_relative "./base"

module Command
  class Add < Base
    LOCKED_INDEX_MESSAGE = <<~MSG.freeze
      Another git process seems to be running in this repository, e.g.
      an editor opened by 'git commit'. Please make sure all processes
      are terminated then try again. If it still fails, a git process
      may have crashed in this repository earlier:
      remove the file manually to continue.
    MSG

    def run
      repo.index.load_for_update

      queried_files.each { |pathname| add_path_to_index(pathname) }

      repo.index.write_updates

      exit 0
    rescue Lockfile::LockDenied => e
      handle_locked_index(e)
    rescue Workspace::MissingFile => e
      handle_missing_file(e)
    rescue Workspace::NoPermission => e
      handle_no_permission(e)
    end

    private

    def handle_locked_index(error)
      warn "fatal: #{error.message}"
      warn
      warn LOCKED_INDEX_MESSAGE
      exit 128
    end

    def handle_missing_file(error)
      warn "fatal: #{error.message}"
      repo.index.release_lock
      exit 128
    end

    def handle_no_permission(error)
      warn "error: #{error.message}"
      warn "fatal: adding files failed"
      repo.index.release_lock
      exit 128
    end

    def add_path_to_index(pathname)
      data = repo.workspace.read_file(pathname)
      stat = repo.workspace.stat_file(pathname)

      blob = Database::Blob.new(data)
      repo.database.store(blob)
      repo.index.add(pathname, blob.oid, stat)
    end

    def expanded_arg_paths
      @args.map do |path_input|
        target_path = Pathname.new(path_input.chomp("/"))
        full_path = expanded_pathname(path_input)

        [target_path, full_path]
      end
    end

    def queried_files
      expanded_arg_paths.flat_map do |target_path, target_path_full|
        repo.workspace.list_files(target_path_full)
      rescue Workspace::MissingFile => e
        # reraise exception if trying to add a bad file
        # -> the file or dir is missing and not in index
        raise e unless repo.index.tracked?(target_path)

        []
      ensure
        # remove files in target path from index if nonexistent
        repo.index.delete_nonexistent_entries(target_path, workspace_path)
      end
    end
  end
end
