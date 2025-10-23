# path: config/capabilities.rb
CONFIG = {
  platformName: 'Android',
  deviceName: ENV.fetch('DEVICE_NAME', 'emulator-5556'),
  automationName: 'UiAutomator2',
  appPackage: 'com.mercadolibre',
  appActivity: 'com.mercadolibre.splash.SplashActivity',
  noReset: false,
  newCommandTimeout: 20
}.freeze
