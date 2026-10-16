module Settings
  class ApplicationController < ApplicationController
    CATEGORY_TITLES = {
      "type"    => "Типы хостов",
      "role"    => "Роли хостов",
      "os_type" => "Типы ОС"
    }.freeze

    def show
      @settings = Settings::AppConfig.new
      @zabbix_masked = Zabbix::Settings.api_key.present? ? "****" : ""
      @zabbix_insecure = Zabbix::Settings.insecure_ssl?
      content_for(:page_title) { "Настройки" }
    end

    def update
      Settings::AppConfig.new.apply(params.fetch(:settings, {}).permit!) if params[:settings]
      Zabbix::Settings.apply(
        url: params[:settings]["zabbix_url"],
        api_key: params[:settings]["zabbix_api_key"],
        insecure_ssl: params.dig(:settings, "zabbix_insecure_ssl").present?
      ) if params[:settings]
      redirect_to settings_path, notice: "Настройки сохранены"
    end

    # Форма редактирования списка (тип/роль/тип ОС): таблица
    # чекбокс «отображать» | отображаемое имя | название группы в Zabbix.
    def edit_option
      @category = params[:category].to_s
      @options = ZabbixOption.by_category(@category).order(:label)
      content_for(:page_title) { CATEGORY_TITLES[@category] || "Список" }
    end

    # Сохранение списка. Входящие params[:items] — массив строк:
    # { id:, label:, value:, enabled: }.
    # Строки с пустым id → создание записи; со id → обновление;
    # строки, удалённые из формы (id не передан) → удаление из БД.
    def update_option
      @category = params[:category].to_s
      items = Array(params.fetch(:items, [])).map { |it| it.to_unsafe_h }

      kept_ids = []
      items.each do |it|
        id = it["id"].presence
        if (option = ZabbixOption.find_by(id: id))
          option.update(label: it["label"], value: it["value"], enabled: it["enabled"].present?)
          kept_ids << option.id
        elsif it["label"].present? && it["value"].present?
          new_opt = ZabbixOption.create(category: @category, label: it["label"], value: it["value"], enabled: it["enabled"].present?)
          kept_ids << new_opt.id if new_opt
        end
      end

      # Удалить из категории всё, что осталось за рамками формы.
      if kept_ids.any?
        ZabbixOption.by_category(@category).where.not(id: kept_ids).delete_all
      else
        ZabbixOption.by_category(@category).delete_all
      end

      redirect_to edit_option_path(category: @category), notice: "Список сохранён"
    end
  end
end