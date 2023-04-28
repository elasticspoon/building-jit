class Database
  class TreeDiff
    attr_reader :changes

    def initialize(database)
      @database = database
      @changes = {}
    end

    def compare_oids(a_oid, b_oid, prefix = Pathname.new(""))
      return if a_oid == b_oid

      entries_a = a_oid ? oid_to_tree(a_oid).entries : {}
      entries_b = b_oid ? oid_to_tree(b_oid).entries : {}

      detect_deletions(entries_a, entries_b, prefix)
      detect_additions(entries_a, entries_b, prefix)
    end

    private

    def oid_to_tree(oid)
      object = @database.load(oid)

      case object
      when Commit then @database.load(object.tree)
      when Tree then object
      end
    end

    def detect_deletions(entries_a, entries_b, prefix)
      entries_a.each do |name, entry_a|
        path = prefix.join(name)
        entry_b = entries_b[name]

        next if entry_a == entry_b

        tree_a = entry_a&.tree? ? entry_a.oid : nil
        tree_b = entry_b&.tree? ? entry_b.oid : nil
        compare_oids(tree_a, tree_b, path)

        blobs = [entry_a, entry_b].map { |entry| entry&.tree? ? nil : entry }
        @changes[path] = blobs if blobs.any?
      end
    end

    def detect_additions(entries_a, entries_b, prefix)
      entries_b.each do |name, entry_b|
        path = prefix.join(name)
        entry_a = entries_a[name]

        next unless entry_a.nil?

        if entry_b&.tree?
          compare_oids(entry_a, entry_b, path)
        else
          @changes[path] = [nil, entry_b]
        end
      end
    end
  end
end
