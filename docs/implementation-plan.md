# Formz — MCP Implementation Plan

Formz is a generic form builder: admins compose forms out of typed fields, every user
fills each form out once, and admins review and export the results. This plan covers the
minimum complete product. Analysis and insight tools are explicitly out of scope.

All code follows `~/.claude/skills/rails-conventions/SKILL.md` and the project's
`rubocop-rails-omakase` configuration.

## Stack as it stands

Rails 8.1.3.1 on Ruby 4.0.1, PostgreSQL, Propshaft, importmap-rails, turbo-rails,
stimulus-rails, Minitest with Capybara and Selenium, Solid Queue/Cache/Cable.

## Decisions already made

| Question | Decision |
|---|---|
| Tailwind | `tailwindcss-rails` gem — standalone binary, no Node |
| Rails UJS | Turbo equivalents (`data-turbo-method`, `data-turbo-confirm`); no `rails-ujs` |
| CSV | Add `gem "csv"` — it is a bundled gem in Ruby 4.0 and does not load under Bundler without it |
| Editing a form with submissions | Structure locks: name and description stay editable, fields do not |

### Gems

Adding exactly three: `devise`, `tailwindcss-rails`, `csv`.

Deliberately not adding, to respect the ask-before-installing rule:

- **Pundit / CanCanCan** — authorization is two rules (signed in, and admin owns the form).
  A `before_action` in an `Admin::BaseController` covers it.
- **Pagy** — no pagination in the MCP. Worth revisiting the first time a form list or a
  submissions table gets long; the standards name Pagy as the preference.
- **factory_bot** — the app uses Minitest with Rails fixtures. The standards say to use
  the project's existing mechanism.

If any phase turns out to need a gem beyond those three, stop and ask.

## Assumptions

Flagged because they resolve genuine gaps in the requirements. Each is cheap to change.

1. **Admins can fill out forms too.** They are users; their submissions appear alongside
   everyone else's.
2. **No draft/published state.** Every active form is visible to every user the moment it
   exists, including one with no fields yet. A `published` flag is the natural follow-up.
3. **A user can view their own submission** read-only after submitting, but not edit it.
4. **Deleted forms disappear for members.** A soft-deleted form leaves the member index and
   can no longer be filled out. A member who already submitted keeps access to their own
   submission — the form they answered doesn't vanish from under them.
5. **No restore in the MCP.** Reactivating a deleted form is a natural companion to soft
   delete and is one action away (`Form#restore`, a button on the admin index), but it
   wasn't asked for. Say the word and it goes in — it's fifteen minutes.

## Data model

### users

Devise defaults plus `admin:boolean default: false, null: false`.

`admin` is never in permitted parameters. Devise's default sanitizer only allows email and
password, so the safe behavior is what we get by leaving it alone — and there is a test
asserting that signing up with `admin=true` in the payload produces a non-admin.

Promotion happens in the console, as specified:

```ruby
User.find_by(email: "someone@example.com").update(admin: true)
```

### forms

| Column | Type | Notes |
|---|---|---|
| `owner_id` | references users | `null: false`, FK, indexed |
| `name` | string | `null: false` |
| `description` | text | optional |
| `active` | boolean | `default: true`, `null: false` — soft-delete flag |

`belongs_to :owner, class_name: "User", inverse_of: :forms`
`has_many :fields, -> { order(:position) }, dependent: :destroy, inverse_of: :form`
`has_many :submissions, dependent: :destroy, inverse_of: :form`
`scope :active, -> { where(active: true) }`

The `dependent: :destroy` associations only matter if a form is ever hard-deleted from the
console — the app never destroys one.

### fields

| Column | Type | Notes |
|---|---|---|
| `form_id` | references forms | `null: false`, FK |
| `label` | string | `null: false` |
| `description` | text | optional |
| `input_type` | integer | enum, `null: false` |
| `value_type` | integer | enum, `null: false` |
| `choices` | string array | `default: []`, `null: false` |
| `required` | boolean | `default: false`, `null: false` — an answer must be given |
| `position` | integer | `null: false`, unique index on `[form_id, position]` |

### submissions

| Column | Type | Notes |
|---|---|---|
| `form_id` | references forms | `null: false`, FK |
| `user_id` | references users | `null: false`, FK |
| `values` | jsonb | `default: {}`, `null: false` |

