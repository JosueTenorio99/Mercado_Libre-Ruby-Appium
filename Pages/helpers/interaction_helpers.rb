# path: pages/helpers/interaction_helpers.rb
# ======================================
# InteractionHelpers
# Provides safe finders, smart clicking, and basic element interactions.
# ======================================

module InteractionHelpers
  def elements(locator)
    driver.find_elements(*normalize(locator))
  rescue StandardError
    []
  end

  def find!(locator)
    driver.find_element(*normalize(locator))
  end

  def present?(locator)
    !elements(locator).empty?
  end

  def try_find(locator, timeout: 1.5, interval: 0.05)
    el = nil
    wait_until(timeout: timeout, interval: interval) do
      el = find!(locator) rescue nil
      el && (!block_given? || yield(el))
    end
    el
  end

  # Smart and robust click logic
  def click(locator, timeout: 3.0, retries: 1, smart: false, success: nil)
    el = try_find(locator, timeout: timeout) { |e| interactable?(e) }
    raise "Not clickable: #{locator.inspect}" unless el

    driver.hide_keyboard rescue nil
    old_sig = page_signature
    succeeded = false

    (retries + 1).times do
      begin
        el.click
      rescue Selenium::WebDriver::Error::StaleElementReferenceError,
        Selenium::WebDriver::Error::ElementClickInterceptedError
        el = try_find(locator, timeout: 0.8) { |e| interactable?(e) }
        el&.click
      end

      succeeded = wait_until(timeout: 1.0, interval: 0.05) do
        (success && safe_call { success.call }) || page_signature != old_sig
      end

      break if succeeded
    end

    raise "Failed to click #{locator.inspect}" if smart && !succeeded
    true
  end

  private

  def interactable?(el)
    (el.displayed? rescue true) && (el.enabled? rescue true)
  end

  def normalize(locator)
    key = locator.keys.first
    val = locator.values.first
    [key.to_sym, val]
  end
end
