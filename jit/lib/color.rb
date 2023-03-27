class Color
  SGR_COLORS = {
    bold: 1,
    red: 31,
    green: 32,
    cyan: 36
  }.freeze

  def self.format(string, style)
    code = SGR_COLORS.fetch(style)

    "\e[#{code}m#{string}\e[m"
  end
end
