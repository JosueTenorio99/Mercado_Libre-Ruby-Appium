# Mercado_Libre-Ruby-Appium

---

> **Nota:** La **versión en español** de este README se encuentra **justo debajo** de la versión en inglés.

---
Automated functional test for the **Mercado Libre** Android app using **Ruby + Appium**.
The scenario validates **search** → **filters** → **sorting** and extracts the **first 5 product names and prices**, printing them to the console and attaching them to an **Allure HTML report** (with screenshots; on failure, a video is also saved and attached).

> ℹ️ The original requirement asked to filter by **location “CDMX”**.
> The current public app flow doesn’t expose that filter reliably, so this project applies **“Envío Full”** instead to satisfy the “location-like” filter step and keep the test deterministic.

---

## Project tree

```text
.
├── Config
│   └── capabilities.rb
├── Gemfile
├── Gemfile.lock
├── Locators
│   ├── home_locators.rb
│   ├── results_locators.rb
│   └── start_locators.rb
├── Pages
│   ├── base_page.rb
│   ├── helpers
│   ├── home_page.rb
│   ├── results_page.rb
│   └── start_page.rb
├── benchmark_appium.rb
└── spec
    ├── mercado_search_spec.rb
    └── spec_helper.rb

6 directories, 13 files
```

---

## Test flow (what the scenario does)

```ruby
it 'search products and applies filters with screenshots' do
  @start.click_CONTINUE_AS_GUEST_BUTTON
  @start.save_SCREENSHOT

  @home.click_SEARCH_BAR
  @home.save_SCREENSHOT

  @home.send_keys_SEARCH_INPUT('PlayStation 5')
  @home.save_SCREENSHOT

  @results.click_FILTER_BUTTON
  @results.save_SCREENSHOT

  @results.click_DELIVERY_FULL                   # “Envío Full” instead of “CDMX”
  @results.save_SCREENSHOT

  @results.scroll_until_OPTION_NEW
  @results.save_SCREENSHOT

  @results.click_OPTION_NEW                     # condition: “Nuevos”
  @results.save_SCREENSHOT

  @results.scroll_until_SORT_BY_PRICE_DESC_BTN
  @results.save_SCREENSHOT

  @results.click_SORT_BY_PRICE_DESC_BTN         # sort: price high → low
  @results.save_SCREENSHOT

  @results.click_VIEW_RESULTS_BUTTON
  @results.save_SCREENSHOT

  @results.collect_products_and_prices(max: 5)  # prints & attaches
  @results.save_SCREENSHOT
end
```

---

## Tech stack & versions (tested)

* **Ruby**: 3.4.7 (arm64-darwin25)
* **Bundler**: as locked in `Gemfile.lock`
* **Appium**: 3.1.0 (driver: **UiAutomator2**)
* **Selenium-WebDriver**: via Gemfile
* **Allure**: allure-rspec + **Allure CLI** (for HTML report)
* **Android Studio**: 2025.1.4 (includes SDK/AVD Manager)
* **AVDs used**:

    * Pixel 7 — **Android 14** (“UpsideDownCake”) — arm64
    * Pixel 9a — **Android 16** (“Baklava”) — arm64
* **Editor (optional)**: RubyMine 2025.2.3
* **Hardware tested**: MacBook M4 Pro

> The test is **Android-only**.

---

## 1) Clone the repository

You can run this project entirely from a **terminal** — no IDE is required (RubyMine/VS Code are optional).
Clone into any folder you like by changing the **destination path** at the end of the command (optional).

```bash
# Clone into the current directory using default folder name:
git clone https://github.com/JosueTenorio99/Mercado_Libre-Ruby-Appium.git

# OR clone into a specific path/name:
git clone https://github.com/JosueTenorio99/Mercado_Libre-Ruby-Appium.git ~/work/ml-automation

# Enter the project folder and install gems:
cd Mercado_Libre-Ruby-Appium   # or: cd ~/work/ml-automation
bundle install
```

> **IMPORTANT:** Run all commands **from the project root** (the folder containing `Gemfile` and `spec/`).

---

## 2) Prerequisites — Complete setup (macOS & Windows)

### macOS

1. **Install Android Studio (required)**

    * Install Android Studio.
    * In **SDK Manager**, install:

        * **SDK Platforms** (Android 14 or 16)
        * **Android SDK Platform-Tools**
        * **Android SDK Build-Tools**
    * In **AVD Manager**, create an emulator:

        * **Pixel 7 (Android 14)** or **Pixel 9a (Android 16)**.

