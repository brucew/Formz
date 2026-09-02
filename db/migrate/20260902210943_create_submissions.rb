class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.references :form, null: false,
                   foreign_key: { name: "fk_submissions_form_id" }
      t.references :user, null: false,
                   foreign_key: { name: "fk_submissions_user_id" }
      t.jsonb :values, null: false, default: {}

      t.timestamps
    end

    add_index :submissions, [ :form_id, :user_id ], unique: true
  end
end
