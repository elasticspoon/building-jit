class Database
  class Tree
    ENTRY_FORMAT = 'Z*H40'.freeze
    TREE_MODE = 0o40000

    attr_accessor :oid

    def initialize
      @entries = {}
    end

    def type
      'tree'
    end

    def mode
      TREE_MODE
    end

    def to_s
      entries = @entries.map do |name, entry|
        entry_mode = entry.mode.to_s(8)
        ["#{entry_mode} #{name}", entry.oid].pack(ENTRY_FORMAT)
      end

      entries.join
    end

    def add_entry(parents, entry)
      if parents.empty?
        @entries[entry.basename] = entry
      else
        tree = @entries[parents.first.basename] ||= Tree.new
        tree.add_entry(parents[1..], entry)
      end
    end

    def traverse(&)
      @entries.each do |_name, entry|
        entry.traverse(&) if entry.is_a?(Tree)
      end

      yield self
    end

    def self.build(entries)
      entries = entries.sort_by(&:key)

      root = Tree.new

      entries.each do |entry|
        root.add_entry(entry.parent_directories, entry)
      end

      root
    end
  end
end
