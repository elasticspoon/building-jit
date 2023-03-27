require 'digest/sha1'
require 'sorted_set'

require_relative '../lib/index/entry'
require_relative '../lib/index/checksum'
require_relative '../lib/lockfile'

class Index
  HEADER_FORMAT = 'a4N2'.freeze
  HEADER_SIZE = 12
  VERSION = 2
  SIGNATURE = 'DIRC'.freeze

  ENTRY_SIZE = 64

  def initialize(pathname)
    @pathname = pathname
    @entries = {}
    @parents = {}
    @keys = SortedSet.new
    @lockfile = Lockfile.new(pathname)
  end

  def add(pathname, oid, stat)
    entry = Entry.create(pathname, oid, stat)
    discard_conflicts(entry)
    store_entry(entry)
    @changed = true
  end

  def write_updates
    return @lockfile.rollback unless @changed

    writer = Checksum.new(@lockfile)
    header = [SIGNATURE, VERSION, @entries.size].pack(HEADER_FORMAT)

    writer.write(header)
    each_entry { |data| writer.write(data.to_s) }
    writer.write_checksum

    @lockfile.commit

    @changed = false
  end

  def load_for_update
    @lockfile.hold_for_update
    load
  end

  def load
    clear
    file = open_index_file

    if file
      reader = Checksum.new(file)
      count = read_header(reader)
      read_entries(reader, count)
      reader.verify_checksum
    end
  ensure
    file&.close
  end

  def delete_nonexistent_entries(relative_pathname, base_path)
    qualified_entries = @parents[relative_pathname.to_s] || @entries.keys

    qualified_entries.each do |entry_path|
      full_path = base_path.join(entry_path)
      remove_missing_entry(entry_path, full_path)
    end
  end

  def each_entry
    if block_given?
      @keys.each { |key| yield entry_for_path(key) }
    else
      enum_for(:each_entry)
    end
  end

  def entry_for_path(path)
    @entries[path.to_s]
  end

  def release_lock
    @lockfile.rollback
  end

  def tracked?(path)
    tracked_file?(path) || tracked_dir?(path)
  end

  def tracked_dir?(path_input)
    @parents.key?(path_input.to_s)
  end

  def tracked_file?(path)
    @entries.key?(path.to_s)
  end

  def update_entry_stat(entry, stat)
    entry.update_stat(stat)
    @changed = true
  end

  private

  def remove_missing_entry(path, full_path)
    remove_entry(path) if tracked_file?(path) && !File.exist?(full_path)
    remove_children(path) if tracked_dir?(path) && !File.directory?(full_path)
  end

  def remove_entry(path)
    entry = entry_for_path(path)
    return if entry.nil?

    @keys.delete(entry.key)
    @entries.delete(entry.key)

    entry.parent_directories.each do |dirname|
      dir = dirname.to_s
      @parents[dir].delete(entry.path)
      @parents.delete(dir) if @parents[dir].empty?
    end

    @changed = true
  end

  def add_parents(entry)
    entry.parent_directories.each do |parent|
      (@parents[parent.to_s] ||= Set.new) << entry.key
    end
  end

  def discard_conflicts(entry)
    entry.parent_directories.each { |dir_name| remove_entry(dir_name) }
    remove_children(entry.path)
  end

  def remove_children(parent_path)
    children_set = @parents.clone[parent_path]
    children_set&.each { |child| remove_entry(child) }
  end

  def clear
    @entries = {}
    @parents = {}
    @keys = SortedSet.new
    @changed = false
  end

  def read_entries(reader, count)
    count.times do
      data = reader.read(ENTRY_SIZE)
      data.concat(reader.read(ENTRY_BLOCK)) until data.byteslice(-1) == "\0"

      store_entry(Entry.parse(data))
    end
  end

  def store_entry(entry)
    @keys.add(entry.key)
    @entries[entry.key] = entry
    add_parents(entry)
  end

  def read_header(reader)
    data = reader.read(HEADER_SIZE)
    signature, version, count = data.unpack(HEADER_FORMAT)

    raise Invalid, "Signature: expected #{SIGNATURE} but found #{signature}" if signature != SIGNATURE
    raise Invalid, "Version: expected #{VERSION} but found #{version}" if version != VERSION

    count
  end

  def open_index_file
    File.open(@pathname, File::RDONLY)
  rescue Errno::ENOENT
    nil
  end

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
end
