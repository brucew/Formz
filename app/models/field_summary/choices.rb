class FieldSummary
  # Select, radio button and check box fields. Shares are of the people who answered the
  # field rather than of the selections they made, so a check box field's shares
  # deliberately add up to more than 100% when people pick several options.
  class Choices < FieldSummary
    def multiple?
      field.multiple_choice?
    end

    # In the order the form asks them, including choices nobody picked.
    def tallies
      @tallies ||= field.choices.map { |choice| tally_for(choice) }
    end

    # Answers that are not among the choices the field offers now. Nothing in the app can
    # produce one, because a form's fields stop changing at its first submission, but an
    # answer stored before the choices were what they are now would otherwise disappear
    # from the totals without a word.
    def unexpected_tallies
      @unexpected_tallies ||= (counts.keys - field.choices).sort.map { |choice| tally_for(choice) }
    end

    def unexpected?
      unexpected_tallies.any?
    end

    # How many options were picked in total, which is larger than the number of people
    # for a check box field that people used more than one box on.
    def selection_count
      selections.size
    end

    private

      def selections
        @selections ||= answers.flat_map { |answer| Array(answer) }.map(&:to_s)
      end

      def counts
        @counts ||= selections.tally
      end

      def tally_for(choice)
        count = counts.fetch(choice, 0)

        Tally.new(label: choice, count: count, share: share_of(count))
      end
  end
end
