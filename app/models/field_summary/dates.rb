class FieldSummary
  # Date fields: the range the answers cover and their shape over that range. The buckets
  # get coarser as the range widens so that the shape stays readable, from a row per day
  # for a fortnight of answers to a row per decade for dates of birth.
  class Dates < FieldSummary
    # One period of the timeline. The period is a date rather than a name so that naming
    # it stays a question for the page rather than for the model.
    Bucket = Data.define(:starts_on, :count, :share)

    def earliest
      sorted_answers.first
    end

    def latest
      sorted_answers.last
    end

    def span_in_days
      return unless answered?

      (latest - earliest).to_i
    end

    def granularity
      return unless answered?
      return :day if span_in_days <= 31
      return :month if span_in_days <= 3 * 365
      return :year if span_in_days <= 50 * 365

      :decade
    end

    # Every period between the earliest and latest answer, including the empty ones, so
    # that a gap in the answers reads as a gap rather than as two adjacent bars.
    def timeline
      return [] unless answered?

      @timeline ||= bucket_starts.map do |starts_on|
        count = counts.fetch(starts_on, 0)

        Bucket.new(starts_on: starts_on, count: count, share: share_of(count))
      end
    end

    def busiest_share
      timeline.map(&:share).max || 0.0
    end

    def sorted_answers
      @sorted_answers ||= answers.sort
    end

    private

      def counts
        @counts ||= sorted_answers.map { |answer| bucket_start(answer) }.tally
      end

      def bucket_starts
        starts = [ bucket_start(earliest) ]
        starts << next_bucket_start(starts.last) while starts.last < bucket_start(latest)
        starts
      end

      def bucket_start(date)
        case granularity
        when :day then date
        when :month then date.beginning_of_month
        when :year then date.beginning_of_year
        else Date.new(date.year - (date.year % 10), 1, 1)
        end
      end

      def next_bucket_start(date)
        case granularity
        when :day then date.next_day
        when :month then date.next_month
        when :year then date.next_year
        else date.next_year(10)
        end
      end
  end
end
