# path: spec/spec_helper.rb
$stdout.sync = true

require 'appium_lib'
require_relative '../config/capabilities'
# --- Allure: habilitar formatter sin tocar lógica de tests ---
require 'allure-rspec'

Allure.configure do |c|
  c.results_directory = 'reports/allure-results'
  c.clean_results_directory = true
end

RSpec.configure do |config|
  config.add_formatter 'AllureRspecFormatter'
end

def driver_config
  { caps: CONFIG, appium_lib: { server_url: 'http://127.0.0.1:4723' } }
end

# --- helpers locales para screenshot en fallos (sin requerir BasePage) ---
require 'fileutils'
require 'base64'

def current_test_class_name_from(example)
  if example.example_group.respond_to?(:described_class) && example.example_group.described_class
    example.example_group.described_class.name
  else
    file = example.file_path rescue nil
    return 'UnknownSpec' unless file
    base = File.basename(file, '.rb').sub(/_spec\z/, '')
    camel = base.split(/[^0-9A-Za-z]+/).map { |s| s.capitalize }.join
    camel.empty? ? 'UnknownSpec' : "#{camel}Spec"
  end
end

def save_failure_screenshot(driver, example)
  # carpeta por clase de test
  klass = current_test_class_name_from(example)
  folder = File.join('screenshots', klass)
  FileUtils.mkdir_p(folder) rescue nil

  # nombre simple: usa enumeración por hilo para evitar colisiones
  Thread.current[:screenshot_index] = (Thread.current[:screenshot_index] || 0) + 1
  prefix    = format('%02d', Thread.current[:screenshot_index])
  timestamp = Time.now.strftime('%Y%m%d-%H%M%S-%L')
  base      = 'failure'
  path      = File.join(folder, "#{prefix}_#{base}_#{timestamp}.png")

  if driver.respond_to?(:save_screenshot)
    driver.save_screenshot(path)
  elsif driver.respond_to?(:screenshot_as)
    File.open(path, 'wb') { |f| f.write(Base64.decode64(driver.screenshot_as(:base64))) }
  elsif driver.respond_to?(:driver) && driver.driver.respond_to?(:save_screenshot)
    driver.driver.save_screenshot(path)
  end
rescue
  # silencioso por diseño
end
# --- fin helpers ---

RSpec.configure do |config|
  config.before(:suite) do
    $driver = Appium::Driver.new(driver_config, true).start_driver
    Appium.promote_appium_methods Object
  end

  # reinicia enumeración por ejemplo (para naming consistente)
  config.before(:each) do
    Thread.current[:screenshot_index] = 0
  end

  # Captura automática si el ejemplo falla (sin requerir BasePage)
  config.after(:each) do |example|
    if example.exception && $driver&.session_id
      save_failure_screenshot($driver, example)
    end

    if $driver&.session_id
      pkg = CONFIG[:appPackage] rescue nil
      $driver.terminate_app(pkg) rescue nil if pkg
      $driver.manage.timeouts.implicit_wait = 0 rescue nil
    end
  end

  config.after(:suite) do
    if $driver&.session_id
      $driver.quit rescue nil
    end
  end

  def add_allure_custom_style
    css_dir = File.join("reports", "allure-report")
    css_file = File.join(css_dir, "styles.css")

    unless File.exist?(css_file)
      puts "[INFO] Aún no existe el reporte Allure, ejecuta primero: allure generate o allure serve"
      return
    end

    css_code = <<~CSS

    img {
      max-width: 30% !important;  
      height: auto !important;
      border-radius: 8px;
      box-shadow: 0 0 10px rgba(0,0,0,0.25);
      margin: 12px auto;
      display: block;
    }

    /* Fondo gris suave y centrado */
    .attachment__content {
      display: flex;
      justify-content: center;
      align-items: center;
      background-color: #f3f3f3;
      padding: 12px;
      border-radius: 10px;
    }

    CSS

    File.open(css_file, 'a') { |f| f.puts css_code }
    puts "[INFO] ✅ Estilo personalizado añadido al reporte (#{css_file})"
  end


end
