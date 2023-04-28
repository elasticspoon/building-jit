module Diff
  HUNK_CONTEXT = 3

  Hunk = Struct.new(:a_start, :b_start, :edits) do
    def self.filter(edits_array)
      hunks = []
      offset = 0

      loop do
        offset += 1 while edits_array[offset]&.type == :eql
        return hunks if offset >= edits_array.size

        offset -= HUNK_CONTEXT + 1

        a_start = offset.positive? ? edits_array[offset].a_line.number : 0
        b_start = offset.positive? ? edits_array[offset].b_line.number : 0

        hunks.push(Hunk.new(a_start, b_start, []))
        offset = Hunk.build(hunks.last, edits_array, offset)
      end
    end

    def self.build(hunk, edits_array, offset)
      counter = -1

      until counter == 0
        hunk.edits.push(edits_array[offset]) if offset >= 0 && counter > 0
        offset += 1
        break if offset >= edits_array.size

        far_context = edits_array[offset + HUNK_CONTEXT]

        case far_context&.type
        when :del, :ins
          counter = (2 * HUNK_CONTEXT) + 1
        else
          counter -= 1
        end
      end

      offset
    end

    def header
      a_offset = offsets_for(:a_line, a_start).join(",")
      b_offset = offsets_for(:b_line, b_start).join(",")

      "@@ -#{a_offset} +#{b_offset}"
    end

    private

    def offsets_for(line_type, default)
      lines = edits.filter_map(&line_type)
      start = lines.first&.number || default

      [start, lines.size]
    end
  end
end
