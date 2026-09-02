require "test_helper"

class FieldSummaryTest < ActiveSupport::TestCase
  test "a field with no submissions has nothing to report" do
    summary = fields(:team).summary_of([])

    assert_equal 0, summary.answered_count
    assert_equal 0, summary.unanswered_count
    assert_not summary.answered?
    assert_nil summary.response_rate
    assert_not summary.sparse?
  end

  test "a field nobody answered counts everybody as having left it blank" do
    submissions = [ answer(users(:member), {}), answer(users(:another_member), {}) ]
    summary = fields(:team).summary_of(submissions)

    assert_equal 0, summary.answered_count
    assert_equal 2, summary.unanswered_count
    assert_in_delta 0.0, summary.response_rate
    assert_equal [ 0, 0, 0 ], summary.tallies.map(&:count)
    assert_equal [ 0.0, 0.0, 0.0 ], summary.tallies.map(&:share)
  end

  test "the response rate is the share of submissions that answered" do
    submissions = [
      answer(users(:member), fields(:team) => "Design"),
      answer(users(:another_member), {}),
      answer(users(:admin), fields(:team) => "Support"),
      answer(users(:other_admin), {})
    ]

    summary = fields(:team).summary_of(submissions)

    assert_equal 2, summary.answered_count
    assert_equal 2, summary.unanswered_count
    assert_in_delta 0.5, summary.response_rate
  end

  test "a single answer is reported as sparse" do
    summary = fields(:team).summary_of([ answer(users(:member), fields(:team) => "Design") ])

    assert summary.sparse?
  end

  test "five answers are no longer sparse" do
    summary = fields(:team).summary_of(five_team_answers)

    assert_not summary.sparse?
  end

  # Choice fields

  test "a select field counts every choice it offers, including the unpicked ones" do
    summary = fields(:team).summary_of(five_team_answers)

    assert_equal :choices, summary.kind
    assert_equal %w[Design Engineering Support], summary.tallies.map(&:label)
    assert_equal [ 3, 2, 0 ], summary.tallies.map(&:count)
    assert_in_delta 0.6, summary.tallies.first.share
    assert_in_delta 0.0, summary.tallies.last.share
  end

  test "a single choice field's shares add up to the whole" do
    summary = fields(:team).summary_of(five_team_answers)

    assert_in_delta 1.0, summary.tallies.sum(&:share)
    assert_not summary.multiple?
  end

  test "a check box field's shares are of the people who answered, not of the selections" do
    perks = fields(:perks)
    submissions = [
      answer(users(:member), perks => %w[Gym Transit]),
      answer(users(:another_member), perks => %w[Gym]),
      answer(users(:admin), {}),
      answer(users(:other_admin), perks => %w[Transit])
    ]

    summary = perks.summary_of(submissions)

    assert summary.multiple?
    assert_equal 3, summary.answered_count
    assert_equal 4, summary.selection_count
    assert_equal({ "Gym" => 2, "Transit" => 2 }, summary.tallies.to_h { |tally| [ tally.label, tally.count ] })
    # Two thirds each: deliberately more than the whole, because people picked both.
    assert_in_delta 0.6666, summary.tallies.first.share, 0.001
    assert_operator summary.tallies.sum(&:share), :>, 1.0
  end

  test "a check box field nobody ticked reports no selections rather than dividing by zero" do
    summary = fields(:perks).summary_of([ answer(users(:member), fields(:perks) => []) ])

    assert_equal 0, summary.answered_count
    assert_equal 0, summary.selection_count
    assert_equal [ 0.0, 0.0 ], summary.tallies.map(&:share)
  end

  test "answers stored before the choices changed are counted and named separately" do
    team = fields(:team)
    submission = answer(users(:member), team => "Design")
    submission.values[team.id.to_s] = "Marketing"

    summary = team.summary_of([ submission ])

    assert summary.unexpected?
    assert_equal %w[Marketing], summary.unexpected_tallies.map(&:label)
    assert_equal 1, summary.unexpected_tallies.first.count
    assert_in_delta 1.0, summary.unexpected_tallies.first.share
    assert_equal 1, summary.answered_count
    assert_equal [ 0, 0, 0 ], summary.tallies.map(&:count)
  end

  # Number fields

  test "a number field reports its range, mean and median" do
    experience = fields(:years_experience)
    summary = experience.summary_of(number_answers([ 1, 4, 9, 2 ]))

    assert_equal :numbers, summary.kind
    assert_equal BigDecimal(1), summary.minimum
    assert_equal BigDecimal(9), summary.maximum
    assert_equal BigDecimal(4), summary.mean
    assert_equal BigDecimal(3), summary.median
    assert_equal [ 1, 2, 4, 9 ].map { |value| BigDecimal(value) }, summary.sorted_answers
  end

  test "an odd number of answers takes the middle one as the median" do
    summary = fields(:years_experience).summary_of(number_answers([ 10, 1, 3 ]))

    assert_equal BigDecimal(3), summary.median
    assert_equal BigDecimal("4.666666666666666667"), summary.mean.round(18)
  end

  test "a single number is its own minimum, maximum, mean and median" do
    summary = fields(:years_experience).summary_of(number_answers([ 7 ]))

    assert_equal [ BigDecimal(7) ] * 4,
                 [ summary.minimum, summary.maximum, summary.mean, summary.median ]
    assert summary.sparse?
  end

  test "an unanswered number field has no statistics rather than zeroed ones" do
    summary = fields(:years_experience).summary_of([ answer(users(:member), {}) ])

    assert_nil summary.minimum
    assert_nil summary.maximum
    assert_nil summary.mean
    assert_nil summary.median
  end

  test "a zero answer counts as an answer" do
    summary = fields(:years_experience).summary_of(number_answers([ 0 ]))

    assert_equal 1, summary.answered_count
    assert_equal BigDecimal(0), summary.minimum
  end

  # Date fields

  test "a date field reports its range and buckets a short span by day" do
    summary = fields(:start_date).summary_of(
      date_answers([ "2026-03-01", "2026-03-03", "2026-03-03" ])
    )

    assert_equal :dates, summary.kind
    assert_equal Date.new(2026, 3, 1), summary.earliest
    assert_equal Date.new(2026, 3, 3), summary.latest
    assert_equal 2, summary.span_in_days
    assert_equal :day, summary.granularity
    assert_equal [ Date.new(2026, 3, 1), Date.new(2026, 3, 2), Date.new(2026, 3, 3) ],
                 summary.timeline.map(&:starts_on)
    assert_equal [ 1, 0, 2 ], summary.timeline.map(&:count)
    assert_in_delta 0.6666, summary.busiest_share, 0.001
  end

  test "a span of months is bucketed by month with the empty months kept" do
    summary = fields(:start_date).summary_of(
      date_answers([ "2026-01-15", "2026-03-02" ])
    )

    assert_equal :month, summary.granularity
    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 2, 1), Date.new(2026, 3, 1) ],
                 summary.timeline.map(&:starts_on)
    assert_equal [ 1, 0, 1 ], summary.timeline.map(&:count)
  end

  test "a span of years is bucketed by year and a lifetime by decade" do
    years = fields(:start_date).summary_of(date_answers([ "2019-01-15", "2026-03-02" ]))

    assert_equal :year, years.granularity
    assert_equal 8, years.timeline.size

    lifetimes = fields(:start_date).summary_of(date_answers([ "1958-01-15", "2026-03-02" ]))

    assert_equal :decade, lifetimes.granularity
    assert_equal Date.new(1950, 1, 1), lifetimes.timeline.first.starts_on
    assert_equal Date.new(2020, 1, 1), lifetimes.timeline.last.starts_on
  end

  test "one date has a span of no days and a timeline of one bucket" do
    summary = fields(:start_date).summary_of(date_answers([ "2026-03-01" ]))

    assert_equal 0, summary.span_in_days
    assert_equal 1, summary.timeline.size
  end

  test "an unanswered date field has no range and an empty timeline" do
    summary = fields(:start_date).summary_of([ answer(users(:member), {}) ])

    assert_nil summary.earliest
    assert_nil summary.span_in_days
    assert_nil summary.granularity
    assert_equal [], summary.timeline
    assert_in_delta 0.0, summary.busiest_share
  end

  # Free text fields

  test "a text field counts its answers and keeps a sample of them" do
    name = fields(:full_name)
    summary = name.summary_of([
      answer(users(:member), name => "Ada"),
      answer(users(:another_member), name => "Grace"),
      answer(users(:admin), name => "Ada")
    ])

    assert_equal :texts, summary.kind
    assert_equal 3, summary.answered_count
    assert_equal 2, summary.distinct_count
    assert summary.repeated?
    assert_equal %w[Ada Grace], summary.examples
    assert_equal 0, summary.unshown_count
  end

  test "a text field shows at most five answers and says how many it left out" do
    name = fields(:full_name)
    submissions = %w[Ada Grace Alan Edsger Barbara Donald Ken].map do |value|
      answer(another_user, name => value)
    end

    summary = name.summary_of(submissions)

    assert_equal 5, summary.examples.size
    assert_equal %w[Ada Grace Alan Edsger Barbara], summary.examples
    assert_equal 2, summary.unshown_count
    assert_not summary.repeated?
  end

  private

    # Answers are cast on save, so the summaries see exactly what the database holds.
    def answer(user, answers)
      values = answers.transform_keys { |field| field.id.to_s }

      Submission.create!(form: forms(:survey), user: user,
                         values: values.reverse_merge(fields(:full_name).id.to_s => "Someone"))
    end

    # Every submission needs a user of its own: nobody fills a form out twice.
    def another_user
      @user_count = @user_count.to_i + 1

      User.create!(email: "analysis#{@user_count}@example.com", password: "password123")
    end

    def five_team_answers
      %w[Design Design Engineering Engineering Design].map do |choice|
        answer(another_user, fields(:team) => choice)
      end
    end

    def number_answers(values)
      typed_answers(fields(:years_experience), values)
    end

    def date_answers(values)
      typed_answers(fields(:start_date), values)
    end

    def typed_answers(field, values)
      values.map { |value| answer(another_user, field => value) }
    end
end
