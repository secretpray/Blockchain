# Used to create the users table with necessary fields and indexes
class CreateUsers < ActiveRecord::Migration[8.1]
   def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :eth_address, null: false
      t.string :eth_nonce, null: false

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :eth_address, unique: true
    add_index :users, :eth_nonce, unique: true
  end
end
