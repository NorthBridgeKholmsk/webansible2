class HostsController < ApplicationController
  before_action :set_host, only: [:show, :edit, :update, :destroy]

  def index
    # Фильтры списка хостов: текстовый запрос (имя или IP) и значения типа,
    # роли и ОС из выпадающих списков. Пустые параметры — без фильтра.
    @hosts = Host.includes(:organization).order(:name)
    @hosts = @hosts.search_by_name_or_ip(params[:q]) if params[:q].present?
    @hosts = @hosts.where(type: params[:type]) if params[:type].present?
    @hosts = @hosts.search_by_role(params[:role]) if params[:role].present?
    @hosts = @hosts.where(os_type: params[:os_type]) if params[:os_type].present?
    content_for(:page_title) { "Хосты" }
  end

  def show
    @variables = @host.variables
    content_for(:page_title) { "Хост: #{@host.name}" }
  end

  def new
    @host = Host.new
    @organizations = Organization.order(:name)
    content_for(:page_title) { "Новый хост" }
  end

  def create
    @host = Host.new(host_params)
    if @host.save
      redirect_to host_path(@host), notice: "Хост сохранён"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organizations = Organization.order(:name)
    content_for(:page_title) { "Редактирование: #{@host.name}" }
  end

  def update
    result = @host.update(host_params)
    Rails.logger.info("UPDATE_RESULT valid=#{result.inspect} errors=#{@host.errors.full_messages.inspect}")
    if result
      redirect_to host_path(@host), notice: "Хост обновлён"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @host.destroy
    redirect_to hosts_path, notice: "Хост удалён"
  end

  private

  def set_host
    @host = Host.find(params[:id])
  end

  def host_params
    params.require(:host).permit(
      :name, :ip, :login, :password, :type, :os_type, :organization_id, role: [],
      variables_attributes: [:id, :name, :value, :encrypted, :_destroy]
    )
  end
end
