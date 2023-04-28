class Database
  class Blob
    attr_accessor :oid, :data

    def initialize(data)
      @data = data
    end

    def type
      "blob"
    end

    def to_s
      @data
    end

    def self.parse(scanner)
      Blob.new(scanner.rest)
    end
  end
end
