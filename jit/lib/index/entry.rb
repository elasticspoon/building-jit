class Index
  REGULAR_MODE = 0o100644
  EXECUTABLE_MODE = 0o100755
  MAX_PATH_SIZE = 0xfff
  ENTRY_FORMAT = "N10H40nZ*".freeze
  ENTRY_BLOCK = 8

  entry_fields = %i[ctime ctime_nsec mtime mtime_nsec dev ino mode uid gid size oid flags path]

  Entry = Struct.new(*entry_fields) do
    def self.create(file_path, oid, stat)
      path = file_path.to_s
      mode = Entry.mode_for_stat(stat)
      flags = [path.bytesize, MAX_PATH_SIZE].min

      Entry.new(
        stat.ctime.to_i,
        stat.ctime.nsec,
        stat.mtime.to_i,
        stat.mtime.nsec,
        stat.dev,
        stat.ino,
        mode,
        stat.uid,
        stat.gid,
        stat.size,
        oid,
        flags,
        path
      )
    end

    def to_s
      string = to_a.pack(ENTRY_FORMAT)
      string.concat("\0") until string.bytesize % ENTRY_BLOCK == 0
      string
    end

    def key
      path
    end

    def self.parse(data)
      Entry.new(*data.unpack(ENTRY_FORMAT))
    end

    def self.mode_for_stat(stat)
      stat.executable? ? EXECUTABLE_MODE : REGULAR_MODE
    end

    def parent_directories
      pathname.descend.to_a[...-1]
    end

    def basename # rubocop:disable Rails/Delegate
      pathname.basename
    end

    def stat_match?(stat)
      Entry.mode_for_stat(stat) == mode && (size == 0 || size == stat.size)
    end

    def times_match?(stat)
      mtime == stat.mtime.to_i &&
        ctime == stat.ctime.to_i &&
        ctime_nsec == stat.ctime.nsec &&
        mtime_nsec == stat.mtime.nsec
    end

    def update_stat(stat)
      self.ctime = stat.ctime.to_i
      self.ctime_nsec = stat.ctime.nsec
      self.mtime = stat.mtime.to_i
      self.mtime_nsec = stat.mtime.nsec
      self.dev = stat.dev
      self.ino = stat.ino
      self.mode = Entry.mode_for_stat(stat)
      self.uid = stat.uid
      self.gid = stat.gid
      self.size = stat.size
    end

    def pathname
      Pathname.new(path)
    end
  end
end
