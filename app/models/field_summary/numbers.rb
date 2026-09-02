class FieldSummary
  # Number fields. The smallest, largest, mean and median of the answers, and the answers
  # themselves while there are still few enough to read, because a median of three
  # numbers is just the middle one.
  class Numbers < FieldSummary
    def minimum
      sorted_answers.first
    end

    def maximum
      sorted_answers.last
    end

    def mean
      return unless answered?

      sorted_answers.sum / answered_count
    end

    def median
      return unless answered?

      middle = answered_count / 2

      if answered_count.odd?
        sorted_answers[middle]
      else
        (sorted_answers[middle - 1] + sorted_answers[middle]) / 2
      end
    end

    def sorted_answers
      @sorted_answers ||= answers.sort
    end
  end
end
