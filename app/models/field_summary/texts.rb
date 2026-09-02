class FieldSummary
  # Free text, which resists summarising. How many people wrote something, how much of
  # that repeated, and a few of the answers themselves -- anything more would be an
  # analysis the data does not support.
  class Texts < FieldSummary
    def distinct_count
      distinct_answers.size
    end

    # Written answers that more than one person gave word for word. A free text field
    # collecting the same handful of replies is usually a choice field waiting to happen.
    def repeated?
      distinct_count < answered_count
    end

    def examples
      distinct_answers.first(5)
    end

    def unshown_count
      distinct_count - examples.size
    end

    private

      def distinct_answers
        @distinct_answers ||= answers.uniq
      end
  end
end
