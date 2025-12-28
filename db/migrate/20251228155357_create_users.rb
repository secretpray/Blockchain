class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :eth_address, null: false

      t.timestamps
    end

    add_index :users, :eth_address, unique: true
  end
end