Unique index on `[form_id, user_id]` — this is what actually enforces "only once"; the
model validation is the friendly error message in front of it.

> **Verify at the end of Phase 1:** Rails raises `DangerousAttributeError` on boot for
> column names that collide with Active Record internals. `values` is expected to be fine,
> but confirm the app boots before building on it. If it does collide, rename the column to
> `answers` and keep going — nothing downstream depends on the name except the CSV export.

## Enums

Both use the current Rails syntax with a prefix. The prefix is not cosmetic: without it,
`enum :input_type` generates a `Field.select` scope that shadows Active Record's own
`select`, and `value_type` would generate `Field.date` and `Field.string`.

```ruby
enum :input_type, {
  text_field: 0, text_area: 1, number_field: 2, date_field: 3, email_field: 4,
  telephone_field: 5, url_field: 6, select: 7, radio_button: 8, check_box: 9
}, prefix: :input, scopes: false, validate: true

enum :value_type, { string: 0, number: 1, date: 2 },
     prefix: :value, scopes: false, validate: true
```

The keys are exactly the Form Builder method names, which is what makes
`form.public_send(field.input_type, ...)` work when rendering. Because the enum constrains
the column to those ten values, `public_send` is dispatching against an allowlist by
construction — there is no path from user input to an arbitrary method name.

`Field#choice_based?` returns true for select, radio_button, and check_box.

### Validators

Both live in `app/validators`, per the standards.

- **`FieldChoicesValidator`** — choices must be present for choice-based inputs and empty
  for everything else.
- **`FieldTypeCompatibilityValidator`** — `number_field` pairs with `number`, `date_field`
  with `date`, everything else with `string`.

## Submission values

Stored as a JSONB hash keyed by **field id as a string**, not by label, so the data stays
attached to the field even if a label is reworded.

- `Field#cast(raw)` returns the value coerced to its `value_type` — String, BigDecimal, or
  Date. A `check_box` field with choices produces an array.
- `SubmissionValuesValidator` (in `app/validators`) rejects keys that aren't fields of the
  submission's form, values that won't cast, choice values outside `field.choices`, and a
  **missing or blank answer for any field marked `required`** — for a check-box field that
  means an empty array counts as missing. The error is attached per field so the fill-out
  form can show it next to the input that caused it.

Strong parameters build their allowlist from the form itself rather than accepting an open
hash — this is the one place the app would otherwise drift toward `permit!`:

```ruby
def submission_params
  params.require(:submission).permit(values: permitted_value_keys)
end

def permitted_value_keys
  @form.fields.map do |field|
    field.input_check_box? ? { field.id.to_s => [] } : field.id.to_s
  end
end
```

## Two independent gates on editing

A form can be closed to edits for two unrelated reasons, and they compose.

| Method | True when | Blocks |
|---|---|---|
| `Form#locked?` | `submissions.exists?` | Adding, removing, or retyping fields |
| `Form#editable?` | `active?` | Every edit, including name and description |

`validate :structure_unchanged, if: :locked?` adds an error when any field is new, changed,
or marked for destruction on a locked form. `validate :editable, on: :update` refuses any
change at all to a deleted form. Both live in the model rather than in parameter filtering,
so the console and any future API get the same protection, and the edit view can ask the
form directly which parts to render read-only and why.

## Soft delete

`active` starts true. "Delete" sets it to false; nothing is ever destroyed.

```ruby
def soft_delete
  update(active: false)
end
```

Non-bang `update` returning a boolean, and no bang in the method name — the caller decides
how to handle failure. This is the exact case the standards use as their example of a
mutation that belongs on the model rather than in a service class.

**No `default_scope`.** It is the obvious way to hide inactive rows, and it is the wrong
one here: the admin index has to see deleted forms, and the only escape from a
`default_scope` is `unscoped`, which the standards ban outright. Instead there is an
explicit `scope :active` that the member-facing queries opt into. Admin queries stay
unscoped by simply not calling it.

What changes where a form is deleted:

| Surface | Behavior |
|---|---|
| Admin form index | Still listed, marked with a "Deleted" badge and de-emphasized |
| Admin form show | Viewable in full |
| Admin form edit/update | Refused — the action redirects with an explanation |
| Admin submissions index | Unchanged, still viewable |
| CSV export | Unchanged, still downloadable |
| Member form index | Gone — scoped through `Form.active` |
| Member fill-out | Refused, even by direct URL |
| Member's own submission | Still viewable |

