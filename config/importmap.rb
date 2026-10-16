# Пины зависимостей importmap: какие модули доступны скриптам приложения.
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "app", to: "app.js"

# Все модули из app/javascript доступны в неймспейсе "app"
# (например, import { something } from "app/something").
pin_all_from "app/javascript", under: "app"
