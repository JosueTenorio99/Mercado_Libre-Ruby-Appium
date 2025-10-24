# path: pages/base_page.rb
require 'base64'
require 'set'
require 'tempfile'

# ================================
# BasePage
# Core foundation for all pages.
# Provides waiting, interaction, scrolling, UI helpers, and sync utilities.
# ================================

require_relative 'helpers/wait_helpers'
require_relative 'helpers/interaction_helpers'
require_relative 'helpers/scroll_helpers'
require_relative 'helpers/ui_helpers'
require_relative 'helpers/reports_helpers'

class BasePage
  include WaitHelpers
  include InteractionHelpers
  include ScrollHelpers
  include UIHelpers
  include ReportsHelpers

  attr_reader :driver

  def initialize(driver = $driver)
    @driver = driver
  end

  # --- General state tracking ---
  def remember_last_action(sym)
    @__last_action = sym.to_s
  end

  def last_action_name
    @__last_action || 'unknown_action'
  end

  # --- Safe execution wrapper ---
  def safe_call
    yield
  rescue StandardError
    nil
  end

  # --- Page state signatures ---
  def page_signature
    driver.page_source.hash
  rescue StandardError
    monotonic_now.to_i
  end

  # --- Monotonic clock for precise timing ---
  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
