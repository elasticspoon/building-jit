require_relative "./base"
require_relative "../sorted_hash"

module Command
  class Status < Base
    PORCELAIN_STATUS = {
      added: "A",
      deleted: "D",
      modified: "M"
    }.freeze

    LONG_STATUS = {
      added: "new file:",
      deleted: "deleted:",
      modified: "modified:"
    }.freeze

    LABEL_WIDTH = 12

    def run
      repo.index.load_for_update
      @status = repo.status
      repo.index.write_updates

      print_results
      exit 0
    end

    private

    def print_results
      if @args.first == "--porcelain"
        print_porcelain_format
      else
        print_long_format
      end
    end

    def print_porcelain_format
      @status.changed.each { |path| puts "#{status_for_path(path)} #{path}" }
      @status.untracked.each { |path| puts "?? #{path}" }
    end

    def print_long_format
      print_changes("Changes to be committed", @status.index_changes, :green)
      print_changes("Changes not staged for commit", @status.workspace_changes, :red)
      print_changes("Untracked files", @status.untracked, :red)

      print_commit_status
    end

    def print_changes(message, change_hash, color)
      return if change_hash.empty?

      puts message
      puts
      change_hash.each do |path, change|
        long_status = change ? LONG_STATUS[change].ljust(LABEL_WIDTH, " ") : ""
        puts "\t#{fmt(long_status + path, color)}"
      end
      puts
    end

    def print_commit_status
      return if @status.index_changes.any?

      if @status.workspace_changes.any?
        puts "no changes added to commit"
      elsif @status.untracked.any?
        puts "no changes added for commit but untracked files present"
      else
        puts "nothing to commit, working tree clean"
      end
    end

    def status_for_path(path)
      left = PORCELAIN_STATUS.fetch(@status.index_changes[path], " ")
      right = PORCELAIN_STATUS.fetch(@status.workspace_changes[path], " ")

      left + right
    end
  end
end
