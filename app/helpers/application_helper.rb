module ApplicationHelper
  def highlight_query(text, query)
    return text unless query.present? && text.present?

    normalized_text = accent_insensitive_normalize(text)
    normalized_query = accent_insensitive_normalize(query)
    return text if normalized_query.blank?

    ranges = []
    search_from = 0
    while (pos = normalized_text.index(normalized_query, search_from))
      ranges << (pos...(pos + normalized_query.length))
      search_from = pos + normalized_query.length
    end
    return text if ranges.empty?

    highlighted = +""
    in_mark = false
    text.chars.each_with_index do |char, idx|
      if ranges.any? { |range| range.cover?(idx) }
        unless in_mark
          highlighted << "<mark>"
          in_mark = true
        end
      elsif in_mark
        highlighted << "</mark>"
        in_mark = false
      end
      highlighted << ERB::Util.html_escape(char)
    end
    highlighted << "</mark>" if in_mark
    highlighted.html_safe
  end

  def accent_insensitive_normalize(str)
    str.to_s.chars.map { |char| accent_insensitive_char(char) }.join.downcase
  end

  def accent_insensitive_char(char)
    base = char.downcase
    replacement = Episode::ACCENT_REPLACEMENTS.find { |chars, _| chars.include?(base) }&.last
    return replacement if replacement.present?

    transliterated = I18n.transliterate(base)
    transliterated.present? ? transliterated[0] : base
  end
end
