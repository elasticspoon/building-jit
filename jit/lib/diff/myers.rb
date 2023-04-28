# rubocop:disable Naming/MethodParameterName
module Diff
  class Myers
    def self.diff(a, b)
      Myers.new(a, b).diff
    end

    def initialize(a, b)
      @lines_a = a
      @lines_b = b
    end

    def diff
      diff = []

      backtrack do |prev_x, prev_y, x, y|
        a_line = @lines_a[prev_x]
        b_line = @lines_b[prev_y]

        if x == prev_x
          diff.push(Edit.new(:ins, nil, b_line))
        elsif y == prev_y
          diff.push(Edit.new(:del, a_line, b_line))
        # elsif diff[..-3].none? { |v| v.type == :eql }
        else
          diff.push(Edit.new(:eql, a_line, b_line))
        end
      end

      diff.reverse
    end

    def shortest_edit
      n = @lines_a.size
      m = @lines_b.size

      max_edits = n + m

      v = Array.new((2 * max_edits) + 1)
      v[1] = 0
      trace = []

      (0..max_edits).step do |depth|
        trace.push(v.clone)

        (-depth..depth).step(2) do |k|
          x = next_x_down_or_right(depth, k, v)
          x, y = try_diagonal(x, k, n, m)

          v[k] = x

          return trace if x >= n && y >= m
        end
      end
    end

    def backtrack
      current_x = @lines_a.size
      current_y = @lines_b.size

      trace_table_end_to_start = shortest_edit.each_with_index.reverse_each

      trace_table_end_to_start.each do |v, depth|
        current_k = current_x - current_y

        prev_k = prev_k_down_or_right(depth, current_k, v)

        prev_x, prev_y, = get_k_x_y_values(v, k: prev_k)

        # follows diagonals and yield coords until 1 away from prev move
        # either in x or y direction or reaches prev move
        while current_x > prev_x && current_y > prev_y
          # yields diagonal move
          yield current_x - 1, current_y - 1, current_x, current_y
          current_x -= 1
          current_y -= 1
        end

        # yields right or down move
        yield prev_x, prev_y, current_x, current_y if depth > 0

        current_x = prev_x
        current_y = prev_y
      end
    end

    private

    def get_k_x_y_values(v, x: nil, y: nil, k: nil)
      k ||= x&.- y
      x ||= v[k]
      y ||= v[k]&.-k

      [x, y, k]
    end

    def right_or_down_move(depth, k, v, right_move, down_move)
      return down_move if k == -depth
      return right_move if k == depth

      (v[k - 1] < v[k + 1]) ? down_move : right_move
    end

    def next_x_down_or_right(depth, k, v)
      right_move = v[k - 1]&.+ 1
      down_move = v[k + 1]

      right_or_down_move(depth, k, v, right_move, down_move)
    end

    def prev_k_down_or_right(depth, k, v)
      right_move = k - 1
      down_move = k + 1

      right_or_down_move(depth, k, v, right_move, down_move)
    end

    def try_diagonal(x, k, n, m)
      y = x - k

      while x < n && y < m &&
          @lines_a[x].text == @lines_b[y].text
        x += 1
        y += 1
      end

      [x, y]
    end
  end
end

# rubocop:enable Naming/MethodParameterName
