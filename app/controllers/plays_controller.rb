class PlaysController < ApplicationController
  before_action :set_play, only: [:show, :edit, :update, :destroy]

  def index
    @plays = Play.order(:name)
    content_for(:page_title) { "Плеи" }
  end

  def show
    content_for(:page_title) { @play.name }
  end

  def new
    @play = Play.new
    # Для нового плея в поле «Содержимое» сразу подставляем шаблон.
    @play.content = default_play_content unless @play.persisted?
    content_for(:page_title) { "Новый плей" }
  end

  def create
    @play = Play.new(play_params)
    if @play.save
      redirect_to play_path(@play), notice: "Плей сохранён"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    content_for(:page_title) { "Редактирование: #{@play.name}" }
  end

  def update
    if @play.update(play_params)
      redirect_to play_path(@play), notice: "Плей обновлён"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @play.destroy
    redirect_to plays_path, notice: "Плей удалён"
  end

  private

  def set_play
    @play = Play.find(params[:id])
  end

  # Шаблон содержимого нового плея (YAML). Подставляется в форму создания.
  def default_play_content
    "---\n- host: all\n  tasks:\n"
  end

  def play_params
    params.require(:play).permit(:name, :os_type, :content, :description, :enabled)
  end
end