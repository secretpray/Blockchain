class AddSecurityFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Флаг верификации (создан vs доказал владение адресом)
    add_column :users, :verified, :boolean, default: false, null: false
    add_index :users, :verified

    # Поля для многоуровневой защиты
    add_column :users, :nonce_issued_at, :datetime
    add_column :users, :last_auth_attempt_at, :datetime
    add_column :users, :auth_attempts_count, :integer, default: 0, null: false

    # Индексы для производительности
    add_index :users, :nonce_issued_at
    add_index :users, :last_auth_attempt_at

    # Все существующие пользователи считаются верифицированными
    reversible do |dir|
      dir.up do
        User.update_all(
          verified: true,
          nonce_issued_at: Time.current,
          auth_attempts_count: 0
        )
      end
    end
  end
end
