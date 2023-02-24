class Entry
  attr_reader :name, :oid

  REGULAR_MODE = '100644'.freeze
  EXECUTABLE_MODE = '100755'.freeze
  DIRECTORY_MODE = '40000'.freeze

  def initialize(name, oid, stat)
    @name = name
    @oid = oid
    @stat = stat
  end

  def mode
    @stat.executable? ? EXECUTABLE_MODE : REGULAR_MODE
  end

  def parent_directories
    @name.descend.to_a[...-1]
  end

  def basename
    @name.basename
  end
end
