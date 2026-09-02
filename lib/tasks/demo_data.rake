# Demo data for exercising Formz with something more lifelike than the fixtures: one
# form and a hundred submissions to it, with answers spread the way real answers are
# spread rather than evenly or identically.
#
#   bin/rails formz:demo_data            # the default, repeatable, dataset
#   bin/rails formz:demo_data SEED=42    # a different but equally repeatable dataset

# The questions the demo form asks, and how a person answers each one. Keeping the two
# together is what makes the shape of the generated data readable: the weights and the
# spread sit next to the field they belong to, and the choices are derived from the
# weights rather than repeated alongside them.
class DemoSurvey
  def initialize(seed)
    @random = Random.new(seed)
  end

  def name
    "Developer experience survey"
  end

  def description
    "Demo data. A hundred answers with distributions worth looking at."
  end

  def field_attributes
    questions.map { |question| question.except(:answer) }
  end

  # Answers keyed by field id as a string, shaped the way a browser would post them:
  # strings, and an array for the check box field. An unanswered optional question is
  # left out entirely.
  def answers_for(fields)
    fields.zip(questions).each_with_object({}) do |(field, question), answers|
      answer = question[:answer].call
      answers[field.id.to_s] = answer if answer.present?
    end
  end

  private

    attr_reader :random

    def questions
      @questions ||= [
        {
          label: "Full name",
          input_type: :text_field, value_type: :string, required: true,
          answer: -> { full_name }
        },
        {
          label: "Team",
          description: "The team you spend most of your week with",
          input_type: :select, value_type: :string, required: true,
          choices: team_weights.keys,
          answer: -> { weighted_choice(team_weights) }
        },
        {
          label: "Working pattern",
          input_type: :radio_button, value_type: :string, required: true,
          choices: working_pattern_weights.keys,
          answer: -> { weighted_choice(working_pattern_weights) }
        },
        {
          label: "Tools used daily",
          description: "Tick every one that applies",
          input_type: :check_box, value_type: :string,
          choices: tool_likelihoods.keys,
          answer: -> { chosen_from(tool_likelihoods) }
        },
        {
          label: "Years of experience",
          input_type: :number_field, value_type: :number, required: true,
          answer: -> { skewed_towards_low(1..24, bias: 2.4).to_s }
        },
        {
          label: "Hours a week lost waiting for builds",
          description: "Roughly, to the nearest hour",
          input_type: :number_field, value_type: :number,
          answer: -> { answered_by(0.72) { skewed_towards_low(0..16, bias: 2.0).to_s } }
        },
        {
          label: "Satisfaction with our tooling",
          description: "1 is miserable, 10 is delighted",
          input_type: :number_field, value_type: :number, required: true,
          answer: -> { skewed_towards_high(1..10, bias: 2.2).to_s }
        },
        {
          label: "Joined the company",
          input_type: :date_field, value_type: :date, required: true,
          answer: -> { days_ago(0..2190, bias: 1.7).iso8601 }
        },
        {
          label: "Last one to one with your manager",
          input_type: :date_field, value_type: :date,
          answer: -> { answered_by(0.64) { days_ago(0..120, bias: 1.3).iso8601 } }
        },
        {
          label: "Anything else we should know?",
          input_type: :text_area, value_type: :string,
          answer: -> { answered_by(0.21) { one_of(remarks) } }
        }
      ]
    end

    def team_weights
      { "Engineering" => 38, "Support" => 22, "Design" => 16, "Operations" => 14, "Marketing" => 10 }
    end

    def working_pattern_weights
      { "Hybrid" => 54, "Remote" => 31, "Onsite" => 15 }
    end

    def tool_likelihoods
      { "Editor" => 0.94, "Terminal" => 0.78, "Debugger" => 0.46, "Profiler" => 0.19, "Notebook" => 0.12 }
    end

    def full_name
      "#{one_of(first_names)} #{one_of(last_names)}"
    end

    def first_names
      %w[Amara Bruno Cerys Dmitri Elena Farid Greta Hassan Imogen Jonas
         Keiko Lucia Malik Nadia Oskar Priya Quentin Rosa Soren Tamsin]
    end

    def last_names
      %w[Abara Beaumont Castellanos Delacroix Eriksen Falconer Gutierrez Halvorsen
         Ibrahim Janssen Kowalski Lindqvist Moreau Nakamura Okonkwo Pereira]
    end

    def remarks
      [
        "The onboarding docs were out of date on my first day.",
        "Builds are the single biggest drag on my week.",
        "Happy overall, but code review turnaround could be faster.",
        "More pairing time would help the newer people on the team.",
        "The staging environment is unreliable on Friday afternoons.",
        "Nothing to add, things are working well."
      ]
    end

    # Returns the choice whose weight the throw lands in, so a choice weighted 38 out of
    # 100 comes up about 38 times in a hundred draws.
    def weighted_choice(weights)
      throw_at = random.rand(weights.values.sum)
      running_total = 0

      weights.each do |choice, weight|
        running_total += weight
        return choice if running_total > throw_at
      end
    end

    # Every choice decided independently, which is how a check box set is answered.
    def chosen_from(likelihoods)
      likelihoods.select { |_choice, likelihood| random.rand < likelihood }.keys
    end

    def answered_by(likelihood)
      yield if random.rand < likelihood
    end

    def one_of(values)
      values[random.rand(values.size)]
    end

    # Raising a 0..1 throw to a power above 1 pulls it towards zero, so a bias of 2
    # bunches the results near the bottom of the range and leaves a thin tail at the top.
    # A bias of 1 is an even spread.
    def skewed_towards_low(range, bias:)
      range.min + ((range.max - range.min) * random.rand**bias).round
    end

    def skewed_towards_high(range, bias:)
      range.max - ((range.max - range.min) * random.rand**bias).round
    end

    def days_ago(range, bias:)
      Date.current - skewed_towards_low(range, bias: bias)
    end
