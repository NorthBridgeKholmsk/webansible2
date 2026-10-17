// Поведение фронтенда WebAnsible: тема, сайдбар, формы, запуск плея.
(function () {
  "use strict";
  var THEME_KEY = "webansible-theme";
  var SIDEBAR_KEY = "webansible-sidebar";
  function ready(fn) {
    if (document.readyState !== "loading") { fn(); }
    else { document.addEventListener("DOMContentLoaded", fn); }
  }
  function onTurboLoad(fn) {
    ready(fn);
    document.addEventListener("turbo:load", fn);
    document.addEventListener("turbo:render", fn);
  }
  function setTheme(theme) {
    var html = document.documentElement;
    html.setAttribute("data-theme", theme);
    html.setAttribute("data-bs-theme", theme);
    var body = document.body;
    if (body) {
      body.setAttribute("data-theme", theme);
      body.setAttribute("data-bs-theme", theme);
    }
    var btn = document.getElementById("theme-toggle");
    if (btn) {
      var icon = btn.querySelector("i");
      if (icon) {
        icon.className = theme === "dark" ? "bi bi-sun-fill" : "bi bi-moon-stars-fill";
      } else {
        btn.textContent = theme === "dark" ? "\u2600" : "\uD83C\uDF19";
      }
      btn.setAttribute("aria-label", "Switch theme");
    }
  }
  function setServerTheme(theme) {
    // Сохранить выбранную тему в глобальные настройки (БД),
    // чтобы layout применил её при следующей загрузке страницы.
    var token = document.querySelector('meta[name="csrf-token"]');
    var fd = new FormData();
    fd.append("_method", "patch");
    fd.append("authenticity_token", token ? token.getAttribute("content") : "");
    fd.append("settings[theme]", theme);
    fetch("/settings", {
      method: "POST",
      headers: { "X-Requested-With": "XMLHttpRequest" },
      body: fd,
      redirect: "follow"
    }).then(function() {}).catch(function() {});
  }
  function initTheme() {
    // Источник — сервер: layout уже применил сохранённую в БД тему.
    // Затем локальное сохранённое предпочтение, затем автоопределение.
    var fromServer = document.documentElement.getAttribute("data-theme");
    var initial = fromServer || localStorage.getItem(THEME_KEY) ||
      (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    setTheme(initial);
    var btn = document.getElementById("theme-toggle");
    if (btn) {
      function onToggleTheme() {
        var next = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark";
        setTheme(next);
        localStorage.setItem(THEME_KEY, next);
        setServerTheme(next);
      }
      if (btn.__baThemeToggle) { btn.removeEventListener("click", btn.__baThemeToggle); }
      btn.__baThemeToggle = onToggleTheme;
      btn.addEventListener("click", onToggleTheme);
    }
  }
  function initSidebar() {
    var sidebar = document.getElementById("sidebar");
    var toggle = document.getElementById("sidebar-toggle");
    if (!sidebar || !toggle) return;
    if (localStorage.getItem(SIDEBAR_KEY) === "collapsed") {
      sidebar.classList.add("collapsed");
      document.body.classList.add("sidebar-collapsed");
    }
    function onToggle() {
      var collapsed = sidebar.classList.contains("collapsed");
      sidebar.classList.toggle("collapsed", !collapsed);
      document.body.classList.toggle("sidebar-collapsed", !collapsed);
      localStorage.setItem(SIDEBAR_KEY, collapsed ? "expanded" : "collapsed");
    }
    if (toggle.__baToggle) { toggle.removeEventListener("click", toggle.__baToggle); }
    toggle.__baToggle = onToggle;
    toggle.addEventListener("click", onToggle);
  }
  function initSubmenu() {
    document.querySelectorAll(".nav-group").forEach(function (group) {
      var title = group.querySelector(".nav-group-title");
      var key = "webansible-group-" + (group.getAttribute("data-group") || "x");
      if (localStorage.getItem(key) === "open") { group.classList.add("open"); }
      if (group.querySelector(".nav-link.active")) { group.classList.add("open"); }
      if (title) {
        function open(e) {
          e.preventDefault();
          var willOpen = !group.classList.contains("open");
          group.classList.toggle("open", willOpen);
          localStorage.setItem(key, willOpen ? "open" : "closed");
        }
        function onKey(e) {
          if (e.key === "Enter" || e.key === " ") { open(e); }
        }
        if (group.__baOpen) { title.removeEventListener("click", group.__baOpen); }
        if (group.__baKey) { title.removeEventListener("keydown", group.__baKey); }
        group.__baOpen = open;
        group.__baKey = onKey;
        title.addEventListener("click", open);
        title.addEventListener("keydown", onKey);
      }
    });
  }
  function updateSelection(table) {
    if (!table) return;
    var rows = table.querySelectorAll("tbody .row-select");
    var checked = table.querySelectorAll("tbody .row-select:checked");
    var badge = table.querySelector(".selected-count");
    var delBtn = table.querySelector(".delete-selected");
    if (badge) badge.textContent = String(checked.length);
    if (delBtn) delBtn.disabled = checked.length === 0;
    var header = table.querySelector("thead .select-all");
    if (header) { header.checked = rows.length > 0 && rows.length === checked.length; }
  }
  function initSelectAll() {
    document.querySelectorAll("thead .select-all").forEach(function (header) {
      header.addEventListener("change", function () {
        var table = header.closest("table");
        table.querySelectorAll("tbody .row-select").forEach(function (c) {
          c.checked = header.checked;
        });
        updateSelection(table);
      });
    });
    document.querySelectorAll("tbody .row-select").forEach(function (cell) {
      cell.addEventListener("change", function () {
        updateSelection(cell.closest("table"));
      });
    });
  }
  var currentAction = null;
  var currentParam = "record";
  function openForm(action, param, record) {
    currentAction = action;
    currentParam = param || "record";
    var form = document.getElementById("record-form");
    if (!form) return;
    form.dataset.edit = record ? "true" : "false";
    form.action = action;
    form.reset();
    if (record) {
      var ids = form.querySelectorAll("[data-field]");
      ids.forEach(function (el) {
        var key = el.getAttribute("data-field");
        if (record[key] !== undefined) el.value = record[key] || "";
      });
      populateVariables(record.variables || []);
    }
    showModal();
  }
  function populateVariables(variables) {
    var container = document.getElementById("variables-container");
    if (!container) return;
    container.innerHTML = "";
    variables.forEach(function (v) {
      addVariableRow(v.name || "", v.value || "");
    });
    if (variables.length === 0) { addVariableRow("", ""); }
  }
  function addVariableRow(name, value) {
    var container = document.getElementById("variables-container");
    if (!container) return;
    var row = document.createElement("div");
    row.className = "variable-row mb-2 row g-2";
    var nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.className = "form-control";
    nameInput.placeholder = "Variable name";
    nameInput.name = currentParam + "[variables_attributes][][name]";
    nameInput.value = name;
    var valueInput = document.createElement("input");
    valueInput.type = "text";
    valueInput.className = "form-control";
    valueInput.placeholder = "Value";
    valueInput.name = currentParam + "[variables_attributes][][value]";
    valueInput.value = value;
    var removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "btn btn-outline-danger";
    removeBtn.textContent = "\u2715";
    removeBtn.addEventListener("click", function () { row.remove(); });
    row.appendChild(nameInput);
    row.appendChild(valueInput);
    row.appendChild(removeBtn);
    container.appendChild(row);
  }
  function showModal() {
    var el = document.getElementById("record-modal");
    if (!el || typeof bootstrap === "undefined") return;
    var modal = new bootstrap.Modal(el);
    modal.show();
  }
  function submitForm() {
    if (!currentAction) return;
    var form = document.getElementById("record-form");
    var methodField = form.querySelector("input[name=\"_method\"]");
    if (!methodField) {
      methodField = document.createElement("input");
      methodField.type = "hidden";
      methodField.name = "_method";
      form.appendChild(methodField);
    }
    methodField.value = form.dataset.edit === "true" ? "patch" : "";
    form.action = currentAction;
    form.method = "post";
    form.submit();
  }
  function bindModalButtons() {
    document.querySelectorAll("[data-modal-new]").forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.preventDefault();
        var record = btn.getAttribute("data-modal-record");
        openForm(btn.getAttribute("data-modal-new"), btn.getAttribute("data-modal-param") || "record", record && JSON.parse(record));
      });
    });
    document.querySelectorAll("[data-modal-edit]").forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.preventDefault();
        var record = btn.getAttribute("data-modal-record");
        openForm(btn.getAttribute("data-modal-edit"), btn.getAttribute("data-modal-param") || "record", record && JSON.parse(record));
      });
    });
    var saveBtn = document.getElementById("modal-save");
    if (saveBtn) saveBtn.addEventListener("click", function (e) {
      e.preventDefault();
      submitForm();
    });
  }
  function initDeleteSelected() {
    document.querySelectorAll(".delete-selected").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var table = btn.closest("table");
        if (!table) return;
        var ids = [];
        table.querySelectorAll("tbody .row-select:checked").forEach(function (c) {
          ids.push(c.getAttribute("data-id"));
        });
        if (ids.length === 0) return;
        if (!confirm("Delete selected records?")) return;
        var form = document.createElement("form");
        form.method = "post";
        form.action = table.getAttribute("data-destroy-url");
        var token = document.querySelector("meta[name=\"csrf-token\"]");
        if (token) {
          var h = document.createElement("input");
          h.type = "hidden";
          h.name = "authenticity_token";
          h.value = token.getAttribute("content");
          form.appendChild(h);
        }
        ids.forEach(function (id) {
          var inp = document.createElement("input");
          inp.type = "hidden";
          inp.name = "ids[]";
          inp.value = id;
          form.appendChild(inp);
        });
        var m = document.createElement("input");
        m.type = "hidden";
        m.name = "_method";
        m.value = "delete";
        form.appendChild(m);
        document.body.appendChild(form);
        form.submit();
      });
    });
  }
  // Обработчик вложенных переменных на формах редактирования хоста и организации.
  // Кнопка «Добавить переменную» добавляет поле <prefix>[variables_attributes][N][...],
  // где prefix берётся из data-variable-prefix контейнера (host/organization).
  // Кнопка «Удалить» ставит _destroy=1 (Rails помечает запись к удалению).
  function bindEditVariables() {
    var container = document.getElementById("variables-container");
    if (!container) return;

    var prefix = container.getAttribute("data-variable-prefix") || "host";

    function nextIndex() {
      var max = -1;
      container.querySelectorAll('input[name*="variables_attributes"]').forEach(function (el) {
        var m = el.getAttribute("name").match(/variables_attributes\]\[(\d+)\]\[/);
        if (m && isFinite(parseInt(m[1], 10)) && parseInt(m[1], 10) > max) { max = parseInt(m[1], 10); }
      });
      return max + 1;
    }

    function buildRow(idx, destroyValue) {
      var row = document.createElement("div");
      // Та же структура, что у серверных строк (variables/_form_field.html.erb) — input-group.
      row.className = "variable-row input-group mb-2";
      var nameInput = document.createElement("input");
      nameInput.type = "text";
      nameInput.className = "form-control mb-2 me-1";
      nameInput.placeholder = "Имя переменной";
      nameInput.required = true;
      nameInput.name = prefix + "[variables_attributes][" + idx + "][name]";

      var valueInput = document.createElement("input");
      valueInput.type = "text";
      valueInput.className = "form-control mb-2 me-1";
      valueInput.placeholder = "Значение";
      valueInput.name = prefix + "[variables_attributes][" + idx + "][value]";

      // Чекбокс «зашифровать»: включён -> значение хранится в зашифрованном виде,
      // input становится password и очищается (plaintext не держим).
      var encryptedCheck = document.createElement("input");
      encryptedCheck.type = "checkbox";
      encryptedCheck.className = "variable-encrypted-check";
      encryptedCheck.title = "Хранить значение в зашифрованном виде (пароли, ключи)";
      encryptedCheck.name = prefix + "[variables_attributes][" + idx + "][encrypted]";
      var checkWrap = document.createElement("span");
      checkWrap.className = "input-group-text mb-2";
      checkWrap.appendChild(encryptedCheck);
      // Скрытое "0" перед чекбоксом: снятая галочка отправляет false.
      var encryptedHidden = document.createElement("input");
      encryptedHidden.type = "hidden";
      encryptedHidden.name = prefix + "[variables_attributes][" + idx + "][encrypted]";
      encryptedHidden.value = "0";

      var destroyInput = document.createElement("input");
      destroyInput.type = "hidden";
      destroyInput.name = prefix + "[variables_attributes][" + idx + "][_destroy]";
      destroyInput.value = destroyValue || "0";

      var removeBtn = document.createElement("button");
      removeBtn.type = "button";
      removeBtn.className = "btn btn-outline-danger mb-2 remove-variable";
      removeBtn.innerHTML = "<i class=\"bi bi-trash\"></i>";
      // Удаление обрабатывает делегированный onRemoveVariable на контейнере — один путь кода.

      row.appendChild(nameInput);
      row.appendChild(valueInput);
      row.appendChild(encryptedHidden);
      row.appendChild(checkWrap);
      row.appendChild(destroyInput);
      row.appendChild(removeBtn);
      bindEncryptedToggle(encryptedCheck, valueInput);
      return row;
    }

    // Переключение типа значения в строке: зашифрованная -> password, обычная -> text.
    // Значение НЕ очищаем: если оно было видно (plaintext-переменная), отметка
    // шифрования должна сохранить его уже в зашифрованном виде; для уже
    // зашифованных переменных действует правило «пусто = не менять» (guard модели).
    function bindEncryptedToggle(check, valueEl) {
      if (!check || !valueEl || check.__baEncBound) return;
      check.__baEncBound = true;
      check.addEventListener("change", function () {
        if (check.checked) {
          valueEl.type = "password";
          valueEl.placeholder = "Не изменять, если пусто";
          valueEl.autocomplete = "off";
        } else {
          valueEl.type = "text";
          valueEl.placeholder = "Значение";
        }
      });
    }

    // Серверные строки (variables/_form_field.html.erb) — навешиваем то же
    // переключение на уже отрисованные чекбоксы.
    container.querySelectorAll(".variable-encrypted-check").forEach(function (check) {
      var row = check.closest(".variable-row");
      if (!row) return;
      bindEncryptedToggle(check, row.querySelector('input[name$="[value]"]'));
    });

    // init() выполняется несколько раз на одной странице (DOMContentLoaded + turbo:load),
    // поэтому защищаемся от повторного навешивания обработчиков — иначе один клик
    // добавлял бы две строки.
    var addBtn = document.getElementById("add-variable");
    if (addBtn) {
      function onAddVariable() { container.appendChild(buildRow(nextIndex())); }
      if (addBtn.__baAddVariable) { addBtn.removeEventListener("click", addBtn.__baAddVariable); }
      addBtn.__baAddVariable = onAddVariable;
      addBtn.addEventListener("click", onAddVariable);
    }

    // Удаление строк (делегирование — работает и для изначально отрисованных).
    // Скрытая строка остаётся в форме, а HTML5-валидация не знает про display:none:
    // пустое required-поле имени молча блокировало сабмит («An invalid form control ...
    // is not focusable»). Поэтому при удалении снимаем required. Новая (не сохранённая)
    // строка без id просто убирается из DOM — уничтожать на сервере нечего;
    // сохранённой ставим _destroy=1, чтобы Rails её удалил.
    function onRemoveVariable(e) {
      var btn = e.target.closest(".remove-variable");
      if (!btn) return;
      var row = btn.closest(".variable-row");
      if (!row) return;
      row.querySelectorAll("input[required]").forEach(function (el) { el.required = false; });
      var idInput = row.querySelector('input[name$="[id]"]');
      if (idInput && idInput.value) {
        var hidden = row.querySelector('input[name$="[_destroy]"]');
        if (hidden) { hidden.value = "1"; }
        row.style.display = "none";
      } else {
        row.remove();
      }
    }
    if (container.__baRemoveVar) { container.removeEventListener("click", container.__baRemoveVar); }
    container.__baRemoveVar = onRemoveVariable;
    container.addEventListener("click", onRemoveVariable);
  }

  // Страница «Запуск плея» (runs#new): динамическая подгрузка переменных
  // из выбранного плея (fetch, без перезагрузки), клиентская фильтрация
  // хостов по имени или IP, организации, типу, роли и ОС — применяется строго
  // по кнопке «Применить» (+ «Сбросить») + счётчик выбранных.
  function bindRunForm() {
    var select = document.getElementById("run-play-select");
    if (!select) return; // не страница запуска

    var container = document.getElementById("run-variables-container");
    var hint = document.getElementById("run-variables-hint");
    var addBtn = document.getElementById("add-variable");
    var list = document.getElementById("run-hosts-list");
    var emptyMsg = document.getElementById("run-hosts-empty");
    var countEl = document.getElementById("run-selected-count");
    var selectAll = document.getElementById("run-select-all");

    // --- Переменные из плея (fetch при смене выбора) ---
    function buildVariableRow(idx, name, value) {
      var row = document.createElement("div");
      row.className = "variable-row mb-2 row g-2";
      var c1 = document.createElement("div");
      c1.className = "col-md-6";
      var c2 = document.createElement("div");
      c2.className = "col-md-6";
      var nameInput = document.createElement("input");
      nameInput.type = "text";
      nameInput.className = "form-control";
      nameInput.placeholder = "Имя переменной";
      nameInput.name = "variables[" + idx + "][name]";
      nameInput.value = name || "";
      var valueInput = document.createElement("input");
      valueInput.type = "text";
      valueInput.className = "form-control";
      valueInput.placeholder = "Значение";
      valueInput.name = "variables[" + idx + "][value]";
      valueInput.value = (value === null || value === undefined) ? "" : String(value);
      c1.appendChild(nameInput);
      c2.appendChild(valueInput);
      row.appendChild(c1);
      row.appendChild(c2);
      return row;
    }

    function showHint(text) {
      if (!hint) return;
      hint.textContent = text || "Выберите плей — список переменных подгрузится из него.";
      hint.style.display = "";
    }

    function loadVariables(playId) {
      container.innerHTML = "";
      if (!playId) { showHint(); return; }
      fetch("/run/variables?play_id=" + encodeURIComponent(playId), {
        headers: { Accept: "application/json" }
      })
        .then(function (res) {
          return res.json().catch(function () { return {}; }).then(function (data) {
            return { ok: res.ok, data: data };
          });
        })
        .then(function (result) {
          if (!result.ok || !Array.isArray(result.data)) {
            showHint((result.data && result.data.error) ? result.data.error : "Не удалось загрузить переменные");
            return;
          }
          hint.style.display = "none";
          result.data.forEach(function (v, i) { container.appendChild(buildVariableRow(i, v.name, v.value)); });
        })
        .catch(function () { showHint("Не удалось загрузить переменные"); });
    }

    if (!select.__baRunSelect) {
      select.__baRunSelect = true;
      select.addEventListener("change", function () { loadVariables(select.value); });
    }

    // «Добавить переменную» — строка после существующих, нумерация продолжается.
    if (addBtn && !addBtn.__baRunAddVar) {
      addBtn.__baRunAddVar = true;
      addBtn.addEventListener("click", function () {
        container.appendChild(buildVariableRow(container.querySelectorAll(".variable-row").length));
        hint.style.display = "none";
      });
    }

    // --- Фильтрация хостов (клиентская, по data-атрибутам строк) ---
    var hostRows = list ? Array.prototype.slice.call(list.querySelectorAll(".host-run-row")) : [];
    function visibleRows() {
      return hostRows.filter(function (r) { return r.style.display !== "none"; });
    }

    // Поля фильтра хостов (единый поиск + организация/тип/роль/ОС).
    function filterFieldEls() {
      return ["run-filter-q", "run-filter-org", "run-filter-type", "run-filter-role", "run-filter-os"]
        .map(function (id) { return document.getElementById(id); });
    }

    function applyHostFilter() {
      if (!list) return;
      var fields = filterFieldEls();
      if (fields.some(function (el) { return !el; })) return;
      var fQ = fields[0], fOrg = fields[1], fType = fields[2], fRole = fields[3], fOs = fields[4];

      // Как на странице «Хосты»: один текстовый запрос — совпадение по имени или IP.
      var q = fQ.value.trim().toLowerCase();
      var qOrg = fOrg.value;
      var qType = fType.value;
      var qRole = fRole.value;
      var qOs = fOs.value;

      hostRows.forEach(function (row) {
        var ok = true;
        if (q && row.dataset.name.toLowerCase().indexOf(q) === -1 &&
            row.dataset.ip.toLowerCase().indexOf(q) === -1) ok = false;
        if (ok && qOrg && row.dataset.org !== qOrg) ok = false;
        if (ok && qType && row.dataset.type !== qType) ok = false;
        if (ok && qRole && row.dataset.role.split(",").indexOf(qRole) === -1) ok = false;
        if (ok && qOs && row.dataset.os !== qOs) ok = false;
        row.style.display = ok ? "" : "none";
      });

      if (emptyMsg) emptyMsg.style.display = visibleRows().length ? "none" : "";
    }

    function updateSelectedCount() {
      if (!countEl || !list) return;
      var n = list.querySelectorAll("input[name='host_ids[]']:checked").length;
      countEl.textContent = n ? "Выбрано: " + n : "";
    }

    // «Выбрать все видимые»: состояние галочки отражает видимые строки.
    function syncSelectAll() {
      if (!selectAll) return;
      var vis = visibleRows();
      selectAll.checked = vis.length > 0 && vis.every(function (r) {
        var cb = r.querySelector("input[type=checkbox]");
        return cb && cb.checked;
      });
    }

    if (list) {
      // Смена галочек хостов — делегирование на контейнер.
      function onHostCheckChange() { updateSelectedCount(); syncSelectAll(); }
      if (!list.__baRunChecks) {
        list.__baRunChecks = true;
        list.addEventListener("change", onHostCheckChange);
      }

      if (selectAll && !selectAll.__baRunSelectAll) {
        selectAll.__baRunSelectAll = true;
        selectAll.addEventListener("change", function () {
          visibleRows().forEach(function (r) {
            var cb = r.querySelector("input[type=checkbox]");
            if (cb) cb.checked = selectAll.checked;
          });
          updateSelectedCount();
        });
      }

      // Фильтр применяется строго по кнопке «Применить» (без авто-фильтрации при вводе);
      // «Сбросить» очищает все поля и сразу показывает все хосты.
      var applyBtn = document.getElementById("run-filter-apply");
      if (applyBtn && !applyBtn.__baRunFilterApply) {
        applyBtn.__baRunFilterApply = true;
        applyBtn.addEventListener("click", applyHostFilter);
      }
      var resetBtn = document.getElementById("run-filter-reset");
      if (resetBtn && !resetBtn.__baRunFilterReset) {
        resetBtn.__baRunFilterReset = true;
        resetBtn.addEventListener("click", function () {
          filterFieldEls().forEach(function (el) { if (el) el.value = ""; });
          applyHostFilter();
        });
      }

      updateSelectedCount();
    }
  }

  // --- Live-вывод запуска плея (страница /runs/:id) ---
  var outputPollTimer = null;
  function stopOutputPolling() {
    if (outputPollTimer !== null) { clearInterval(outputPollTimer); outputPollTimer = null; }
  }

  function base64ToBytes(b64) {
    var bin = atob(b64);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) { bytes[i] = bin.charCodeAt(i); }
    return bytes;
  }

  // Опрашивает /runs/:id/output примерно раз в 700 мс: base64-чанки декодируются
  // стриминговым декодером (мультибайтный UTF-8 не ломается на границе чанков),
  // автоскролл сохраняется, если пользователь у нижнего края, при терминальном
  // статусе поллинг останавливается.
  function bindRunOutputPage() {
    var pre = document.getElementById("run-output");
    if (!pre) return;

    stopOutputPolling();

    var runId = pre.getAttribute("data-run-id");
    var badge = document.getElementById("run-status-badge");
    var exitCodeEl = document.getElementById("run-exit-code-value");
    var offset = 0;
    var decoder = new TextDecoder("utf-8", { stream: true });
    var stopped = false;

    var STATUS_META = {
      pending:   { label: "Ожидает", cls: "bg-secondary" },
      running:   { label: "Выполняется", cls: "bg-primary" },
      succeeded: { label: "Завершён успешно", cls: "bg-success" },
      failed:    { label: "Ошибка", cls: "bg-danger" }
    };

    function isNearBottom() {
      return pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 40;
    }

    function applyStatus(status, exitCode) {
      var meta = STATUS_META[status];
      if (badge && meta) {
        badge.textContent = meta.label;
        badge.className = "badge " + meta.cls;
      }
      if (exitCodeEl && exitCode !== null && exitCode !== undefined) {
        exitCodeEl.textContent = String(exitCode);
      }
    }

    function poll() {
      fetch("/runs/" + runId + "/output?after=" + offset, { headers: { Accept: "application/json" } })
        .then(function (res) { return res.json().catch(function () { return null; }); })
        .then(function (data) {
          if (!data || stopped) return;

          var b64 = data.chunk_b64 || "";
          if (b64.length > 0) {
            var bytes = base64ToBytes(b64);
            offset += bytes.length; // следующий чанк начинается сразу после этого
            var nearBottom = isNearBottom();
            pre.textContent += decoder.decode(bytes, { stream: true });
            if (nearBottom) { pre.scrollTop = pre.scrollHeight; }
          }

          applyStatus(data.status, data.exit_code);

          if (data.status === "succeeded" || data.status === "failed") {
            var tail = decoder.decode(); // сбрасываем буфер стримингового декодера
            if (tail) { pre.textContent += tail; }
            stopped = true;
            stopOutputPolling();
          }
        })
        .catch(function () { /* сетевая ошибка — повторим на следующем тике */ });
    }

    outputPollTimer = setInterval(poll, 700);
    poll();
  }

  // Останавливаем поллинг при уходе со страницы (Turbo-навигация или закрытие вкладки).
  if (!document.__baRunOutputLeaveBound) {
    document.__baRunOutputLeaveBound = true;
    document.addEventListener("turbo:before-visit", stopOutputPolling);
    window.addEventListener("pagehide", stopOutputPolling);
  }

  function init() {
    initTheme();
    initSidebar();
    initSubmenu();
    initSelectAll();
    bindModalButtons();
    initDeleteSelected();
    bindEditVariables();
    bindRunForm();
    bindRunOutputPage();
  }
  onTurboLoad(init);
  window.WebAnsible = { openForm: openForm, showModal: showModal };
})();
