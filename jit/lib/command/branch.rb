require_relative 'base'

module Command
  class Branch < Base
    def run
      run_with_options

      exit 0
    end

    private

    def create_branch
      branch_name = @args[0]
      start_oid = @args[1]

      if start_oid
        revision = Revision.new(repo, start_oid)
        oid = revision.resolve(Revision::COMMIT)
      else
        oid = repo.refs.read_head
      end

      repo.refs.create_branch(branch_name, oid)
    rescue Refs::InvalidBranch, Revision::InvalidObject => e
      revision&.errors&.each do |err|
        warn "error: #{err.message}"
        err.hint.each { |line| warn "hint: #{line}" }
      end
      warn "fatal: #{e.message}"
      exit 128
    end

    def define_options
      @parser.on('-v', '--verbose') { @options[:verbose] = true }

      @parser.on('-d', '--delete') { @options[:delete] = true }
      @parser.on('-f', '--force') { @options[:force] = true }

      @parser.on '-D' do
        @options[:delete] = true
        @options[:force] = true
      end
    end

    def list_branches
      current = repo.refs.current_ref
      branches = repo.refs.list_branches.sort_by(&:path)
      max_width = branches.map { |b| b.short_name.size }.max

      setup_pager

      branches.each do |ref|
        info = format_ref(ref, current)
        info.concat(extended_branch_info(ref, max_width))
        puts info
      end
    end

    def format_ref(ref, current)
      if ref == current
        "* #{fmt(ref.short_name, :green)}"
      else
        "  #{ref.short_name}"
      end
    end

    def extended_branch_info(ref, max_width)
      return '' unless @options[:verbose]

      commit = repo.database.load(ref.read_oid)
      short = repo.database.short_oid(commit.oid)
      space = ' ' * (max_width - ref.short_name.length)

      "#{space} #{short} #{commit.title_line}"
    end

    def run_with_options
      if @options[:delete]
        delete_branches
      elsif @args.empty?
        list_branches
      else
        create_branch
      end
    end

    def delete_branches
      @args.each { |branch_name| delete_branch(branch_name) }
    end

    def delete_branch(branch_name)
      unless @options[:force]
        warn 'Unforced branch deletion not implemented'
        return nil
      end

      oid = repo.refs.delete_branch(branch_name)
      short = repo.database.short_oid(oid)

      puts "Deleted branch #{branch_name} (was #{short})."
    rescue Refs::InvalidBranch => e
      warn("error: #{e}")
      exit 1
    end
  end
end
