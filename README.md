# Formz

A generic form builder. Admins compose forms out of typed fields, every user fills each
form out once, and admins review the answers and export them as CSV.

## Requirements

- Ruby 4.0.1 (see `.ruby-version`)
- PostgreSQL

## Getting started

```bash
bin/setup            # installs gems, prepares the database
bin/rails db:seed    # one admin, one member, and a sample form
bin/dev              # Rails plus the Tailwind watcher
```

The seeds create `admin@formz.test` and `member@formz.test`, both with the password
`password123`.

## Admin users

Admin status is granted from the Rails console only — there is no way to request it
through the sign-up form, and `admin` is not a permitted parameter anywhere.

```ruby
User.find_by(email: "someone@example.com").update(admin: true)
```

An admin lands on the forms they own and can create, edit, delete and export them.
Everyone else lands on the list of forms available to fill out.

## How it fits together

- A **Form** belongs to the admin who owns it and has many **Fields**.
- A **Field** has an `input_type` named after the Rails form builder method that renders
  it (`text_field`, `select`, `check_box`, …) and a `value_type` of string, number or date.
- A **Submission** belongs to a form and a user, holds its answers in a JSONB column keyed
  by field id, and is unique per user per form.

Two rules shape the editing experience:

- A form **locks its structure** once anyone has answered it. The name and description stay
  editable; fields do not, so every stored submission still matches the form it was
  answered on.
- Deleting a form is a **soft delete**. It disappears for members, stays listed for its
  owner, and its submissions remain viewable and exportable.

## Tests

```bash
bin/rails test              # models, controllers, integration
bin/rails test:system       # browser tests
bin/rubocop                 # rubocop-rails-omakase
```

## Conventions

Code follows `~/.claude/skills/rails-conventions/SKILL.md`. The build plan lives in
[docs/implementation-plan.md](docs/implementation-plan.md).