2. **Install Homebrew**

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **Install Node.js, Appium & Doctor**

   ```bash
   brew install node
   npm install -g appium@3.1.0 appium-doctor
   appium driver install uiautomator2
   appium-doctor --android
   ```

4. **Install Allure CLI**

   ```bash
   brew install allure
   ```

5. **Install Ruby 3.4.7 & Bundler**

   ```bash
   ruby -v  # must show 3.4.7
   brew install rbenv
   rbenv install 3.4.7
   rbenv global 3.4.7
   gem install bundler
   bundle install
   ```

6. **Install the Mercado Libre app** on your emulator from **Play Store**, then open it once.

---

### Windows

1. **Install Android Studio (required)**

    * Install Android Studio → install **SDK Platforms** (Android 14/16), **Platform-Tools**, **Build-Tools**.
    * Create emulator: **Pixel 7 (Android 14)** or **Pixel 9a (Android 16)**.
    * Set environment variables:

      ```
      ANDROID_HOME=C:\Users\<you>\AppData\Local\Android\Sdk
      PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools\bin
      ```

2. **Install Node.js, Appium & Doctor**

   ```powershell
   winget install OpenJS.NodeJS.LTS
   npm install -g appium@3.1.0 appium-doctor
   appium driver install uiautomator2
   appium-doctor --android
   ```

3. **Install Java & Allure CLI**

   ```powershell
   choco install temurin17 allure
   java -version
   allure --version
   ```

4. **Install Ruby 3.4.x & Bundler**

   ```powershell
   gem install bundler
   bundle install
   ```

5. **Install the Mercado Libre app** in your emulator from Play Store.

---

## 3) Start Android & Appium

1. **Start your emulator**

   ```bash
   emulator -list-avds
   emulator -avd Pixel_7_API_34
   ```

2. **Verify ADB**

   ```bash
   adb devices
   ```

   You should see:

   ```
   List of devices attached
   emulator-5554   device
   ```

3. **Run Appium server in another terminal**

   ```bash
   appium
   ```

   Appium must stay running to process driver commands while you launch tests from your main terminal.

---

## 4) Run the test (single command)

> ⛳ **Replace `emulator-5554` with your UDID** (from `adb devices`).
> 📁 **Run this from the project root**.

### ✅ Recommended (auto-generates and opens the Allure report)

```bash
UDID=emulator-5554 bundle exec rspec ; \
allure generate reports/allure-results -o reports/allure-report --clean ; \
ruby -e "require './spec/spec_helper'; add_allure_custom_style" ; \
allure open reports/allure-report
```

### Quick run (terminal output only)

```bash
UDID=emulator-5554 bundle exec rspec
```

---

## 5) What happens during the run

* Screenshots are saved after every step.
* A **video** is recorded automatically **only if the test fails**.
* Results, logs, and media are placed in the `reports/` folder.
* In Allure, open **Suites → [test]** to see step-by-step screenshots and attachments.

---

## 6) Troubleshooting

* **App doesn’t open:** Check `appPackage` and `appActivity` in `Config/capabilities.rb`.
* **Device not detected:**

  ```bash
  adb kill-server && adb start-server
  adb devices
  ```
* **Allure not recognized:** reinstall CLI and verify path (`allure --version`).
* **Slow UI actions:** disable emulator animations (Developer options set to 0x).

---

## 7) Summary — After setup

**Install & prepare:**

* Android Studio (SDK + AVD with Android 14/16)
* Node.js + **Appium 3.1.0** + **appium-doctor** + **UiAutomator2** driver
* **Allure CLI**
* **Ruby 3.4.7** + `bundle install`
* Mercado Libre app installed on the emulator and opened once

**Run:**

1. Start emulator → `adb devices` → copy **UDID**
2. Start Appium in another terminal → `appium`
3. From project root:

   ```bash
   UDID=<your-udid> bundle exec rspec ; \
   allure generate reports/allure-results -o reports/allure-report --clean ; \
   ruby -e "require './spec/spec_helper'; add_allure_custom_style" ; \
   allure open reports/allure-report
   ```

---

# 📄 Español

> **Nota:** Este proyecto se puede ejecutar **directamente desde la terminal** (un IDE es opcional).
> El **resumen rápido** está al final de esta sección.

