# What one field's answers add up to. Every number is computed in Ruby from submissions
# that are already loaded, so a form with fifty fields costs no more queries than one
# with a single field. Field#summary_of picks the subclass that matches the shape of the
# answers, because which numbers can honestly be drawn out of an answer is a property of
# the field that asked for it.
class FieldSummary
  # One row of a distribution: how many answers fall into a group, and what share of the
  # answers that group is.
  Tally = Data.define(:label, :count, :share)

  attr_reader :field, :submissions

  def initialize(field, submissions)
    @field = field
    @submissions = submissions
  end

  # :choices, :numbers, :dates or :texts. The shape of the answers decides both what can
  # honestly be said about them and which partial says it.
  def kind
    self.class.name.demodulize.underscore.to_sym
  end

  def answers
    @answers ||= submissions.select { |submission| submission.answered?(field) }
                            .map { |submission| submission.answer_for(field) }
  end

  def submission_count
    submissions.size
  end

  def answered_count
    answers.size
  end

  def unanswered_count
    submission_count - answered_count
  end

  def answered?
    answers.any?
  end

  def response_rate
    return if submissions.empty?

    answered_count.fdiv(submission_count)
  end

  # Below this many answers, a percentage or an average says more about who happened to
  # reply than about the answers. The page says so rather than presenting the number as
  # though it settled something.
  def sparse?
    answered? && answered_count < 5
  end

  private

    def share_of(count)
      return 0.0 if answered_count.zero?

      count.fdiv(answered_count)
    end
end
