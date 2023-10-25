module Command
  class Log < Base
    def run
      setup_pager
      each_commit { |commit| show_commit(commit) }
      exit 0
    end

    private

    def define_options
      @options[:abbrev] = :auto
      @options[:format] = 'medium'

      @parser.on('--decorate[=short|full|auto|no]') do |value|
        @options[:decorate] = value || true
      end

      @parser.on('--pretty=<format>', '--format=<format>') do |value|
        @options[:format] = value
      end

      @parser.on('--[no-]abbrev-commit') do |value|
        @options[:abbrev] = value
      end

      @parser.on('--oneline') do
        @options[:abbrev] = true if @options[:abbrev] == :auto
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
      puts fmt("commit #{abbrev(commit)}", :yellow)
      puts "Author: #{author.name} <#{author.email}>"
      puts "Date:   #{author.readable_time}"
      blank_line
      commit.message.each_line { |line| puts "    #{line}" }
    end

    def show_commit_oneline(commit)
      puts "#{fmt(abbrev(commit), :yellow)} #{commit.title_line}"
    end

    def blank_line
      puts '' if defined? @blank_line
      @blank_line = true
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
