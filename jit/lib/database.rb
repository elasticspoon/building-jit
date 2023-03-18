require 'digest/sha1'
require 'fileutils'
require 'zlib'
require 'strscan'

require_relative './database/blob'
require_relative './database/commit'
require_relative './database/tree'
require_relative './database/author'
require_relative './database/entry'

class Database
  TEMP_CHARS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
  OBJECT_TYPES = {
    'commit' => Commit,
    'tree'   => Tree,
    'blob'   => Blob
  }.freeze

  def initialize(pathname)
    @pathname = pathname
    @objects = {}
  end

  def store(object)
    content = serialize_object(object)
    object.oid = hash_content(content)

    write_object(object.oid, content)
  end

  def hash_object(object)
    hash_content(serialize_object(object))
  end

  def load(oid)
    @objects[oid] ||= read_object(oid)
  end

  private

  def serialize_object(object)
    string = object.to_s.force_encoding(Encoding::ASCII_8BIT)
    "#{object.type} #{string.bytesize}\0#{string}"
  end

  def hash_content(string)
    Digest::SHA1.hexdigest(string)
  end

  def read_object(oid)
    data = deserialize_object(oid)
    scanner = StringScanner.new(data)

    type = scanner.scan_until(/ /).strip
    _size = scanner.scan_until(/\0/)[..-2]

    object = OBJECT_TYPES[type].parse(scanner)
    object.oid = oid

    object
  end

  def deserialize_object(oid)
    path = object_path(oid)
    data = File.read(path)
    Zlib::Inflate.inflate(data)
  end

  def write_object(oid, content)
    path = object_path(oid)
    return if File.exist?(path)

    dirname = path.dirname
    temp_path = dirname.join(generate_temp_name)

    begin
      flags = File::RDWR | File::CREAT | File::EXCL
      file = File.open(temp_path, flags)
    rescue Errno::ENOENT
      FileUtils.mkdir_p(dirname)
      file = File.open(temp_path, flags)
    end

    compressed = Zlib::Deflate.deflate(content, Zlib::BEST_SPEED)
    file.write(compressed)
    file.close

    File.rename(temp_path, path)
  end

  def generate_temp_name
    "tmp_obj#{(1..6).map { TEMP_CHARS.sample }.join}"
  end

  def object_path(oid)
    @pathname.join(oid[0..1], oid[2..])
  end
end
