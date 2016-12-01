module ApplicationHelper
  def tag_path(tag)
    query = [params[:q], tag].compact.join(' ')
    url_for(path_params.merge(q: query))
  end

  def author_path(author_name)
    authors = (params[:authors] || []) + [author_name.parameterize]
    url_for(path_params.merge(authors: authors))
  end

  private

  def path_params
    params.permit(:authors, :hours_ago, :q, :sort, :sources)
  end
end
