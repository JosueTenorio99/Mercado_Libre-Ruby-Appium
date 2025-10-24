# path: pages/helpers/scroll_helpers.rb
# ======================================
# ScrollHelpers
# Lightweight scrolling and list extraction utilities.
# Designed for Fast Mode — no waits, retries, or presence checks.
# ======================================

require 'set'

module ScrollHelpers
  # Scrolls the screen downward by a percentage.
  def scroll_down(percent: 0.7, column_index: 0)
    size = driver.manage.window.size
    top  = (size.height * 0.20).to_i
    h    = (size.height * 0.60).to_i

    driver.execute_script(
      'mobile: scrollGesture',
      {
        'left' => 0,
        'top' => top,
        'width' => size.width,
        'height' => h,
        'direction' => 'down',
        'percent' => percent
      }
    )

    sleep 0.05  # ✅ tiny delay to let the UI settle before next find
    true
  rescue
    ui_script = "new UiScrollable(new UiSelector().scrollable(true).instance(#{column_index})).scrollForward()"
    safe_call { driver.find_element(:uiautomator, ui_script) }
    false
  end


  # Scrolls until a specific locator is visible or maximum swipes are reached.
  def scroll_until(locator, max_swipes: 16, column_index: 0)
    max_swipes.times do
      begin
        return true if driver.find_element(*normalize(locator))
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # keep scrolling
      end
      break unless scroll_down(percent: 1.0, column_index: column_index)
    end
    false
  end

  # Scrolls until a visible text appears on screen.
  def scroll_to_text(text, max_swipes: 16, column_index: 0)
    xp = "//*[contains(@text, \"#{text}\")]"
    max_swipes.times do
      return true if driver.find_elements(xpath: xp).any?
      break unless scroll_down(percent: 0.96, column_index: column_index)
    end
    false
  end

  # Collects first N items by scrolling a list of cards.
  def first_n_by_scroll(card_xpath:, extractor:, max:, max_scrolls: 10)
    products, prices = [], []
    seen_keys = Set.new
    no_change = 0

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

      old_count = cards.size
      break unless scroll_down(percent: 0.7)

      # ✅ Lightweight DOM change detection
      new_count = driver.find_elements(xpath: card_xpath).size
      changed = new_count > old_count

      no_change = changed ? 0 : no_change + 1
      break if no_change >= 2
    end

    [products.first(max), prices.first(max)]
  end


  # Detects DOM changes or new items after scrolling.
  def wait_dom_change_or_new(card_xpath:, old_sig:, old_count:, timeout: 1.4, poll: 0.05)
    deadline = monotonic_now + timeout
    while monotonic_now < deadline
      sig = page_signature
      count = driver.find_elements(xpath: card_xpath).size
      return :new_items if count > old_count
      return :changed if sig != old_sig
      sleep poll
    end
    :no_change
  end
end
