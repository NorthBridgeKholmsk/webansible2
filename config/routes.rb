Rails.application.routes.draw do
  root "dashboard#index"

  # Синхронизация с Zabbix (стриминг прогресса в JSON-lines) — только админы.
  post "dashboard/zabbix_sync", to: "dashboard#zabbix_sync", as: :zabbix_sync

  # Отмена идущей синхронизации (кнопка «Отменить» в модалке) — только админы.
  post "dashboard/zabbix_sync/cancel", to: "dashboard#zabbix_sync_cancel", as: :zabbix_sync_cancel

  resources :sessions, only: [:new, :create, :destroy]
  delete "logout", to: "sessions#destroy"

  resources :organizations, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  resources :hosts, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  # Запасной маршрут: если _method=patch не дошёл (Turbo/браузер) — POST /hosts/:id
  # тоже должен попадать в update, иначе Rails отдаёт 404 (для POST у hosts/:id маршрута нет).
  post "hosts/:id", to: "hosts#update"

  # Общие переменные — плоский список для всех хостов (пакетное сохранение).
  get "common-variables", to: "common_variables#index", as: :common_variables
  patch "common-variables", to: "common_variables#update"

  resources :plays, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  # Плейбуки — конструктор из плеев с ветвлением по ОС (см. PlaybooksController).
  resources :playbooks, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  resources :files, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  resources :users, only: [:index, :new, :create, :edit, :update, :destroy]

  get "run", to: "runs#new", as: :new_run
   post "run", to: "runs#create", as: :run
  # JSON-список переменных плея (fetch при выборе на странице запуска).
  get "run/variables", to: "runs#variables", as: :run_variables

  # Результаты запусков: страница с live-выводом + endpoint опроса новых кусков лога.
  get "runs/:id/output", to: "runs#output", as: :run_output
  get "runs/:id", to: "runs#show", as: :run_show

  get "settings", to: "settings/application#show"
  patch "settings", to: "settings/application#update"

  get "settings/options/new/:category", to: "settings/application#edit_option", as: :edit_option, constraints: { category: %r{type|role|os_type} }
  patch "settings/options/:category", to: "settings/application#update_option", as: :update_option, constraints: { category: %r{type|role|os_type} }
end
