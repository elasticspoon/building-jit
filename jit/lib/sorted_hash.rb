require_relative 'sorted_set'

class SortedHash < Hash
  def initialize
    super
    @keys = SetSorted.new
  end

  def []=(key, value)
    @keys.add(key)
    super
  end

  def each
    @keys.each { |key| yield [key, self[key]] }
  end
end
