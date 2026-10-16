# После изменения этого файла сервер нужно перезапустить.

# Политика безопасности содержимого (CSP) для всего приложения.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self, :https
#     policy.font_src    :self, :https, :data
#     policy.img_src     :self, :https, :data
#     policy.object_src  :none
#     policy.script_src  :self, :https
#     policy.style_src   :self, :https
#     # URI для отчётов о нарушениях:
#     # policy.report_uri "/csp-violation-report-endpoint"
#   end
#
#   # Nonce из сессии для разрешённых importmap- и inline-скриптов:
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src)
#
#   # Отчёты о нарушениях без принудительного применения политики.
#   # config.content_security_policy_report_only = true
# end
