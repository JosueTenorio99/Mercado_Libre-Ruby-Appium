# path: Locators/results_locators.rb
module ResultsLocators
  FILTER_BUTTON           = { xpath: '//android.widget.TextView[contains(@text,"Filtro")]' }
  CONDITION_BUTTON        = { xpath: '//android.view.View[@content-desc="Condición"]' }
  OPTION_NEW              = { xpath: '//android.widget.ToggleButton[@resource-id="ITEM_CONDITION-2230284"]' }
  DELIVERY_FULL           = { xpath: '//android.widget.Image[@text="full"]' }
  SORT_BY_BUTTON = { xpath: "//android.widget.TextView[@text='Ordenar por\n' or @text='Ordenar por']" }

  SORT_BY_PRICE_DESC_BTN  = { xpath: '//android.widget.ToggleButton[@resource-id="sort-price_desc"]' }
  VIEW_RESULTS_BUTTON     = { xpath: '//android.widget.Button[@resource-id=":r3:"]' }

  PRODUCT_TITLES          = { id: 'com.mercadolibre:id/item_result_title' }
  PRODUCT_PRICES          = { id: 'com.mercadolibre:id/item_result_price' }

  POLYCARD_XPATH          = '//android.view.View[@resource-id="polycard_component"]'

  BRAND_CARD_XPATH        = '//android.view.ViewGroup[@resource-id="com.mercadolibre:id/containerBrand"]//android.widget.FrameLayout'

  PRICE_ANY_XPATH         = './/android.widget.TextView[contains(@content-desc, "Pesos")]'
  PRICE_NOW_XPATH         = './/android.widget.TextView[contains(@content-desc, "Pesos") and not(contains(@content-desc, "Antes")) and not(contains(@content-desc, "antes"))]'
  TITLE_ID_IN_CARD_XPATH  = './/android.widget.TextView[@resource-id="com.mercadolibre:id/item_result_title"]'
  TITLE_ANY_IN_CARD_XP    = './/android.widget.TextView[normalize-space(@text)!=""]'
end
