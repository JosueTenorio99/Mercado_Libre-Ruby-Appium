# path: pages/home_page.rb
require_relative 'base_page'
require_relative '../Locators/home_locators'

class HomePage < BasePage
  include HomeLocators

  def click_SEARCH_BAR
    remember_last_action(__method__)
    click(SEARCH_BAR)
  end

  def send_keys_SEARCH_INPUT_and_submit(term)
    remember_last_action(__method__)
    input = find(SEARCH_INPUT)
    input.clear rescue nil
    input.send_keys(term.to_s)
    driver.press_keycode(66) rescue input.send_keys(:enter)
    true
  end
end
