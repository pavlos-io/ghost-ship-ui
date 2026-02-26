module RunEntriesHelper
  def render_session_header(session)
    pills = []
    pills << content_tag(:span, session[:model], class: "bg-purple-100 text-purple-700 text-xs font-medium px-2.5 py-0.5 rounded-full") if session[:model]
    pills << content_tag(:span, session[:session_id], class: "bg-gray-100 text-gray-500 text-xs font-mono px-2.5 py-0.5 rounded-full") if session[:session_id]
    pills << content_tag(:span, session[:source], class: "bg-blue-100 text-blue-700 text-xs font-medium px-2.5 py-0.5 rounded-full") if session[:source]

    content_tag(:div, class: "flex flex-wrap items-center gap-2 mb-4") do
      safe_join(pills)
    end
  end

  def render_turn(turn)
    border_class = case turn[:status]
                   when "failed" then "border-l-4 border-red-400"
                   when "interrupted" then "border-l-4 border-yellow-400"
                   else ""
                   end

    parts = []

    # Thinking (collapsible, purple)
    if turn[:thinking_text].present?
      parts << entry_card("Thinking") do
        content_tag(:details, class: "bg-purple-50 rounded-lg overflow-hidden") do
          summary = content_tag(:summary, class: "px-4 py-3 cursor-pointer text-sm text-purple-600 font-medium list-none") do
            "Extended thinking"
          end
          detail = content_tag(:div, class: "max-h-96 overflow-y-auto border-t border-purple-200") do
            content_tag(:pre, turn[:thinking_text], class: "whitespace-pre-wrap break-words m-0 p-4 bg-transparent font-sans text-sm leading-relaxed text-purple-800")
          end
          safe_join([summary, detail])
        end
      end
    end

    # Message (green card)
    if turn[:message_text].present?
      parts << entry_card("Claude") do
        content_tag(:div, class: "bg-green-50 rounded-lg px-4 py-3") do
          content_tag(:pre, turn[:message_text], class: "whitespace-pre-wrap break-words m-0 p-0 bg-transparent font-sans text-sm leading-relaxed text-gray-800")
        end
      end
    end

    # Tools
    turn[:tools].each do |tool|
      parts << render_tool(tool)
    end

    # Errors
    turn[:errors].each do |error|
      parts << render_error(error[:message])
    end

    # Turn stats
    if turn[:usage] || turn[:stop_reason]
      parts << render_turn_stats(turn)
    end

    content_tag(:div, class: "flex flex-col gap-5 #{border_class}".strip) do
      safe_join(parts)
    end
  end

  def render_session_footer(session)
    return nil if session[:turns].empty?

    total_input = 0
    total_output = 0
    session[:turns].each do |turn|
      if turn[:usage]
        total_input += turn[:usage]["input_tokens"].to_i
        total_output += turn[:usage]["output_tokens"].to_i
      end
    end

    duration = nil
    if session[:started_at] && session[:ended_at]
      begin
        duration = (Time.parse(session[:ended_at]) - Time.parse(session[:started_at])).round(1)
      rescue
        nil
      end
    end

    items = []
    items << content_tag(:span, "#{session[:turns].size} turns", class: "text-gray-600")
    items << content_tag(:span, "#{number_with_delimiter(total_input)} in / #{number_with_delimiter(total_output)} out tokens", class: "text-gray-600") if total_input > 0 || total_output > 0
    items << content_tag(:span, "#{duration}s", class: "text-gray-600") if duration
    items << content_tag(:span, session[:status], class: status_badge_class(session[:status]))

    content_tag(:div, class: "bg-gray-50 rounded-2xl px-5 py-3 mt-4 flex flex-wrap items-center gap-4 text-sm") do
      safe_join(items)
    end
  end

  def render_error(message)
    content_tag(:div, class: "bg-red-50 border border-red-200 rounded-lg px-4 py-3 flex items-center gap-2 text-sm text-red-700") do
      safe_join([
        content_tag(:span, "\u{26a0}\u{fe0f}"),
        content_tag(:span, message)
      ])
    end
  end

  # Outer white card wrapping each entry with a header label
  def entry_card(title, &block)
    content_tag(:div, class: "bg-white rounded-2xl p-5 shadow") do
      header = content_tag(:div, title, class: "text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3")
      safe_join([header, capture(&block)])
    end
  end

  def tool_icon(name)
    case name
    when /read/i then "\u{1f4c4}"
    when /write/i then "\u{270f}\u{fe0f}"
    when /edit/i then "\u{270f}\u{fe0f}"
    when /bash/i then "\u{1f4bb}"
    when /glob/i then "\u{1f50d}"
    when /grep/i then "\u{1f50e}"
    when /list/i then "\u{1f4cb}"
    when /search/i then "\u{1f50d}"
    when /fetch/i then "\u{1f310}"
    when /mcp/i then "\u{1f50c}"
    when /file_change/i then "\u{1f4dd}"
    else "\u{1f527}"
    end
  end

  def tool_display_label(name, input)
    path = input["file_path"] || input["path"] || input["command"] || input["pattern"] || input["query"] || input["url"]
    return nil unless path

    truncate(path.to_s, length: 60)
  end

  private

  def render_tool(tool)
    name = tool[:tool] || "tool"
    input = tool[:input] || {}
    icon = tool_icon(name)
    label = tool_display_label(name, input)

    entry_card("Tool") do
      content_tag(:details, class: "bg-gray-50 rounded-lg overflow-hidden") do
        summary = content_tag(:summary, class: "flex items-center gap-2.5 px-4 py-3 cursor-pointer text-sm list-none") do
          safe_join([
            content_tag(:span, icon, class: "text-base"),
            content_tag(:span, class: "flex flex-col min-w-0") do
              safe_join([
                content_tag(:span, name, class: "font-semibold text-gray-800"),
                (content_tag(:span, label, class: "text-gray-400 font-mono text-xs truncate") if label)
              ].compact)
            end
          ])
        end

        detail = content_tag(:div, class: "max-h-96 overflow-y-auto border-t border-gray-200") do
          content_tag(:pre, JSON.pretty_generate(input), class: "m-0 p-4 text-xs bg-white")
        end

        safe_join([summary, detail])
      end
    end
  end

  def render_turn_stats(turn)
    items = []
    if turn[:usage]
      input_tokens = turn[:usage]["input_tokens"]
      output_tokens = turn[:usage]["output_tokens"]
      items << content_tag(:span, "#{number_with_delimiter(input_tokens)} in", class: "text-gray-500") if input_tokens
      items << content_tag(:span, "#{number_with_delimiter(output_tokens)} out", class: "text-gray-500") if output_tokens
    end
    items << content_tag(:span, turn[:stop_reason], class: "text-gray-400 italic") if turn[:stop_reason]

    content_tag(:div, class: "flex items-center gap-3 text-xs px-1") do
      safe_join(items)
    end
  end

  def status_badge_class(status)
    case status
    when "completed" then "bg-green-100 text-green-700 text-xs font-medium px-2.5 py-0.5 rounded-full"
    when "failed" then "bg-red-100 text-red-700 text-xs font-medium px-2.5 py-0.5 rounded-full"
    when "interrupted" then "bg-yellow-100 text-yellow-700 text-xs font-medium px-2.5 py-0.5 rounded-full"
    else "bg-gray-100 text-gray-600 text-xs font-medium px-2.5 py-0.5 rounded-full"
    end
  end
end
