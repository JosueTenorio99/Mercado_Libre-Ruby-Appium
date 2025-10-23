# path: Locators/home_locators.rb
module HomeLocators
  SEARCH_BAR         = { xpath: '//android.widget.TextView[@resource-id="com.mercadolibre:id/ui_components_toolbar_title_toolbar"]' }
  SEARCH_INPUT       = { id: 'com.mercadolibre:id/autosuggest_input_search' }
  SEARCH_RESULT_ITEM = { id: 'com.mercadolibre:id/row_item' }
end
