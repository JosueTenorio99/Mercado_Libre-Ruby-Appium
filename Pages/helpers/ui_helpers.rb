# path: pages/helpers/ui_helpers.rb
# ======================================
# UIHelpers
# Provides geometry and small visual-related utilities.
# ======================================

module UIHelpers
  def bounds_rect(el)
    b = safe_call { el.attribute('bounds') }
    return [0, 0, 0, 0] unless b && b =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/
    [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
  end

  def center_y(el)
    r = bounds_rect(el)
    (r[1] + r[3]) / 2.0
  end
end
