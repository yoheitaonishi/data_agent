require "selenium-webdriver"
require "csv"

class Obic7ExportMasterService
  class ImportError < StandardError; end

  # Constants from spec
  LOGIN_URL = "https://metawn.obic7.obicnet.ne.jp/WebMenu30/Pages/Common/MainFrame.aspx"
  DEFAULT_USER = "t.izumi"
  DEFAULT_PASSWORD = "ym3dCfrQcHEc"

  def initialize(agentic_job_id: nil)
    @agentic_job_id = agentic_job_id
    @driver = nil
    @wait = nil
  end

  def execute_export_customer
    setup_driver
    login
    perform_export_master("【賃貸住宅管理】顧客登録", "顧客基本情報出力定義")
  ensure
    cleanup_driver
    @temp_customer_csv&.close!
  end

  def execute_export_properties
    setup_driver
    login
    perform_export_master("【賃貸住宅管理】物件登録", "物件基本情報出力定義")
  ensure
    cleanup_driver
    @temp_customer_csv&.close!
  end

  private

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    # Headless mode can be disabled for debugging if needed, but keeping it consistent with other services
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")

    prefs = {
      "default_directory" => Rails.root.join("tmp", "downloads").to_s,
      "prompt_for_download" => false
    }
    options.add_preference(:download, prefs)

    @driver = Selenium::WebDriver.for :chrome, options: options
    @wait = Selenium::WebDriver::Wait.new(timeout: 15)
  end

  def cleanup_driver
    @driver&.quit
  end

  def login
    Rails.logger.info "Navigating to OBIC7 login page: #{LOGIN_URL}"
    @driver.get(LOGIN_URL)

    sleep(3)

    iframe = @wait.until { @driver.find_element(:id, "frameMenu") }
    @driver.switch_to.frame(iframe)

    # - input id=txtID　が表示されるまで待機
    Rails.logger.info "Waiting for txtID input..."
    txt_id_input = @wait.until { @driver.find_element(:id, "txtID") }

    # - input id=txtID に t.izumi を入力
    Rails.logger.info "Entering username..."
    username = ENV["OBIC7_USER"] || DEFAULT_USER
    txt_id_input.clear
    txt_id_input.send_keys(username)

    # - input id=txtPassword に ym3dCfrQcHEc を入力
    Rails.logger.info "Entering password..."
    password = ENV["OBIC7_PASSWORD"] || DEFAULT_PASSWORD
    txt_password_input = @driver.find_element(id: "txtPassword")
    txt_password_input.clear
    txt_password_input.send_keys(password)

    # - button id=btnLogin をクリック
    Rails.logger.info "Clicking login button..."
    btn_login = @driver.find_element(id: "btnLogin")

    sleep(2)

    btn_login.click

    login_completed = @wait.until { @driver.find_element(:tag_name, "body").text.include?("\u4E0D\u52D5\u7523\u5171\u901A\u30E1\u30CB\u30E5\u30FC") }

    # Wait for login to complete (simple check, maybe URL change or element presence)
    # The spec ends here, but in practice we should wait.
    # Assuming successful login leads to a different URL or page state.
    # For now, just a brief wait or check if we are redirected.
    sleep 2
    Rails.logger.info "Login action performed."
  end

  def perform_export_master(bunrui_name, teigi_name)
    # 不動産共通メニュー というラベルを含む、classがpItemのdivタグを取得

    original_window = @driver.window_handle

    Rails.logger.info "Looking for '不動産共通メニュー' menu item..."
    menu_item = @wait.until do
      @driver.find_element(:xpath, "//div[contains(@class, 'pItem') and contains(., '不動産共通メニュー')]")
    end    

    Rails.logger.info "Clicking '不動産共通メニュー'..."
    menu_item.click

    sleep(1)

    master_data_menu_item = @wait.until do
      @driver.find_element(:xpath, "//div[contains(@class, 'pIG') and contains(., 'マスタ入出力')]")
    end

    Rails.logger.info "Clicking 'マスタデータ取込'..."
    master_data_menu_item.click

    sleep(1)

    master_data_export_menu_item = @wait.until do
      @driver.find_element(:xpath, "//li[contains(@class, 'pIJ') and contains(., 'マスタ出力')]")
    end

    master_data_export_menu_item.click

    sleep(1)

    @wait.until do
      @driver.window_handles.size > 1
    end

    new_window = (@driver.window_handles - [ original_window ]).first
    @driver.switch_to.window(new_window)

    sleep(1)

    export_master_window = @driver.window_handle   

    bunrui_select = @driver.find_element(:name, "ctl00$mainArea$ddlBunrui")
    bunrui_select.find_element(:xpath, "//option[contains(text(), '#{bunrui_name}')]").click

    sleep(1)

    teigi_select = @driver.find_element(:name, "ctl00$mainArea$ddlTeigiName")
    teigi_select.find_element(:xpath, "//option[contains(text(), '#{teigi_name}')]").click

    sleep(1)

    display_button = @driver.find_element(:name, "ctl00$mainArea$btnDisp")
    display_button.click

    sleep(1)

    shutsuryoku_button = @driver.find_element(:name, "ctl00$footerArea$btnOutput")
    shutsuryoku_button.click

    sleep(1)

    confirm_button = @driver.find_element(:xpath, "//input[@value='はい']")
    confirm_button.click

    sleep(1)

    # ダウンロードしたCSVを取得
    download_dir = Rails.root.join("tmp", "downloads")
    FileUtils.mkdir_p(download_dir)

    Rails.logger.info "Waiting for file download in #{download_dir}..."

    downloaded_file = nil
    
    # シンプルに最新のファイルを取得
    @wait.until do
      files = Dir.glob(download_dir.join("*.csv")).sort_by { |f| File.mtime(f) }.reverse
      downloaded_file = files.first
      downloaded_file.present?
    end

    Rails.logger.info "Successfully downloaded: #{downloaded_file}"
    
    if @agentic_job_id
      job = AgenticJob.find(@agentic_job_id)
      
      if bunrui_name.include?("顧客登録")
        job.customer_master.attach(io: File.open(downloaded_file), filename: File.basename(downloaded_file), content_type: 'text/csv')
        Rails.logger.info "Attached customer master CSV to AgenticJob #{@agentic_job_id}"
      elsif bunrui_name.include?("物件登録")
        job.property_master.attach(io: File.open(downloaded_file), filename: File.basename(downloaded_file), content_type: 'text/csv')
        Rails.logger.info "Attached property master CSV to AgenticJob #{@agentic_job_id}"
      end
    end
  end
end
