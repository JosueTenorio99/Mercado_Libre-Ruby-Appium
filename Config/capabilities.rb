# path: config/capabilities.rb
CONFIG = {
  platformName: 'Android',
  automationName: 'UiAutomator2',

  # 👉 forza que apunte al emulador
  deviceName: ENV.fetch('DEVICE_NAME', ENV.fetch('UDID', 'emulator-5554')),
  'appium:udid': ENV.fetch('UDID', 'emulator-5554'),

  appPackage: 'com.mercadolibre',
  appActivity: 'com.mercadolibre.splash.SplashActivity',
  noReset: false,
  newCommandTimeout: 20,

  # seguro tenerlas encendidas
  'appium:ignoreHiddenApiPolicyError': true,
  'appium:ignoreHiddenApiPolicyCommandFailure': true
}.freeze
