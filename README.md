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

### Analysing the answers

**Analysis**, on a form you own, summarises what the answers add up to. It opens with the
submission count, the period they were collected over, the share of possible answers actually
given, and how many people left nothing blank.

Below that, every question gets a card that always states how many people answered it and how
many left it blank, then summarises the answers in the way that question's type allows:

| Question type | What you get |
|---|---|
| Select, radio button, check box | A bar per option with counts and shares, including options nobody picked |
| Number field | Smallest, largest, mean, and median |
| Date field | Earliest, latest, the range in days, and a timeline of when answers landed |
| Text field, text area | How many wrote something, how many distinct answers, and a sample of them |

A few details worth knowing before you read too much into a number:

- **Shares are of the people who answered that question**, not of everyone who submitted the
  form. Each card says so.
- **Check-box shares can add up to more than 100%**, because one person can pick several
  options. The card says how many options were picked in total.
- **A question with four or fewer answers is flagged**, and number questions then list every
  answer instead of averaging them. With three responses the list is the analysis.
- **Options nobody picked still appear**, at zero. A choice nobody made is a result.
- **Answers that are no longer valid choices** — because the question's options were changed
  before anyone answered, or the data was written directly — are counted and listed under
  their own heading rather than quietly dropped.
- Free text is **not** summarised into sentiment, keyword counts, or a word cloud. You get
  counts and a sample, with the submissions table for the rest.

Deleted forms can still be analysed, on the same reasoning that they can still be exported.

## How it fits together

- A **Form** belongs to the administrator who owns it and has many **Fields**.
- A **Field** has an `input_type` named after the Rails form builder method that renders it
  (`text_field`, `select`, `check_box`, …) and a `value_type` of string, number, or date.
- A **Submission** belongs to a form and a user, holds its answers in a JSONB column keyed by
  field id, and is unique per user per form — that uniqueness is enforced by a database index,
  not only by a validation.

## Ran Out Of Time

Two things that were asked for and are not here. Both are scoping decisions recorded as
assumptions in [docs/implementation-plan.md](docs/implementation-plan.md).

### Custom input types

`Field#input_type` is an enum whose keys are Rails form builder method names, and
`app/views/submissions/_field_input.html.erb` renders a field with
`value_form.public_send field.input_type, field.id, ...`. The enum constrains the column to
its own keys, so that dispatch is an allowlist by construction.

For an input type that renders through a form builder method, adding one is a key in the
enum in `app/models/field.rb` and a row in the table above.
`FieldsHelper#field_input_type_options` builds the editor's dropdown from
`Field.input_types`, so the new type shows up in the field editor with no view change — add
a case to `field_input_type_label` only if `humanize` gets the label wrong, as it does for
`url_field`.

This extends to your own helpers. `app/views/submissions/new.html.erb` uses the default
`form_with` builder; hand it a `builder:` that subclasses `ActionView::Helpers::FormBuilder`
and any method on that subclass is reachable by the same `public_send`. A bespoke control is
an enum key plus a method.

Two parts are not free:

- **Value type.** `FieldTypeCompatibilityValidator` maps `number_field` to `number`,
  `date_field` to `date`, and everything else to `string`. A type that stores a number or a
  date needs a branch there. A type storing something none of the three value types covers
  needs a new `value_type` key and a matching branch in `Field#cast`.
- **Choices.** `Field#choice_based?` names `select`, `radio_button` and `check_box`
  explicitly, and `FieldChoicesValidator` rejects choices on anything else, so a type that
  offers a set of options has to be added there. The editor's choices textarea then follows
  for free, because `field_type_controller.js` is handed
  `FieldsHelper#choice_based_input_types`. The rendering does not: the three existing
  choice-based types skip `public_send` entirely and have their own branches in
  `_field_input`, going through `select`, `collection_radio_buttons` and
  `collection_check_boxes`. A type that collects more than one answer also needs adding to
  `Field#multiple_choice?`, which is what makes `cast` return an array, and to
  `permitted_value_keys` in `app/controllers/submissions_controller.rb`, which is what
  permits an array parameter rather than a scalar.

**File upload is the exception to "cheap".** The dispatch is genuinely trivial — `file_field`
is a form builder method like any other — but an answer lives in the `values` JSONB column on
`submissions`, keyed by field id, holding what `Field#cast` produces: a string, a number, a
date, or an array of choices. Bytes are not one of those. File upload needs Active Storage —
`bin/rails active_storage:install` has never been run here, there are no `active_storage_*`
tables in `db/schema.rb` — and somewhere to hang the attachment other than the `values` hash,
most likely a record per uploaded answer joined to a submission and a field. `Field#cast`,
`SubmissionValuesValidator`, `Submission#display_value_for` and the CSV export each then need
to know what a file answer is. Trivial to dispatch to; not trivial to store.

### Draft and publish

There is no draft state and no publish step. A form is visible to every member the moment it
is created: `FormsController#index` lists `Form.active`, `active` defaults to true, and
nothing else gates visibility. That includes a form with no questions yet, which appears in
**All forms** with a **Fill out** button and renders a submit button under "This form has no
questions yet".

That empty case collides with the structure lock. Submitting an empty form succeeds and
stores an empty `values` hash, which makes `Form#locked?` true, which means the questions can
never be added — the form is finished before it was written.

Soft delete is the only mechanism that currently takes a form out of circulation, and it is
not a stand-in for a draft state: a deleted form refuses every edit except its own `active`
flag, so it cannot be used to hide a form while it is being built. `Form#restore` exists on
the model, but no route or controller calls it, so the way back is the console.

The fix is a `published` boolean on `forms`, the member-facing queries in
`FormsController` and `SubmissionsController` checking it alongside `active`, and a publish
action in the admin editor.

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
