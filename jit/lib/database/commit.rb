class Database
  class Commit
    attr_accessor :oid
    attr_reader :tree, :parent, :author, :message

    def initialize(parent, tree, author, message)
      @parent = parent
      @tree = tree
      @author = author
      @message = message
    end

    def type
      'commit'
    end

    def to_s
      lines = []

      lines.push("tree #{@tree}")
      lines.push("parent #{@parent}") if @parent
      lines.push("author #{@author}")
      lines.push("commiter #{@author}")
      lines.push('')
      lines.push(@message)

      lines.join("\n")
    end

    def self.parse(scanner)
      headers = {}

      loop do
        line = scanner.scan_until(/\n/).strip
        break if line == ''

        header, value = line.split(/ +/, 2)
        headers[header] = value
      end

      Commit.new(
        headers['parent'],
        headers['tree'],
        Author.parse(headers['author']),
        scanner.rest
      )
    end

    def title_line
      @message.lines.first
    end
  end
end
