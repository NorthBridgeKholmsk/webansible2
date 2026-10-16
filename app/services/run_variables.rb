# Эффективные переменные хоста на момент запуска.
#
# Цепочка приоритетов на каждый хост (нижний уровень переопределяется верхним):
#   общие переменные -> организация -> хост,
# а поверх идут переменные формы запуска через -e (extra-vars) — см. RunLauncher.
#
# Правило: пустое значение НИКОГДА не переопределяет непустое нижнего уровня
# («пусто = не задано»). Ключевой кейс: у хоста нет login/password, а в
# организации есть ansible_user/ansible_password — значения организации
# сохраняются; непустые креды хоста организацию переопределяют.
class RunVariables
  # Эффективные переменные одного хоста (без переменных формы запуска).
  def self.for_host(host)
    result = {}
    merge_non_blank!(result, pairs_of(CommonVariable.all))
    if host.organization
      merge_non_blank!(result, pairs_of(host.organization.variables))
    end
    merge_non_blank!(result, pairs_of(host.variables))
    # Адрес и SSH-креды из колонок хоста — последними на уровне «хост»:
    # ansible_host всегда берётся из IP хоста, непустые login/password
    # переопределяют переменные с теми же именами.
    merge_non_blank!(result, {
      "ansible_host" => host.ip,
      "ansible_user" => host.login,
      "ansible_password" => host.password
    })
    result
  end

  # Переменные формы запуска (variables[i][name/value]). Пустые имена и
  # значения пропускаются («пусто = не задано»).
  def self.from_form(params)
    raw = params.respond_to?(:permit!) ? params.permit!.to_h : (params || {})
    rows = raw[:variables] || raw["variables"] || {}
    return {} unless rows.respond_to?(:each_pair)

    result = {}
    rows.each do |_index, pair|
      next unless pair.respond_to?(:to_h)

      attrs = pair.to_h
      name = (attrs[:name] || attrs["name"]).to_s.strip
      value = (attrs[:value] || attrs["value"]).to_s
      next if name.empty? || value.strip.empty?

      result[name] = value
    end
    result
  end

  class << self
    private

    # Записи переменных -> {имя => значение}. Значения читаются через .value,
    # поэтому зашифрованные прозрачно расшифровываются.
    def pairs_of(records)
      records.each_with_object({}) do |v, h|
        h[v.name.to_s] = v.value
      end
    end

    # Слияние source в target: пустые значения не затирают непустые.
    def merge_non_blank!(target, source)
      source.each do |name, value|
        next if value.nil? || value.to_s.strip.empty?

        target[name.to_s] = value.to_s
      end
      target
    end
  end
end
