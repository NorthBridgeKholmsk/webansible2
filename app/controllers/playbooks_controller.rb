# Плейбуки — конструктор из плеев с ветвлением по типу ОС.
class PlaybooksController < ApplicationController
  before_action :set_playbook, only: [:show, :edit, :update, :destroy]

  def index
    @playbooks = Playbook.order(:name)
    content_for(:page_title) { "Плейбуки" }
  end

  def show
    content_for(:page_title) { @playbook.name }
  end

  def new
    @playbook = Playbook.new
    content_for(:page_title) { "Новый плейбук" }
  end

  def create
    @playbook = Playbook.new(playbook_params)
    if @playbook.save
      redirect_to playbook_path(@playbook), notice: "Плейбук сохранён"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    content_for(:page_title) { "Редактирование: #{@playbook.name}" }
  end

  def update
    if @playbook.update(playbook_params)
      redirect_to playbook_path(@playbook), notice: "Плейбук обновлён"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playbook.destroy
    redirect_to playbooks_path, notice: "Плейбук удалён"
  end

  private

  def set_playbook
    @playbook = Playbook.find(params[:id])
  end

  # Вложенные атрибуты в два уровня: ветвления по ОС и плеи внутри них.
  # position у плеев задаёт JS по текущему порядку строк на странице;
  # _destroy — маркеры удаления (JS оставляет только их в форме).
  def playbook_params
    params.require(:playbook).permit(
      :name, :description,
      sections_attributes: [:id, :os_type, :_destroy,
        section_plays_attributes: [:id, :play_id, :position, :_destroy]]
    )
  end
end