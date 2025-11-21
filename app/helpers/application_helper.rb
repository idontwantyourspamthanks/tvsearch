module ApplicationHelper
  def highlight_query(text, query)
    return text unless query.present? && text.present?

    highlight(text, query, highlighter: '<mark>\1</mark>')
  end
end
