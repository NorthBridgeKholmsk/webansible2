# Данные для первичного наполнения базы.
# Загружаются командой bin/rails db:seed (или вместе с созданием БД через db:setup).

unless User.exists?(login: "admin")
  User.create!(login: "admin", password: "admin", password_confirmation: "admin", role: "admin", active: true)
  puts "Created default admin user (admin / admin)"
else
  puts "Admin user already exists"
end
