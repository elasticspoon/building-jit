# rubocop:disable Naming/MethodParameterName
require_relative "./base"
require_relative "../diff"
require_relative "../index/entry"

module Command
  class Diff < Base
    NULL_PATH = Pathname.new("/dev/null").freeze
    NULL_OID = "0" * 40

    Target = Struct.new(:path, :oid, :mode, :data) do
      def diff_path
        mode ? path : NULL_PATH
      end
    end

    def run
      repo.index.load
      @status = repo.status

      setup_pager

      if @args.first == "--cached"
        diff_head_index
      else
        diff_index_workspace
      end

      exit 0
    end

    private

    def diff_index_workspace
      @status.workspace_changes.each do |path, state|
        case state
        when :modified
          print_diff(target_from_index(path), target_from_file(path))
        when :deleted
          print_diff(target_from_index(path), target_from_nothing(path))
        end
      end
    end

    def diff_head_index
      @status.index_changes.each do |path, state|
        case state
        when :modified
          print_diff(target_from_head(path), target_from_index(path))
        when :deleted
          print_diff(target_from_head(path), target_from_nothing(path))
        when :added
          print_diff(target_from_nothing(path), target_from_index(path))
        end
      end
    end

    def short(oid)
      repo.database.short_oid(oid)
    end

    def header(string)
      puts fmt(string, :bold)
    end

    def print_diff(a, b)
      return if a.oid == b.oid && a.mode == b.mode

      a_path = Pathname.new("a").join(a.path)
      b_path = Pathname.new("b").join(b.path)

      puts "diff --git #{a_path} #{b_path}"

      print_diff_mode(a, b)
      print_diff_content(a, b)
    end

    def print_diff_mode(a, b)
      if a.mode.nil?
        header("new file mode #{b.mode}")
      elsif b.mode.nil?
        header("deleted file mode #{a.mode}")
      elsif a.mode != b.mode
        header("old mode #{a.mode}")
        header("new mode #{b.mode}")
      end
    end

    def print_diff_content(a, b)
      index_text = "index #{short(a.oid)}...#{short(b.oid)}"
      index_text.concat(" #{a.mode}") if a.mode == b.mode

      puts index_text
      puts "--- #{a.diff_path}"
      puts "+++ #{b.diff_path}"

      hunks = ::Diff.diff_hunks(a.data, b.data)
      hunks.each { |hunk| print_diff_hunk(hunk) }
    end

    def print_diff_hunk(hunk)
      puts fmt(hunk.header, :cyan)
      hunk.edits.each { |edit| print_diff_edit(edit) }
    end

    def print_diff_edit(edit)
      text = edit.to_s.rstrip

      case edit.type
      when :del then puts fmt(text, :red)
      when :ins then puts fmt(text, :green)
      when :eql then puts text
      end
    end

    def target_from_index(path)
      entry = repo.index.entry_for_path(path)
      blob = repo.database.load(entry.oid)
      oid = entry.oid
      mode = entry.mode.to_s(8)

      Target.new(path, oid, mode, blob.data)
    end

    def target_from_file(path)
      blob = Database::Blob.new(repo.workspace.read_file(path))
      oid = repo.database.hash_object(blob)
      mode = Index::Entry.mode_for_stat(@status.stats[path]).to_s(8)

      Target.new(path, oid, mode, blob.data)
    end

    def target_from_nothing(path)
      Target.new(path, NULL_OID, nil, "")
    end

    def target_from_head(path)
      entry = @status.head_tree.fetch(path)
      blob = repo.database.load(entry.oid)
      oid = entry.oid
      mode = entry.mode.to_s(8)

      Target.new(path, oid, mode, blob.data)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
