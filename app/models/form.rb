require "csv"

class Form < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :forms

  has_many :fields, -> { order(:position) }, dependent: :destroy, inverse_of: :form
  has_many :submissions, dependent: :destroy, inverse_of: :form

  # A new row with no label is an untouched row in the editor. :all_blank cannot see
  # that, because the type selects and the required checkbox always submit a value.
  accepts_nested_attributes_for :fields, allow_destroy: true,
                                reject_if: ->(attributes) { attributes["id"].blank? && attributes["label"].blank? }

  scope :active, -> { where(active: true) }

  # A form with no questions has nothing to answer, so it stays out of the member facing
  # list until its owner has written it. Subquery rather than a join, so a form with many
  # fields still comes back once.
  scope :answerable, -> { active.where(id: Field.select(:form_id)) }
  scope :answerable_or_owned_by, ->(user) { answerable.or(active.where(owner: user)) }

  validates :name, presence: true
  validate :fields_unchanged_when_locked, if: :locked?
  validate :deleted_form_unchanged, on: :update

  before_validation :assign_field_positions

  # A form stops accepting structural changes the moment someone has answered it,
  # so every stored submission still matches the form it was answered on.
  def locked?
    submissions.exists?
  end

  def editable?
    active?
  end

  def answerable?
    active? && fields.any?
  end

  def owned_by?(user)
    owner_id == user.id
  end

  def deleted?
    !active?
  end

  def soft_delete
    update(active: false)
  end

  def restore
    update(active: true)
  end

  # What the answers add up to. Nothing about it is stored: it is read only, and derived
  # from submissions that cannot change once they are made.
  def analysis
    FormAnalysis.new(self)
  end

  def submissions_csv
    CSV.generate do |csv|
      csv << [ "Submitted by", "Submitted at", *fields.map(&:label) ]

      submissions.includes(:user).order(:created_at).each do |submission|
        csv << [ submission.user.email, submission.created_at.iso8601,
                 *fields.map { |field| submission.display_value_for(field) } ]
      end
    end
  end

  private

    # Positions are renumbered from the order the fields arrive in, which is the order
    # the admin arranged them in the editor.
    def assign_field_positions
      fields.reject(&:marked_for_destruction?).each_with_index do |field, index|
        field.position = index + 1
      end
    end

    def fields_unchanged_when_locked
      return unless structure_changed?

      errors.add(:base, "Fields cannot be changed once the form has submissions")
    end

    # A deleted form is read only. The active flag itself may still change so that a
    # restore stays possible.
    def deleted_form_unchanged
      return unless active_in_database == false
      return if (changed_attributes.keys - [ "active" ]).empty? && !structure_changed?

      errors.add(:base, "A deleted form cannot be edited")
    end

    def structure_changed?
      fields.any? { |field| field.new_record? || field.changed? || field.marked_for_destruction? }
    end
end
