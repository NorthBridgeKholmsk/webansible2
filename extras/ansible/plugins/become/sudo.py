# -*- coding: utf-8 -*-
# Пользовательская ТЕНЬ стандартного become-плагина sudo (ansible-core 2.17).
# Лежит в ~/.ansible/plugins/become/ и перекрывает встроенный плагин для всех
# запусков от root — без ручных переменных на хостах.
#
# Причина: хосты с sudo-rs (Rust-переписанный sudo, поставка Ubuntu 26.04+)
# в не-TTY режиме оборачивают даже кастомный промпт из -p собственной рамкой:
#     [sudo: [sudo via ansible, key=XXXX] password:] Password:
# Встроенный плагин (BecomeBase.check_password_prompt) требует, чтобы строка
# НАЧИНАЛАСЬ с "[sudo via ansible, key=...] password:" — на sudo-rs совпадения
# нет и запуск падает с ошибкой "Timeout (12s) waiting for privilege
# escalation prompt". Классический sudo печатает промпт как есть.
#
# Решение: поиск промпта по подстроке вместо префикса — работает для обоих
# вариантов sudo. Ложное срабатывание практически невозможно: в промпте
# случайный 32-символьный ключ этой сессии.
from __future__ import annotations

import re
import shlex

from ansible.module_utils.common.text.converters import to_bytes
from ansible.plugins.become import BecomeBase


DOCUMENTATION = """
    name: sudo
    short_description: Substitute User DO (sudo-rs compatible override)
    description:
        - Override of the stock C(sudo) become plugin. Same behavior, but the
          password prompt is matched as a substring instead of a line prefix so
          that hosts running sudo-rs (Ubuntu 26.04 and later), which wraps even
          custom -p prompts in its own bracketed prefix, work without any extra
          per-host variables. Classic sudo hosts are unaffected.
    author: WebAnsible2 maintenance
    options:
        become_user:
            description: User you 'become' to execute the task
            default: root
            vars:
              - name: ansible_become_user
              - name: ansible_sudo_user
            env:
              - name: ANSIBLE_BECOME_USER
              - name: ANSIBLE_SUDO_USER
            keyword:
              - name: become_user
        become_exe:
            description: Sudo executable
            default: sudo
            vars:
              - name: ansible_become_exe
              - name: ansible_sudo_exe
            env:
              - name: ANSIBLE_BECOME_EXE
              - name: ANSIBLE_SUDO_EXE
            keyword:
              - name: become_exe
        become_flags:
            description: Options to pass to sudo
            default: -H -S -n
            vars:
              - name: ansible_become_flags
              - name: ansible_sudo_flags
            env:
              - name: ANSIBLE_BECOME_FLAGS
              - name: ANSIBLE_SUDO_FLAGS
            keyword:
              - name: become_flags
        become_pass:
            description: Password to pass to sudo
            required: False
            vars:
              - name: ansible_become_password
              - name: ansible_become_pass
              - name: ansible_sudo_pass
            env:
              - name: ANSIBLE_BECOME_PASS
              - name: ANSIBLE_SUDO_PASS
"""


class BecomeModule(BecomeBase):

    name = 'sudo'

    # messages for detecting prompted password issues
    fail = ('Sorry, try again.',)
    missing = ('Sorry, a password is required to run sudo', 'sudo: a password is required')

    def build_become_command(self, cmd, shell):
        super(BecomeModule, self).build_become_command(cmd, shell)

        if not cmd:
            return cmd

        becomecmd = self.get_option('become_exe') or self.name

        flags = self.get_option('become_flags') or ''
        prompt = ''
        if self.get_option('become_pass'):
            self.prompt = '[sudo via ansible, key=%s] password:' % self._id
            if flags:  # this could be simplified, but kept as is for now for backwards string matching
                reflag = []
                for flag in shlex.split(flags):
                    if flag in ('-n', '--non-interactive'):
                        continue
                    elif not flag.startswith('--'):
                        # handle -XnxxX flags only
                        flag = re.sub(r'^(-\w*)n(\w*.*)', r'\1\2', flag)
                    reflag.append(flag)
                flags = shlex.join(reflag)

            prompt = '-p "%s"' % (self.prompt)

        user = self.get_option('become_user') or ''
        if user:
            user = '-u %s' % (user)

        return ' '.join([becomecmd, flags, prompt, user, self._build_success_command(cmd, shell)])

    def check_password_prompt(self, b_output):
        ''' sudo-rs оборачивает промпт в рамку "[sudo: ...] Password:", поэтому
        ищем не префикс строки, а подстроку. Для классического sudo поведение
        идентично (промпт в начале строки тоже является подстрокой). '''
        if self.prompt:
            b_prompt = to_bytes(self.prompt).strip()
            return any(b_prompt in l for l in b_output.splitlines())
        return False
