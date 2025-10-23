# path: pages/home_page.rb
require_relative 'base_page'
require_relative '../Locators/home_locators'

class HomePage < BasePage
  include HomeLocators

  def click_SEARCH_BAR(timeout: 5)
    remember_last_action(__method__)
    click(SEARCH_BAR, timeout: timeout) # click waits for interactability
    ok = wait_until(timeout: timeout) { present?(SEARCH_INPUT) }
    raise Selenium::WebDriver::Error::TimeoutError, "SEARCH_INPUT no disponible en #{timeout}s" unless ok
    true
  end

  def send_keys_SEARCH_INPUT_and_submit(term, timeout: 25)
    remember_last_action(__method__)

    input = try_find(SEARCH_INPUT, timeout: timeout)
    raise Selenium::WebDriver::Error::TimeoutError, "SEARCH_INPUT no disponible en #{timeout}s" unless input

    input.clear rescue nil
    input.send_keys(term.to_s)

    # Submit for native/web contexts
    begin
      if driver.respond_to?(:press_keycode)
        driver.press_keycode(66) # Android Enter
      else
        input.send_keys(:enter)
      end
    rescue StandardError
      input.send_keys(:enter) rescue nil
    end
    true
  end
end