Automatización funcional de la app **Mercado Libre** en Android con **Ruby + Appium**.
El flujo valida **búsqueda** → **filtros** → **ordenamiento** y extrae **los primeros 5 productos (nombre y precio)**, imprimiéndolos en la consola y adjuntándolos en un **reporte HTML de Allure** (con capturas; si la prueba falla, también guarda y adjunta un video).

> ℹ️ La prueba pedía filtrar por **“CDMX”**.
> El flujo actual de la app pública no expone ese filtro de forma confiable, por lo que este proyecto aplica **“Envío Full”** para cumplir el paso de filtrado “tipo ubicación” y mantener el test determinista.

---

## Árbol del proyecto

```text
.
├── Config
│   └── capabilities.rb
├── Gemfile
├── Gemfile.lock
├── Locators
│   ├── home_locators.rb
│   ├── results_locators.rb
│   └── start_locators.rb
├── Pages
│   ├── base_page.rb
│   ├── helpers
│   ├── home_page.rb
├── Pages
│   ├── results_page.rb
│   └── start_page.rb
├── benchmark_appium.rb
└── spec
    ├── mercado_search_spec.rb
    └── spec_helper.rb

6 directories, 13 files
```

---

## Flujo del test (qué hace el escenario)

```ruby
it 'search products and applies filters with screenshots' do
  @start.click_CONTINUE_AS_GUEST_BUTTON
  @start.save_SCREENSHOT

  @home.click_SEARCH_BAR
  @home.save_SCREENSHOT

  @home.send_keys_SEARCH_INPUT_and_submit('PlayStation 5')
  @home.save_SCREENSHOT

  @results.click_FILTER_BUTTON
  @results.save_SCREENSHOT

  @results.click_DELIVERY_FULL                  # “Envío Full” en lugar de “CDMX”
  @results.save_SCREENSHOT

  @results.scroll_until_OPTION_NEW
  @results.save_SCREENSHOT

  @results.click_OPTION_NEW                     # condición: “Nuevos”
  @results.save_SCREENSHOT

  @results.scroll_until_SORT_BY_PRICE_DESC_BTN
  @results.save_SCREENSHOT

  @results.click_SORT_BY_PRICE_DESC_BTN         # ordenar: precio de mayor a menor
  @results.save_SCREENSHOT

  @results.click_VIEW_RESULTS_BUTTON
  @results.save_SCREENSHOT

  @results.collect_products_and_prices(max: 5)  # imprime y adjunta
  @results.save_SCREENSHOT
end
```

---

## Tecnologías y versiones (probado)

* **Ruby**: 3.4.7 (arm64-darwin25)
* **Bundler**: según `Gemfile.lock`
* **Appium**: 3.1.0 (driver: **UiAutomator2**)
* **Selenium-WebDriver**: vía Gemfile
* **Allure**: allure-rspec + **Allure CLI**
* **Android Studio**: 2025.1.4 (incluye SDK/AVD Manager)
* **AVDs usados**:

    * Pixel 7 — **Android 14** (“UpsideDownCake”) — arm64
    * Pixel 9a — **Android 16** (“Baklava”) — arm64
* **Editor (opcional)**: RubyMine 2025.2.3
* **Hardware probado**: MacBook M4 Pro

> La prueba es **solo Android**.

---

## 1) Clonar el repositorio

Este proyecto puede ejecutarse **desde la terminal** (un IDE es opcional).
Puedes clonar en cualquier carpeta cambiando la **ruta de destino** al final del comando (opcional).

```bash
# Clonar en la carpeta actual con el nombre por defecto:
git clone https://github.com/JosueTenorio99/Mercado_Libre-Ruby-Appium.git

# O clonar en una ruta/nombre específico:
git clone https://github.com/JosueTenorio99/Mercado_Libre-Ruby-Appium.git ~/trabajo/ml-automation

# Entra a la carpeta del proyecto e instala dependencias:
cd Mercado_Libre-Ruby-Appium   # o: cd ~/trabajo/ml-automation
bundle install
```

> **IMPORTANTE:** Ejecuta todos los comandos **desde la raíz del proyecto** (la carpeta con `Gemfile` y `spec/`).

---

## 2) Requisitos — Configuración completa (macOS y Windows)

### macOS

1. **Instalar Android Studio (obligatorio)**

    * Instala Android Studio.
    * En **SDK Manager**, instala:

        * **SDK Platforms** (Android 14 o 16)
        * **Android SDK Platform-Tools**
        * **Android SDK Build-Tools**
    * En **AVD Manager**, crea un emulador:

        * **Pixel 7 (Android 14)** o **Pixel 9a (Android 16)**.

