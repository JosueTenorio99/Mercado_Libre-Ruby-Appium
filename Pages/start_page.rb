# path: pages/start_page.rb
require_relative 'base_page'
require_relative '../Locators/start_locators'

class StartPage < BasePage
  include StartLocators

  def click_CONTINUE_AS_GUEST_BUTTON
    remember_last_action(__method__)
    click(CONTINUE_AS_GUEST_BUTTON)
  end

  def click_NOT_NOW_NOTIFICATIONS_BUTTON
    remember_last_action(__method__)
    click(NOT_NOW_NOTIFICATIONS_BUTTON)
  end
end