## Routes

```ruby
devise_for :users

resources :forms, only: %i[index show] do
  resource :submission, only: %i[new create show]
end

namespace :admin do
  resources :forms do
    resources :submissions, only: :index
  end
end

authenticated :user, ->(user) { user.admin? } do
  root "admin/forms#index", as: :admin_root
end

root "forms#index"
```

The two `root` declarations are what give admins and members different home pages without
a role conditional inside a controller action. CSV export is `format.csv` on
`admin/forms/:form_id/submissions`, not a custom action.

## Controllers

| Controller | Responsibility |
|---|---|
| `ApplicationController` | `before_action :authenticate_user!` |
| `Admin::BaseController` | `before_action :require_admin`; every admin controller inherits it |
| `Admin::FormsController` | Full CRUD over `current_user.forms`, including deleted ones; `destroy` soft-deletes; `edit`/`update` refuse a deleted form |
| `Admin::SubmissionsController` | `index` for one owned form, HTML and CSV, deleted or not |
| `FormsController` | `index` over `current_user`-visible `Form.active`, `show` |
| `SubmissionsController` | `new`, `create` (active forms only), `show` (own submission, read-only) |

Admin scoping goes through the association — `current_user.forms.find(params[:id])` — so an
admin reaching for another admin's form gets a 404 from the query itself rather than from a
permission check that could be forgotten.

## Views

Tailwind utility classes in the markup; any extracted component classes go in
`app/assets/tailwind/application.css`. No inline styles.

**Field editor (admin).** `accepts_nested_attributes_for :fields, allow_destroy: true`
plus `form.fields_for`, with a Stimulus `nested_fields_controller` that clones a
`<template>` to add rows and a `field_type_controller` that shows the choices textarea only
for choice-based input types. Adding a row is instant client-side state, which is exactly
where the Turbo → Stimulus hierarchy puts Stimulus.

**Fill-out form.** `form.fields :values` scopes inputs to `submission[values][<field_id>]`.
A `_field_input` partial dispatches: choice-based fields render through `select`,
`collection_radio_buttons`, or `collection_check_boxes`; everything else renders through
`form.public_send(field.input_type, field.id)`.

**Required fields.** Each required input is marked three ways, because one is never enough:
a red asterisk after the label with an `aria-hidden` on the glyph and a visually-hidden
"required" for screen readers, `required: true` on the input so the browser catches it
before the round trip, and `aria-required="true"` on choice groups where the HTML attribute
alone doesn't work across a radio or check-box set. A legend above the form names the
convention once. The server-side validator remains the source of truth — the HTML attribute
is a convenience, not the check.

**Deleted forms.** The admin index renders a deleted row de-emphasized with a "Deleted"
badge and no edit link. The show page carries a banner explaining that the form is deleted,
that its submissions are still exportable, and that it can no longer be edited.

**Destructive actions.** `button_to` with `data: { turbo_confirm: ... }`. No UJS. The
confirm text for deleting a form says it will be hidden from members and that submissions
are kept.

## CSV export

`Form#submissions_csv` builds the file with `CSV.generate`: a header row of
`Submitted by, Submitted at, *field labels`, then one row per submission with
`Submission#display_value_for(field)` rendering arrays as comma-joined text.

This is data serialization rather than view presentation, and the call site reads
`@form.submissions_csv`, which the standards say should be a model method rather than a
service class. If it grows — multiple formats, column configuration — it becomes a
`SubmissionsCsv` PORO at that point, not before.

## Tests

Minitest with fixtures for `users`, `forms`, `fields`, and `submissions`.

**Models.** Admin defaults to false. Form requires an owner; `active` defaults to true;
`locked?` flips after the first submission; a locked form rejects field changes;
`soft_delete` flips `active` and returns true; a deleted form rejects every update;
`Form.active` excludes deleted forms. Field enum prefixes, choice rules, type
compatibility, and `required` defaulting to false. Submission uniqueness at both the
validation and the database level, value casting per type, choice membership, unknown keys
rejected, and a blank answer to a required field rejected — including an empty array for a
required check-box field.

