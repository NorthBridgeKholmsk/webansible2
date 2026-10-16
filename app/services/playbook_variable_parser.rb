# Извлечение play-уровневых переменных из YAML-содержимого плейбука.
#
# Берётся ТОЛЬКО блок «vars:» в начале каждого плейа (верх плейбука).
# Переменные, определённые для конкретных задач (tasks, pre_tasks, post_tasks,
# handlers, task-уровневые vars:, параметры модулей), не рассматриваются —
# парсер вообще не заглядывает внутрь tasks.
#
# Правила:
# - несколько плейа в файле — vars: каждого объединяются по порядку сверху вниз;
#   при дубликате имени побеждает первое вхождение (верх файла);
# - значения приводятся к строке как есть, включая шаблоны «{{ ... }}»;
#   nil -> "", число/булево -> to_s;
# - битый YAML или отсутствие плейов — результат с ошибкой (ok? == false),
#   исключений наружу не бросаем.
class PlaybookVariableParser
  class ParseResult
    attr_reader :variables, :error

    def initialize(variables, error = nil)
      @variables = variables
      @error = error
    end

    def ok?
      @error.nil?
    end
  end

  # content — YAML-текст плейбука (Playbook#content).
  # Возвращает ParseResult: variables — массив пар [имя, значение] в порядке
  # появления, либо error — человекочитаемое сообщение об ошибке.
  def self.parse(content)
    text = content.to_s.strip
    return ParseResult.new([], "У плейбука нет содержимого") if text.empty?

    documents =
      begin
        # Psych 3.x не имеет safe_load_all: разбиваем поток на документы по
        # маркерам «---» в начале строки и безопасно загружаем каждый.
        split_documents(text).map do |chunk|
          next if chunk.nil? || chunk.strip.empty?
          Psych.safe_load(chunk, permitted_classes: [Date, Time])
        end.compact
      rescue Psych::Exception => e
        return ParseResult.new([], "Ошибка разбора YAML: #{e.message.lines.first.to_s.strip}")
      end

    plays = []
    documents.each do |doc|
      case doc
      when Array then plays.concat(doc)
      when Hash  then plays << doc # одиночный плей без обёртки-списка
      end
    end
    return ParseResult.new([], "В плейбуке не найдено ни одного плейа") if plays.empty?

    variables = []
    seen = {}
    plays.each do |play|
      next unless play.is_a?(Hash)
      vars = play["vars"] # ключи из safe_load — строки
      next unless vars.is_a?(Hash)

      vars.each do |name, value|
        name_s = name.to_s.strip
        next if name_s.empty? || seen[name_s]
        seen[name_s] = true
        variables << [name_s, value.nil? ? "" : value.to_s]
      end
    end
    ParseResult.new(variables)
  end

  # Разбивает YAML-поток на тексты отдельных документов по маркерам «---»
  # в начале строки (стандартный формат ansible-плейбуков). Возвращает массив
  # строк; пустые куски (например, до первого маркера) остаются — их пропускает
  # вызывающий код.
  def self.split_documents(text)
    chunks = []
    current = []
    text.each_line do |line|
      if line.match?(/\A---\s*(#.*)?\z/)
        chunks << current.join
        current = []
      else
        current << line
      end
    end
    chunks << current.join
    chunks
  end
end
