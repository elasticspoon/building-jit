class Color
  SGR_COLORS = {
    red: 31,
    green: 32
  }.freeze

  def self.format(string, style)
    code = SGR_COLORS.fetch(style)

    "\e[#{code}m#{string}\e[m"
  end
end
