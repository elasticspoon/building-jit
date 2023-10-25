module Command
  class Log < Base
    def run
      setup_pager

      @reverse_refs = repo.refs.reverse_refs
      @current_ref = repo.refs.current_ref

      each_commit { |commit| show_commit(commit) }
      exit 0
    end

    private

    def define_options
      @options[:abbrev] = 'auto'
      @options[:decorate] = 'auto'
      @options[:format] = 'medium'

      @parser.on('--decorate[=<format>]') do |value|
        @options[:decorate] = value || 'short'
      end

      @parser.on('--no-decorate') do
        @options[:decorate] = 'no'
      end

      @parser.on('--pretty=<format>', '--format=<format>') do |value|
        @options[:format] = value
      end

      @parser.on('--[no-]abbrev-commit') do |value|
        @options[:abbrev] = value
      end

      @parser.on('--oneline') do
        @options[:abbrev] = true if @options[:abbrev] == 'auto'
        @options[:format] = 'oneline'
      end
    end

    def each_commit
      val = Revision.new(repo, @args[0]).resolve if @args[0]
      oid = val || repo.refs.read_head

      while oid
        commit = repo.database.load(oid)
        yield commit
        oid = commit.parent
      end
    end

    def show_commit(commit)
      case @options[:format]
      when 'oneline' then show_commit_oneline(commit)
      when 'medium' then show_commit_medium(commit)
      end
    end

    def show_commit_medium(commit)
      author = commit.author

      blank_line
      puts fmt("commit #{abbrev(commit)}", :yellow) + decorate(commit)
      puts "Author: #{author.name} <#{author.email}>"
      puts "Date:   #{author.readable_time}"
      blank_line
      commit.message.each_line { |line| puts "    #{line}" }
    end

    def show_commit_oneline(commit)
      id = fmt(abbrev(commit), :yellow) + decorate(commit)
      puts "#{id} #{commit.title_line}"
    end

    def blank_line
      puts '' if defined? @blank_line
      @blank_line = true
    end

    def decorate(commit)
      case @options[:decorate]
      when 'auto' then return '' unless @isatty
      when 'no' then return ''
      end

      refs = @reverse_refs[commit.oid]
      return '' if refs.empty?

      head, refs = refs.partition { |ref| ref.head? && !@current_ref.head? }
      names = refs.map { |ref| decoration_name(head.first, ref) }

      fmt(' (', :yellow) + names.join(fmt(', ', :yellow)) + fmt(')', :yellow)
    end

    def decoration_name(head, ref)
      case @options[:decorate]
      when 'short', 'auto' then name = ref.short_name
      when 'full' then name = ref.path
      end

      name = fmt(name, ref_color(ref))
      name = fmt("#{head.path} -> #{name}", ref_color(head)) if head && ref == @current_ref

      name
    end

    def ref_color(ref)
      ref.head? ? %i[bold cyan] : %i[bold green]
    end

    def abbrev(commit)
      if @options[:abbrev] == true
        repo.database.short_oid(commit.oid)
      else
        commit.oid
      end
    end
  end
end
