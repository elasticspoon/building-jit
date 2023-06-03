require "set"

class SetSorted < Set
  def each
    to_a.sort.each { |val| yield val }
  end
end
