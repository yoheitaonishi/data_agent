module TopHelper
  def status_badge(status)
    case status
    when 'success'
      content_tag(:span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800") do
        concat content_tag(:i, nil, data: { lucide: "check-circle" }, class: "w-3 h-3 mr-1")
        concat " 成功"
      end
    when 'warning'
      content_tag(:span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800") do
        concat content_tag(:i, nil, data: { lucide: "alert-triangle" }, class: "w-3 h-3 mr-1")
        concat " 警告"
      end
    when 'error'
      content_tag(:span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800") do
        concat content_tag(:i, nil, data: { lucide: "x-circle" }, class: "w-3 h-3 mr-1")
        concat " エラー"
      end
    when 'processing'
      content_tag(:span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800") do
        concat content_tag(:i, nil, data: { lucide: "loader-2" }, class: "w-3 h-3 mr-1 animate-spin")
        concat " 処理中"
      end
    else
      content_tag(:span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800") do
        status
      end
    end
  end
end
