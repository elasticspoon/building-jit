class Lockfile
  MissingParent = Class.new(StandardError)
  NoPermission = Class.new(StandardError)
  StaleLock = Class.new(StandardError)
  LockDenied = Class.new(StandardError)

  def initialize(path)
    @file_path = path
    @lock_path = path.sub_ext(".lock")

    @lock = nil
  end

  def hold_for_update
    unless @lock
      flags = File::RDWR | File::CREAT | File::EXCL
      @lock = File.open(@lock_path, flags)
    end
    true
  rescue Errno::EEXIST
    raise LockDenied, "Unable to create '#{@lock_path}': File exists."
  rescue Errno::ENOENT => e
    raise MissingParent, e.message
  rescue Errno::EACCES => e
    raise NoPermission, e.message
  end

  def write(string)
    raise_on_stale_lock

    @lock.write(string)
  end

  def commit
    raise_on_stale_lock

    @lock.close
    File.rename(@lock_path, @file_path)
    @lock = nil
  end

  # releases the lock without saving changes
  def rollback
    raise_on_stale_lock

    @lock.close
    File.unlink(@lock_path) # deletes the .lock file
    @lock = nil
  end

  private

  def raise_on_stale_lock
    raise StaleLock, "Not holding lock on file: #{@lock_path}" unless @lock
  end
end
