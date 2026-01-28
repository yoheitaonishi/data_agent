class TopController < ApplicationController
  def index
    @initial_data = AgenticJob.order(id: :desc).map do |job|
      {
        id: job.id,
        date: job.executed_at.strftime("%Y/%m/%d %H:%M:%S"),
        source: job.source_system,
        destination: job.destination_system,
        status: job.status,
        count: job.record_count,
        requiredAction: job.action_required,
        errorDetail: job.error_message
      }
    end
  end

  def dev
    @title = "取得中..."

    # シンプルなコードとして、コントローラー内で直接実行します。
    # 実際の本番運用ではバックグラウンドジョブでの実行を推奨します。

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    driver = Selenium::WebDriver.for :chrome, options: options

    begin
      driver.get("https://www.yahoo.co.jp/")
      @title = driver.title
    ensure
      driver.quit
    end
  rescue => e
    @title = "エラーが発生しました: #{e.message}"
  end

  def contract_data
    scraper = MoushikomiScraperService.new
    result = scraper.scrape_contract_data

    @contract_data = result[:data] || []
    @pages_scraped = result[:pages_scraped]

    # Also load saved data from database
    @saved_entries = ContractEntry.recent.limit(50)

    if result[:success]
      @status = "契約準備中データを#{result[:count]}件取得してDBに保存しました（#{@pages_scraped}ページ）"
    else
      @status = "エラーが発生しました: #{result[:error]}"
    end
  rescue => e
    @status = "エラーが発生しました: #{e.message}"
    @contract_data = []
    @pages_scraped = 0
    @saved_entries = ContractEntry.recent.limit(50)
    logger.error "contract_data エラー: #{e.message}"
    logger.error e.backtrace.join("\n")
  end

  def saved_contract_data
    @saved_entries = ContractEntry.recent.limit(100)
    @status = "データベースから#{@saved_entries.count}件のデータを取得しました"
  end

  def obic7_import_demo
    Obic7CsvImportService.new.execute
    redirect_to root_path, notice: "OBIC7取込デモを実行しました"
  rescue => e
    logger.error "OBIC7 Import Error: #{e.message}"
    logger.error e.backtrace.join("\n")
    redirect_to root_path, alert: "OBIC7取込実行中にエラーが発生しました: #{e.message}"
  end
end
