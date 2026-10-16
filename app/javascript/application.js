// Точка входа пайплайна ассетов. Подключаем Turbo, чтобы TurboDrive работал
// при полных переходах (обычные формы/ссылки).
import "@hotwired/turbo-rails"
// Подключаем app.js — его IIFE (initTheme/initSidebar/initSubmenu/...) должна
// выполняться на каждой странице. Раньше пин "app" в importmap был определён,
// но нигде не импортирован, поэтому сворачивание групп меню и кнопка
// сворачивания сайдбара не работали.
import "app"

console.log("WebAnsible asset pipeline loaded.")
