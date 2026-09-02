class CreateForms < ActiveRecord::Migration[8.1]
  def change
    create_table :forms do |t|
      t.references :owner, null: false,
                   foreign_key: { to_table: :users, name: "fk_forms_owner_id" }
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :forms, [ :owner_id, :created_at ]
  end
end
