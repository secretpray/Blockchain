# frozen_string_literal: true

# Flash notification helper
module FlashHelper
  # Icon and color configuration for different flash types
  FLASH_CONFIG = {
    "success" => { icon: "check-circle", color: "text-green-500" },
    "notice" => { icon: "check-circle", color: "text-blue-500" },
    "error" => { icon: "x-circle", color: "text-red-500" },
    "alert" => { icon: "alert-circle", color: "text-yellow-500" },
    "danger" => { icon: "x-circle", color: "text-red-500" },
    "info" => { icon: "info", color: "text-blue-500" }
  }.freeze

  DEFAULT_CONFIG = { icon: "info", color: "text-primary" }.freeze

  # Renders status icon using SVG
  #
  # @param key [String, Symbol] flash key or status type
  # @param size [String] icon size (default: 20)
  #
  # @example
  #   status_icon_tag(:success)
  #   status_icon_tag(:error)
  #
  def status_icon_tag(key, size: "20")
    config = FLASH_CONFIG.fetch(key.to_s, DEFAULT_CONFIG)
    icon_svg(config[:icon], config[:color], size)
  end

  private

  def icon_svg(icon_name, color_class, size)
    case icon_name
    when "check-circle"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", width: size, height: size,
                  viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
                  stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round",
                  class: "#{color_class} flex-shrink-0") do
        safe_join([
          tag.path(d: "M22 11.08V12a10 10 0 1 1-5.93-9.14"),
          tag.polyline(points: "22 4 12 14.01 9 11.01")
        ])
      end
    when "x-circle"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", width: size, height: size,
                  viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
                  stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round",
                  class: "#{color_class} flex-shrink-0") do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "10"),
          tag.line(x1: "15", y1: "9", x2: "9", y2: "15"),
          tag.line(x1: "9", y1: "9", x2: "15", y2: "15")
        ])
      end
    when "alert-circle"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", width: size, height: size,
                  viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
                  stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round",
                  class: "#{color_class} flex-shrink-0") do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "10"),
          tag.line(x1: "12", y1: "8", x2: "12", y2: "12"),
          tag.line(x1: "12", y1: "16", x2: "12.01", y2: "16")
        ])
      end
    when "info"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", width: size, height: size,
                  viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
                  stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round",
                  class: "#{color_class} flex-shrink-0") do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "10"),
          tag.line(x1: "12", y1: "16", x2: "12", y2: "12"),
          tag.line(x1: "12", y1: "8", x2: "12.01", y2: "8")
        ])
      end
    else
      content_tag(:div, "", class: "w-5 h-5 #{color_class}")
    end
  end
end
