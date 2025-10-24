# path: pages/helpers/scroll_helpers.rb
# ======================================
# ScrollHelpers
# Provides scrolling logic and collection of items via extractor.
# ======================================

require 'set'

module ScrollHelpers
  def scroll_down(percent: 0.93, column_index: 0)
    size = driver.manage.window.size
    top  = (size.height * 0.20).to_i
    h    = (size.height * 0.60).to_i

    driver.execute_script(
      'mobile: scrollGesture',
      { 'left' => 0, 'top' => top, 'width' => size.width,
        'height' => h, 'direction' => 'down', 'percent' => percent }
    )
    true
  rescue
    ui_script = "new UiScrollable(new UiSelector().scrollable(true).instance(#{column_index})).scrollForward()"
    safe_call { driver.find_element(:uiautomator, ui_script) }
    false
  end

  # Scrolls through a list and collects unique items using an extractor lambda.
  def first_n_by_scroll(card_xpath:, extractor:, max:, max_scrolls: 8)
    products = []
    prices   = []
    seen_keys = Set.new
    consecutive_nochange = 0

    max_scrolls.times do
      cards = driver.find_elements(xpath: card_xpath)
      cards.each do |card|
        data = safe_call { extractor.call(card) }
        next unless data

        name, price, key = data
        key ||= "#{name}|#{price}"
        next if seen_keys.include?(key)

        seen_keys << key
        products << name
        prices  << price
        return [products.first(max), prices.first(max)] if products.size >= max
      end

      old_sig   = page_signature
      old_count = cards.size
      break unless scroll_down(percent: 0.93)

      change = wait_dom_change_or_new(
        card_xpath: card_xpath,
        old_sig: old_sig,
        old_count: old_count,
        timeout: 1.0,
        poll: 0.04
      )

      consecutive_nochange = (change == :no_change) ? (consecutive_nochange + 1) : 0
      break if consecutive_nochange >= 2
    end

    [products.first(max), prices.first(max)]
  end

  # Detects if DOM changed or new items appeared
  def wait_dom_change_or_new(card_xpath:, old_sig:, old_count:, timeout: 1.4, poll: 0.05)
    deadline = monotonic_now + timeout
    while monotonic_now < deadline
      sig = page_signature
      count = driver.find_elements(xpath: card_xpath).size
      return :new_items if count > old_count
      return :changed   if sig != old_sig
      sleep poll
    end
    :no_change
  end
end


# Scrolls until a specific element is visible or max_swipes reached.
def scroll_until(locator, max_swipes: 16, column_index: 0)
  return true if present?(locator)
  max_swipes.times do
    break unless scroll_down(percent: 1.0, column_index: column_index)
    return true if present?(locator)
  end
  false
end

# Scrolls until text is visible on screen (for textual searches)
def scroll_to_text(text, max_swipes: 16, column_index: 0)
  xp = "//*[contains(@text, \"#{text}\")]"
  return true if driver.find_elements(xpath: xp).any?

  max_swipes.times do
    break unless scroll_down(percent: 0.96, column_index: column_index)
    return true if driver.find_elements(xpath: xp).any?
  end
  false
end
