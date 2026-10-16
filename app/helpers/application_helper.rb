module ApplicationHelper
  def yes_icon
    content_tag(:i, "", class: "bi bi-check-circle-fill text-success")
  end

  def no_icon
    content_tag(:i, "", class: "bi bi-x-circle text-muted")
  end

  def role_badge_class(role)
    case role.to_s
    when "admin" then "bg-danger"
    when "editor" then "bg-warning text-dark"
    else "bg-secondary"
    end
  end

  def page_title_text
    content_for(:page_title) || "WebAnsible"
  end

  # Актуальная тема (light/dark) из глобальных настроек (БД).
  # Используется layout, чтобы применять сохранённую тему без JS.
  def settings_theme
    Settings::AppConfig.new["theme"] || "light"
  end

  # Варианты для select в форме хоста: текст опции = отображаемое имя,
  # значение = группа Zabbix (для ролей — перечень имён хостов Zabbix).
  # Список подтягивается из настроек (здесь и там же).
  def host_option_select_options(category)
    ZabbixOption.options_for(category)
  end
end
