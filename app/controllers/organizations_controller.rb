class OrganizationsController < ApplicationController
  before_action :set_organization, only: [:show, :edit, :update, :destroy]

  def index
    # Поиск по имени (частичное совпадение); пустой запрос — все организации.
    @organizations = Organization.order(:name)
    @organizations = @organizations.search_by_name(params[:q]) if params[:q].present?
    content_for(:page_title) { "Организации" }
  end

  def show
    @variables = @organization.variables
    content_for(:page_title) { "Организация: #{@organization.name}" }
  end

  def new
    @organization = Organization.new
    content_for(:page_title) { "Новая организация" }
  end

  def create
    @organization = Organization.new(organization_params)
    if @organization.save
      redirect_to organization_path(@organization), notice: "Организация сохранена"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    content_for(:page_title) { "Редактирование: #{@organization.name}" }
  end

  def update
    if @organization.update(organization_params)
      redirect_to organization_path(@organization), notice: "Организация обновлена"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @organization.destroy
    redirect_to organizations_path, notice: "Организация удалена"
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(
      :name,
      variables_attributes: [:id, :name, :value, :encrypted, :_destroy]
    )
  end
end
