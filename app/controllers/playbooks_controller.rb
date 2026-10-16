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
    # Для нового плейбука в поле «Содержимое» сразу подставляем шаблон.
    @playbook.content = default_playbook_content unless @playbook.persisted?
    content_for(:page_title) { "Новый плейбук" }
  end

  def create
    @playbook = Playbook.new(playbook_params)
    if @playbook.save
      redirect_to playbook_path(@playbook), notice: "Пейбук сохранён"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    content_for(:page_title) { "Редактирование: #{@playbook.name}" }
  end

  def update
    if @playbook.update(playbook_params)
      redirect_to playbook_path(@playbook), notice: "Пейбук обновлён"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playbook.destroy
    redirect_to playbooks_path, notice: "Пейбук удалён"
  end

  private

  def set_playbook
    @playbook = Playbook.find(params[:id])
  end

  # Шаблон содержимого нового плейбука (YAML). Подставляется в форму создания.
  def default_playbook_content
    "---\n- host: all\n  tasks:\n"
  end

  def playbook_params
    params.require(:playbook).permit(:name, :os_type, :content, :description, :enabled)
  end
end