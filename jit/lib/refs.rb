require_relative '../lib/lockfile'

class Refs
  LockDenied = Class.new(StandardError)

  def initialize(pathname)
    @pathname = pathname
  end

  def update_head(oid)
    lockfile = Lockfile.new(head_path)
    lockfile.hold_for_update
    lockfile.write(oid)
    lockfile.write("\n")
    lockfile.commit
  end

  def read_head
    File.read(head_path).strip if File.exist?(head_path)
  end

  private

  def head_path
    @pathname.join('HEAD')
  end
end
