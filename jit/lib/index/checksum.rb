require 'digest/sha1'

class Index
  class Checksum
    CHECKSUM_SIZE = 20

    EndOfFile = Class.new(StandardError)

    def initialize(file)
      @file = file
      @digest = Digest::SHA1.new
    end

    def read(size)
      data = @file.read(size)

      raise EndOfFile, 'Unexpected end-of-file while reading index' unless data.bytesize == size

      @digest.update(data)
      data
    end

    def write(data)
      @file.write(data)
      @digest.update(data)
    end

    def write_checksum
      @file.write(@digest.digest)
    end

    def verify_checksum
      checksum = @file.read(CHECKSUM_SIZE)

      raise Invalid, 'Checksum does not match value stored on disk.' unless checksum == @digest.digest
    end
  end
end
