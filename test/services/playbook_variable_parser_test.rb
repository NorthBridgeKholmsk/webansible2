require "test_helper"

# Парсер play-уровневых переменных из YAML плейбука (PlaybookVariableParser).
class PlaybookVariableParserTest < ActiveSupport::TestCase
  def parse(yaml)
    PlaybookVariableParser.parse(yaml)
  end

  test "parses vars block from the top of a single play, preserving order" do
    result = parse(<<~YAML)
      ---
      - name: Deploy and configure Zabbix Agent
        hosts: all
        become: yes
        vars:
          zabbix_agent_hostname: "{{ inventory_hostname }}"
          zabbix_agent_package: "zabbix-agent"
          zabbix_repo_deb: "/tmp/zabbix-release.deb"
        tasks:
          - name: Install package
            apt:
              name: "{{ zabbix_agent_package }}"
    YAML

    assert result.ok?
    assert_equal [
      ["zabbix_agent_hostname", "{{ inventory_hostname }}"],
      ["zabbix_agent_package", "zabbix-agent"],
      ["zabbix_repo_deb", "/tmp/zabbix-release.deb"]
    ], result.variables
  end

  test "ignores task-level variables completely" do
    result = parse(<<~YAML)
      ---
      - name: Play
        hosts: all
        vars:
          play_level_var: "keep-me"
        tasks:
          - name: Task with own vars
            vars:
              task_level_var: "drop-me"
            command: echo ok
          - name: Set fact
            set_fact:
              another_task_var: "drop-me-too"
    YAML

    assert result.ok?
    assert_equal [["play_level_var", "keep-me"]], result.variables
  end

  test "merges vars of multiple plays, first occurrence wins on duplicates" do
    result = parse(<<~YAML)
      ---
      - name: First play
        hosts: all
        vars:
          common: "from-first-play"
          only_first: "a"
      - name: Second play
        hosts: all
        vars:
          common: "from-second-play"
          only_second: "b"
    YAML

    assert result.ok?
    assert_equal [
      ["common", "from-first-play"],
      ["only_first", "a"],
      ["only_second", "b"]
    ], result.variables
  end

  test "supports multi-document files (several --- documents)" do
    yaml = "---\n- name: A\n  hosts: all\n  vars:\n    a_var: '1'\n---\n- name: B\n  hosts: all\n  vars:\n    b_var: '2'\n"
    result = parse(yaml)

    assert result.ok?
    assert_equal [["a_var", "1"], ["b_var", "2"]], result.variables
  end

  test "supports a single play given as a plain mapping document" do
    result = parse("hosts: all\nvars:\n  solo: 'yes'\n")

    assert result.ok?
    assert_equal [["solo", "yes"]], result.variables
  end

  test "converts non-string values to strings and nil to empty string" do
    result = parse(<<~YAML)
      ---
      - name: Play
        hosts: all
        vars:
          number: 123
          flag: true
          nothing:
    YAML

    assert result.ok?
    assert_equal [["number", "123"], ["flag", "true"], ["nothing", ""]], result.variables
  end

  test "playbook without vars block returns ok with empty list" do
    result = parse("---\n- name: Play\n  hosts: all\n  tasks:\n    - command: echo hi\n")

    assert result.ok?
    assert_equal [], result.variables
  end

  test "empty content is an error result" do
    [nil, "", "   \n"].each do |content|
      result = parse(content)
      refute result.ok?
      assert_equal [], result.variables
      assert_match(/нет содержимого/, result.error)
    end
  end

  test "broken YAML is an error result with message" do
    result = parse("---\n- name: [unclosed\n  hosts: all")

    refute result.ok?
    assert_equal [], result.variables
    assert_match(/Ошибка разбора YAML/, result.error)
  end

  test "document without plays (plain scalar) is an error result" do
    result = parse("just some text")

    refute result.ok?
    assert_match(/не найдено ни одного плейа/, result.error)
  end
end