**Controllers and integration.** Everything requires authentication. A member hitting an
admin route is refused. An admin sees only their own forms and cannot load another admin's.
Creating a form with nested fields. A locked form rejecting a structural update. Submitting
stores typed values; a second submission is refused; a submission missing a required answer
is refused. Strong parameters drop unknown keys. Deleting a form leaves it in the admin
index and out of the member index; its edit page redirects; its fill-out page refuses even
by direct URL; its CSV still downloads. CSV export returns the right content type, header
row, and values, and only to the owner.
Signing up with `admin=true` in the payload does not produce an admin.

**System tests** (headless Chrome, two only — they are slow): building a form by adding
three fields of different types, and filling one out end to end.

Every phase ends with `bin/rails test`, `bin/rails test:system` where relevant, and
`bin/rubocop` at zero offenses.

## Phases

### Phase 1 — Foundation (sequential, no agents)

Schema and models are a single dependency root; parallelizing here only produces migration
races and merge conflicts.

1. Add `devise`, `tailwindcss-rails`, `csv` to the Gemfile and `bundle install`.
2. Confirm PostgreSQL is running; `bin/rails db:create`.
3. `rails g devise:install`, `rails g devise User`, `rails g tailwindcss:install`.
4. Migrations: `admin` on users; `forms` (with `active`); `fields` (with `required`);
   `submissions` — with every index and foreign key listed above.
5. Models, enums, associations, `Form.active`, `Field#cast`, `Form#locked?`,
   `Form#editable?`, `Form#soft_delete`, `Form#submissions_csv`,
   `Submission#display_value_for`.
6. The three validators in `app/validators`.
7. `ApplicationController` authentication and `Admin::BaseController`.
8. Routes.
9. Fixtures and the full model test suite.
10. Boot the app and confirm no `DangerousAttributeError` on `values`, `required`, or
    `active`.

### Phase 2a — Shared shell (sequential, no agents)

Every agent's views depend on these, so they land before any agent starts: the application
layout with nav and sign-out, the flash partial, and the shared page-header and
empty-state partials with their Tailwind treatment.

### Phase 2b — Parallel agents

Three agents, disjoint file ownership, same working tree. **Model files are frozen** after
Phase 1 — an agent that believes it needs a model change stops and reports rather than
editing.

| Agent | Owns | Builds |
|---|---|---|
| **A — Form authoring** | `app/controllers/admin/forms_controller.rb`, `app/views/admin/forms/**`, `app/javascript/controllers/nested_fields_controller.js`, `app/javascript/controllers/field_type_controller.js`, `test/controllers/admin/forms_controller_test.rb` | Admin CRUD, the dynamic field editor with its required checkbox, soft delete, and the locked and deleted read-only states |
| **B — Fill out** | `app/controllers/forms_controller.rb`, `app/views/forms/**`, `app/controllers/submissions_controller.rb`, `app/views/submissions/**`, `test/controllers/forms_controller_test.rb`, `test/controllers/submissions_controller_test.rb` | Member form list, form detail, the dynamic fill-out form with required-field marking and error display, one-submission-per-user handling |
| **C — Review and export** | `app/controllers/admin/submissions_controller.rb`, `app/views/admin/submissions/**`, `test/controllers/admin/submissions_controller_test.rb` | Submissions table for an owned form and the CSV download |

Nobody but the main session touches `config/routes.rb`, `app/models/**`,
`app/views/layouts/**`, or `Gemfile`. Agent A and Agent B both render field inputs but for
different purposes — A renders the *editor* for a field, B renders the *input* for
answering — so there is no shared partial between them to fight over.

### Phase 3 — Integration (sequential)

Full suite and RuboCop across everything, cross-cutting fixes, `db/seeds.rb` with an admin,
a member, and a sample form covering every input type, and a README section on promoting an
admin from the console. System tests get written here, once the UI has stopped moving.

### Phase 4 — Polish

A design pass across all pages, empty states, mobile layout, and an accessibility check:
every input tied to its label, visible focus states, and choice groups marked up as
fieldsets.

## Risks

- **Field-editor complexity.** Nested attributes plus conditional choices is the fiddliest
  part of the build. If the Stimulus approach fights us, the fallback is a Turbo Frame that
  appends a row from the server — slower, but far less client state.
- **Value casting at the boundary.** JSONB will happily store whatever it is handed. The
  validator is what keeps `values` trustworthy, so its tests matter more than most.
- **Structure lock discoverability.** An admin who cannot edit fields needs to understand
  why. The edit view says so explicitly rather than just disabling inputs.
