require 'digest/sha1'
require 'set'

require_relative './index/entry'
require_relative './lockfile'

class Index
  HEADER_FORMAT = 'a4N2'.freeze

  def initialize(pathname)
    @entries = {}
    @keys = Set.new
    @lockfile = Lockfile.new(pathname)
  end

  def add(pathname, oid, stat)
    entry = Entry.create(pathname, oid, stat)
    @keys.add(entry.key)
    @entries[pathname.to_s] = entry
  end

  def write_updates
    return false unless @lockfile.hold_for_update

    begin_write
    header = ['DIRC', 2, @entries.size].pack(HEADER_FORMAT)
    write(header)
    each_entry { |data| write(data.to_s) }
    finish_write

    true
  end

  private

  def begin_write
    @index_hash = Digest::SHA1.new
  end

  def finish_write
    @lockfile.write(@index_hash.digest)
    @lockfile.commit
  end

  def write(data)
    @lockfile.write(data)
    @index_hash.update(data)
  end

  def each_entry
    @keys.sort.each { |key| yield @entries[key] }
  end
end
