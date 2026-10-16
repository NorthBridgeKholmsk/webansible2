class FilesController < ApplicationController
  before_action :set_file, only: [:show, :edit, :update, :destroy]

  def index
    @files = FileEntry.order(:name)
    content_for(:page_title) { "Файлы проекта" }
  end

  def show
    content_for(:page_title) { @file.name }
  end

  def new
    @file = FileEntry.new
    @file.organization = Organization.find(params[:organization_id]) if params[:organization_id]
    @organizations = Organization.order(:name)
    content_for(:page_title) { "Новый файл" }
  end

  def create
    @file = FileEntry.new(file_params)
    @organizations = Organization.order(:name)
    if @file.save
      redirect_to file_path(@file), notice: "Файл сохранён"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    content_for(:page_title) { "Редактирование: #{@file.name}" }
  end

  def update
    if @file.update(file_params)
      redirect_to file_path(@file), notice: "Файл обновлён"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @file.destroy
    redirect_to files_path, notice: "Файл удалён"
  end

  private

  def set_file
    @file = FileEntry.find(params[:id])
  end

  def file_params
    params.require(:file_entry).permit(:name, :path, :content, :mime_type, :organization_id)
  end
end