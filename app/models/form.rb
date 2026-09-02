require "csv"

class Form < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :forms

  has_many :fields, -> { order(:position) }, dependent: :destroy, inverse_of: :form
  has_many :submissions, dependent: :destroy, inverse_of: :form

  accepts_nested_attributes_for :fields, allow_destroy: true, reject_if: :all_blank

  scope :active, -> { where(active: true) }

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

  def deleted?
    !active?
  end

  def soft_delete
    update(active: false)
  end

  def restore
    update(active: true)
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