end

# Builds the demo form, the disposable users who answer it, and their submissions, then
# reports what it made.
class DemoDataGenerator
  def initialize(seed:, output: $stdout)
    @seed = seed
    @survey = DemoSurvey.new(seed)
    @output = output
  end

  def generate
    ActiveRecord::Base.transaction do
      @replaced = remove_previous_demo_data
      @form = create_form
      create_submissions(create_people)
    end

    report
    form
  end

  private

    attr_reader :seed, :survey, :output, :form, :replaced

    def submission_count
      100
    end

    # Everything this task creates is inside its own namespace: one form name owned by
    # the demo owner, and users on a domain nothing else in the app uses. A second run
    # deletes that namespace and rebuilds it, so it can never disturb real data and can
    # never leave a half-populated form behind.
    def remove_previous_demo_data
      previous = { forms: owner.forms.where(name: survey.name).count, users: demo_users.count }

      owner.forms.where(name: survey.name).destroy_all
      demo_users.destroy_all
      previous
    end

    def demo_users
      User.where("email LIKE :pattern", pattern: "demo-%@#{demo_email_domain}")
    end

    def demo_email_domain
      "formz.demo"
    end

    def demo_email(number)
      format("demo-%03d@%s", number, demo_email_domain)
    end

    # The same admin db/seeds.rb creates, created the same way if the seeds have not run.
    def owner
      @owner ||= User.find_or_initialize_by(email: "admin@formz.test").tap do |admin|
        admin.password = demo_password if admin.new_record?
        admin.admin = true
        admin.save!
      end
    end

    def demo_password
      "password123"
    end

    def create_form
      owner.forms.create!(name: survey.name, description: survey.description,
                          fields_attributes: survey.field_attributes)
    end

    # One insert for the whole cohort. Devise hashes a password at cost 12 outside the
    # test environment, so hashing once and reusing the digest is the difference between
    # a second and half a minute.
    def create_people
      hashed_password = User.new(password: demo_password).encrypted_password
      now = Time.current
      rows = (1..submission_count).map do |number|
        { email: demo_email(number), encrypted_password: hashed_password,
          created_at: now, updated_at: now }
      end

      User.insert_all(rows)
      demo_users.order(:email).to_a
    end

    # Saved one at a time and through the model on purpose: the answers are validated and
    # cast exactly as a browser's would be, so the demo data cannot drift from what the
    # app itself would have stored. The form and its fields are loaded once and shared, so
    # the only per-submission queries are the uniqueness check and the insert.
    def create_submissions(people)
      fields = form.fields.to_a

      people.each do |person|
        Submission.create!(form: form, user: person, values: survey.answers_for(fields))
      end
    end

    def report
      output.puts "Formz demo data, seed #{seed}"
      output.puts
      report_line "Owner", owner.email
      report_line "Form", "#{form.name} (id #{form.id}, #{form.fields.size} fields)"
      report_line "People", "#{submission_count} disposable users, " \
                            "#{demo_email(1)} to #{demo_email(submission_count)}, password #{demo_password}"
      report_line "Submissions", form.submissions.count.to_s
      report_line "Replaced", "#{replaced[:forms]} form(s) and #{replaced[:users]} users from a previous run"
      output.puts
      report_answers
      output.puts
      output.puts "Repeat this exact dataset with SEED=#{seed}, or vary it with any other SEED."
    end

    def report_answers
      submissions = form.submissions.to_a

      form.fields.each do |field|
        answers = submissions.filter_map { |submission| submission.answer_for(field).presence }
        report_line field.label, "#{field_summary(field, answers)}#{unanswered_note(answers)}"
      end
    end

    def report_line(label, value)
      output.puts format("  %-36s %s", label, value)
    end

    def field_summary(field, answers)
      if field.choice_based?
        choice_tally(answers)
      elsif field.value_number?
        number_spread(answers)
      elsif field.value_date?
        date_spread(answers)
      else
        "#{answers.size} answered"
      end
    end

    def choice_tally(answers)
      answers.flatten.tally.sort_by { |_choice, count| -count }
             .map { |choice, count| "#{choice} #{count}" }.join(", ")
    end

    def number_spread(answers)
      sorted = answers.map(&:to_i).sort

      "min #{sorted.first}, median #{sorted[sorted.size / 2]}, max #{sorted.last}, mean #{mean(sorted)}"
    end

    def mean(numbers)
      (numbers.sum.to_f / numbers.size).round(1)
    end

    def date_spread(answers)
      sorted = answers.sort

      "#{sorted.first.iso8601} to #{sorted.last.iso8601}, median #{sorted[sorted.size / 2].iso8601}"
    end

    def unanswered_note(answers)
      blanks = submission_count - answers.size
      blanks.zero? ? "" : " (#{blanks} unanswered)"
    end
end

namespace :formz do
  desc "Generate a demo form owned by admin@formz.test with 100 varied submissions (SEED=n to vary the data)"
  task demo_data: :environment do
    # A fixed default so every developer, and every re-run, gets the same dataset unless
    # they deliberately ask for a different one.
    seed = Integer(ENV.fetch("SEED", "20260902"))

    DemoDataGenerator.new(seed: seed).generate
  end
end
