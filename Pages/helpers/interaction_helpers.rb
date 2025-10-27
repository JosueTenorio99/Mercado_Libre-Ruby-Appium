# path: pages/helpers/interaction_helpers.rb
# ======================================
# InteractionHelpers
# Minimal, fast, and direct element interaction utilities.
# Used for immediate clicks and lookups without waiting logic.
# ======================================

module InteractionHelpers
    include WaitHelpers
  # Clicks an element directly using its locator.
  # Expects the element to already be visible and interactable.
def click(locator, timeout: 10)
  wait_until(timeout: timeout) do
    begin
      el = find(locator)
      el.displayed? && el.enabled?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      false
    end
  end

  find(locator).click
  true
rescue Selenium::WebDriver::Error::TimeoutError
  raise "Timeout waiting for element: #{locator.inspect}"
end


  # Finds and returns a single element.
  def find(locator)
    driver.find_element(*normalize(locator))
  rescue Selenium::WebDriver::Error::NoSuchElementError
    raise "Element not found for locator: #{locator.inspect}"
  end

  private

  # Normalizes a locator hash into a valid Selenium selector array.
  # Example: {id: 'foo'} → [:id, 'foo']
  def normalize(locator)
    key = locator.keys.first
    val = locator.values.first
    [key.to_sym, val]
  end
end
