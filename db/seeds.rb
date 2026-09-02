# Creates one admin, one member, and a form that exercises every input type, so a fresh
# checkout has something to sign in to and something to fill out.
#
# Run with: bin/rails db:seed

admin = User.find_or_initialize_by(email: "admin@formz.test")
admin.password = "password123" if admin.new_record?
admin.admin = true
admin.save!

member = User.find_or_initialize_by(email: "member@formz.test")
member.password = "password123" if member.new_record?
member.save!

form = admin.forms.find_or_initialize_by(name: "Onboarding survey")

if form.new_record?
  form.description = "A sample form covering every input type Formz supports."
  form.fields_attributes = [
    { label: "Full name", input_type: :text_field, value_type: :string, required: true },
    { label: "Preferred contact email", input_type: :email_field, value_type: :string },
    { label: "Phone number", input_type: :telephone_field, value_type: :string,
      description: "Optional, only used if we cannot reach you by email" },
    { label: "Portfolio URL", input_type: :url_field, value_type: :string },
    { label: "Years of experience", input_type: :number_field, value_type: :number, required: true },
    { label: "Start date", input_type: :date_field, value_type: :date, required: true },
    { label: "Team", input_type: :select, value_type: :string,
      choices: [ "Design", "Engineering", "Support" ], required: true },
    { label: "Working pattern", input_type: :radio_button, value_type: :string,
      choices: [ "Onsite", "Hybrid", "Remote" ] },
    { label: "Perks used", input_type: :check_box, value_type: :string,
      choices: [ "Gym", "Transit", "Learning budget" ],
      description: "Tick every one that applies" },
    { label: "Anything else we should know?", input_type: :text_area, value_type: :string }
  ]
  form.save!
end

puts "Seeded #{User.count} users and #{Form.count} form(s)."
puts "  admin:  #{admin.email} / password123"
puts "  member: #{member.email} / password123"
puts
puts "Promote another user from the console with:"
puts %(  User.find_by(email: "someone@example.com").update(admin: true))
