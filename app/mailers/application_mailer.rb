# Базовый класс писем приложения (отправка почты в UI не используется).
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end