2. **Instalar Homebrew**

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **Instalar Node.js, Appium y Doctor**

   ```bash
   brew install node
   npm install -g appium@3.1.0 appium-doctor
   appium driver install uiautomator2
   appium-doctor --android
   ```

4. **Instalar Allure CLI**

   ```bash
   brew install allure
   ```

5. **Instalar Ruby 3.4.7 y Bundler**

   ```bash
   ruby -v  # debe mostrar 3.4.7
   brew install rbenv
   rbenv install 3.4.7
   rbenv global 3.4.7
   gem install bundler
   bundle install
   ```

6. **Instalar la app Mercado Libre** desde **Play Store** en el emulador y abrirla una vez.

---

### Windows

1. **Instalar Android Studio (obligatorio)**

    * Instala Android Studio → **SDK Platforms** (Android 14/16), **Platform-Tools**, **Build-Tools**.
    * Crea un emulador: **Pixel 7 (Android 14)** o **Pixel 9a (Android 16)**.
    * Variables de entorno:

      ```
      ANDROID_HOME=C:\Users\<you>\AppData\Local\Android\Sdk
      PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools\bin
      ```

2. **Instalar Node.js, Appium y Doctor**

   ```powershell
   winget install OpenJS.NodeJS.LTS
   npm install -g appium@3.1.0 appium-doctor
   appium driver install uiautomator2
   appium-doctor --android
   ```

3. **Instalar Java y Allure CLI**

   ```powershell
   choco install temurin17 allure
   java -version
   allure --version
   ```

4. **Instalar Ruby 3.4.x y Bundler**

   ```powershell
   gem install bundler
   bundle install
   ```

5. **Instalar la app Mercado Libre** en el emulador desde Play Store.

---

## 3) Iniciar Android y Appium

1. **Inicia el emulador**

   ```bash
   emulator -list-avds
   emulator -avd Pixel_7_API_34
   ```

2. **Verifica ADB**

   ```bash
   adb devices
   ```

   Debe mostrar:

   ```
   List of devices attached
   emulator-5554   device
   ```

3. **Ejecuta Appium en otra terminal**

   ```bash
   appium
   ```

   Appium debe permanecer ejecutándose para procesar los comandos del driver mientras lanzas la prueba desde tu terminal principal.

---

## 4) Ejecutar la prueba (un solo comando)

> ⛳ **Reemplaza `emulator-5554` por tu UDID** (de `adb devices`).
> 📁 **Ejecuta esto desde la raíz del proyecto**.

### ✅ Recomendado (genera y abre el reporte Allure automáticamente)

```bash
UDID=emulator-5554 bundle exec rspec ; \
allure generate reports/allure-results -o reports/allure-report --clean ; \
ruby -e "require './spec/spec_helper'; add_allure_custom_style" ; \
allure open reports/allure-report
```

### Rápido (solo consola)

```bash
UDID=emulator-5554 bundle exec rspec
```

---

## 5) Qué sucede durante la ejecución

* Se **toma una captura** después de cada paso.
* Se graba **video únicamente si la prueba falla**.
* Resultados, logs y medios se guardan en `reports/`.
* En Allure, abre **Suites → [test]** para ver capturas y adjuntos.

---

## 6) Solución de problemas

* **La app no abre:** revisa `appPackage`/`appActivity` en `Config/capabilities.rb`.
* **No detecta el dispositivo:**

  ```bash
  adb kill-server && adb start-server
  adb devices
  ```
* **Allure no se encuentra:** reinstala la CLI y confirma (`allure --version`).
* **UI lenta:** desactiva animaciones del emulador (Opciones de desarrollador a 0x).

---

## 7) Resumen — Después de la configuración

**Instalar y preparar:**

* Android Studio (SDK + AVD con Android 14/16)
* Node.js + **Appium 3.1.0** + **appium-doctor** + driver **UiAutomator2**
* **Allure CLI**
* **Ruby 3.4.7** + `bundle install`
* App de Mercado Libre instalada y abierta una vez en el emulador

**Correr:**

1. Inicia emulador → `adb devices` → copia **UDID**
2. Ejecuta Appium en otra terminal → `appium`
3. Desde la raíz del proyecto:

   ```bash
   UDID=<tu-udid> bundle exec rspec ; \
   allure generate reports/allure-results -o reports/allure-report --clean ; \
   ruby -e "require './spec/spec_helper'; add_allure_custom_style" ; \
   allure open reports/allure-report
   ```

---
