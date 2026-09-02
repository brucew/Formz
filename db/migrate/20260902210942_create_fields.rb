class CreateFields < ActiveRecord::Migration[8.1]
  def change
    create_table :fields do |t|
      t.references :form, null: false,
                   foreign_key: { name: "fk_fields_form_id" }
      t.string :label, null: false
      t.text :description
      t.integer :input_type, null: false
      t.integer :value_type, null: false
      t.string :choices, array: true, null: false, default: []
      t.boolean :required, null: false, default: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :fields, [ :form_id, :position ], unique: true
  end
end
