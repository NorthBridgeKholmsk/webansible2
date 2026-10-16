# Базовый класс фоновых задач приложения.
class ApplicationJob < ActiveJob::Base
  # Автоматический повтор при дедлоке (выключено):
  # retry_on ActiveRecord::Deadlocked

  # Игнорировать задачу, если запись уже удалена (выключено):
  # discard_on ActiveJob::DeserializationError
end
