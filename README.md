# Formz

Formz is a form builder. Administrators compose forms out of typed fields — text, numbers,
dates, dropdowns, radio buttons, check boxes — and everyone else fills each form out once.
Administrators then review the answers in the browser or export them as CSV.

Answers are stored as structured, typed data rather than free text, so a number field holds
a number and a date field holds a date. That is the groundwork for the analysis and insight
tools the app is heading towards.

## Requirements

- Ruby 4.0.1 (see `.ruby-version`)
- PostgreSQL, running locally

The app connects to PostgreSQL as your operating system user, with no password. If your
server is set up differently, adjust `config/database.yml`.

## Getting started

```bash
git clone <repository-url> formz
cd formz

bin/setup --skip-server   # installs gems and creates the databases
bin/rails db:seed         # an admin, a member, and a sample form
bin/dev                   # Rails plus the Tailwind watcher
```

Then open http://localhost:3000.

`bin/setup` on its own does the same thing and starts the server immediately, which is
handy once you have seeded. `bin/dev` runs Rails and the Tailwind rebuild together — start
the app that way rather than with `bin/rails server`, or your CSS will not rebuild as you
edit.

### Accounts

The seeds create two accounts, both with the password `password123`:

| Email | Role |
|---|---|
| `admin@formz.test` | Administrator, owns the sample form |
| `member@formz.test` | Regular member |

Anyone can create their own account from the sign-up page, but **sign-up can never grant
administrator rights** — `admin` is not a permitted parameter anywhere in the app. Promote
someone from the Rails console instead:

```ruby
User.find_by(email: "someone@example.com").update(admin: true)
```

Sign in and Formz sends you where you belong: administrators land on the forms they own,
everyone else on the list of forms waiting to be filled out.

## Using Formz

### Building a form

From **My forms**, choose **New form**. Give it a name, an optional description, and then
add as many questions as you need with **Add field**. Each question has:

- **Question** — the label people answer, and the column heading in the CSV export.
- **Help text** — optional, shown under the question.
- **Input type** — the control people see.
- **Stores** — the kind of value the answer is kept as.
- **An answer is required** — whether the form can be submitted without it.
- **Choices** — one option per line, for the input types that offer a set of options.

Questions are asked in the order they appear in the editor.

### Input types

The input type decides both what people see and how the answer is stored. The two must
agree, and Formz will tell you if they do not:

| Input type | Stores | Notes |
|---|---|---|
| Text field | String | A single line |
| Text area | String | Several lines |
| Email field, Telephone field, URL field | String | The browser validates the format |
| Number field | Number | Stored as a number, not text |
| Date field | Date | Stored as a date |
| Select | String | Needs choices |
| Radio button | String | Needs choices, one answer |
| Check box | String | Needs choices, any number of answers |

### Editing, and why a form eventually stops changing

A form can be edited freely until somebody answers it. From the first submission onward its
**structure is locked**: the name and description stay editable, but fields cannot be added,
removed, or retyped. This is deliberate — changing the questions under answers already given
would leave those answers describing questions that no longer exist. The editor says so
plainly when it happens.

### Deleting a form

Deleting is a soft delete, so nothing anyone submitted is ever thrown away. A deleted form:

- disappears from the list members see, and can no longer be filled out
- stays in **My forms**, marked as deleted, and is still fully viewable
- keeps its submissions, which remain readable and exportable

### Filling a form out

Members see every active form at **All forms** and can fill each one out exactly once.
Questions marked with a red asterisk must be answered. After submitting, the form moves to
"Completed" and the answers are available to re-read at any time — but not to change.

### Reading the answers

From a form you own, choose **Submissions** for a table of every answer, one row per person
and one column per question. **Download CSV** gives you the same data as a file, with
`Submitted by` and `Submitted at` ahead of the question columns. Both work for deleted forms
too.

## How it fits together

- A **Form** belongs to the administrator who owns it and has many **Fields**.
- A **Field** has an `input_type` named after the Rails form builder method that renders it
  (`text_field`, `select`, `check_box`, …) and a `value_type` of string, number, or date.
- A **Submission** belongs to a form and a user, holds its answers in a JSONB column keyed by
  field id, and is unique per user per form — that uniqueness is enforced by a database index,
  not only by a validation.

## Tests

```bash
bin/rails test           # models, controllers, integration
bin/rails test:system    # browser tests, needs Google Chrome
bin/rubocop              # rubocop-rails-omakase
```

## Conventions

Code follows `~/.claude/skills/rails-conventions/SKILL.md`. The build plan, including the
decisions behind the structure lock and the soft delete, is in
[docs/implementation-plan.md](docs/implementation-plan.md).
