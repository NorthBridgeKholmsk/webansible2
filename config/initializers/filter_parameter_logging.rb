# После изменения этого файла сервер нужно перезапустить.

# Параметры, которые маскируются в логах (защита от утечки секретов).
# Поддерживаемые нотации — см. документацию ActiveSupport::ParameterFilter.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
]
