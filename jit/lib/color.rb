class Color
  SGR_COLORS = {
    bold: 1,
    red: 31,
    green: 32,
    cyan: 36,
    yellow: 33
  }.freeze

  def self.format(string, style)
    codes = [*style].map { |s| SGR_COLORS.fetch(s) }
    "\e[#{codes.join(';')}m#{string}\e[m"
  end
end
