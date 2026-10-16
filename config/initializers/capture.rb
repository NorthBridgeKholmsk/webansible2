# frozen_string_literal: true
#
# Возвращаем модуль AbstractController::Capture контроллерам.
#
# Обычно Rails сам предоставляет модуль AbstractController::Capture (content_for /
# provide / capture / content_for?) и включает его в AbstractController::Base.
# В actionpack этого окружения модуля нет, поэтому вызов content_for(...) внутри
# действия контроллера падает с NoMethodError (например, DashboardController#index).
#
# Здесь мы объявляем модуль заново и включаем его в AbstractController::Base,
# восстанавливая штатное поведение. content_for делегирует view_context, где уже
# есть ActionView::Helpers::CaptureHelper#content_for.
module AbstractController
  module Capture
    def capture(*args)
      view_context.capture(*args)
    end

    def content_for(name, content = nil, options = {}, &block)
      name = name.to_sym
      if block_given?
        options = block
        content = nil
      end

      # `options` может быть блоком (Proc) или Hash — приводим к Hash, чтобы на
      # слой представления уходил чистый хеш опций.
      if options.respond_to?(:to_options)
        options = options.to_options
      end
      options = {} unless options.respond_to?(:key?)

      # Флаг :replace уровня контроллера мапим на флаг :flush представления.
      if options.key?(:replace)
        options = { flush: options[:replace] }
      end

      content = block.call if block

      view_context.content_for(name, content, options)
    end

    def provide(name, content = nil, &block)
      content_for(name, content, {}, &block)
    end

    def content_for?(name)
      view_context.content_for?(name)
    end
  end
end

AbstractController::Base.include(AbstractController::Capture)
