module Admin
  # Formatting for the analysis page. The numbers themselves come from FormAnalysis and
  # FieldSummary; nothing here decides what is true, only how it reads.
  module AnalysesHelper
    # Bars are drawn as an SVG rectangle in a 100 unit wide viewBox rather than as a
    # styled width, so a proportion becomes an attribute instead of an inline style.
    def analysis_bar_length(share, scale: 1.0)
      return 0 if share.to_f <= 0 || scale.to_f <= 0

      [ (share / scale * 100).round(2), 100 ].min
    end

    def analysis_share(share)
      number_to_percentage(share.to_f * 100, precision: 1, strip_insignificant_zeros: true)
    end

    # Answers are BigDecimal, so whole numbers should read as whole numbers and the rest
    # should stop before the arithmetic of an average runs away with itself.
    def analysis_number(value)
      number_with_precision(value, precision: 2, strip_insignificant_zeros: true, delimiter: ",")
    end

    def analysis_date(date)
      l(date, format: :long)
    end

    # A timeline bucket names itself by how wide it is: a day, a month, a year or a
    # decade.
    def analysis_period(starts_on, granularity)
      case granularity
      when :day then l(starts_on, format: :long)
      when :month then starts_on.strftime("%B %Y")
      when :year then starts_on.year.to_s
      else "#{starts_on.year}s"
      end
    end

    def analysis_timeline_tallies(summary)
      summary.timeline.map do |bucket|
        FieldSummary::Tally.new(
          label: analysis_period(bucket.starts_on, summary.granularity),
          count: bucket.count,
          share: bucket.share
        )
      end
    end
  end
end
