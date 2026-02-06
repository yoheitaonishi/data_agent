class AgenticJob < ApplicationRecord
  has_many :contract_entries, dependent: :nullify
  has_one_attached :customers
  has_one_attached :contracts

  # System names
  SOURCE_SYSTEM_ITANDI = "イタンジ"
  DESTINATION_SYSTEM_OBIC7 = "OBIC7"

  # Status constants
  STATUS_PROCESSING = "processing"
  STATUS_SUCCESS = "success"
  STATUS_WARNING = "warning"
  STATUS_ERROR = "error"

  # Create contract data scraping job record
  def self.create_scraping_job
    create!(
      source_system: SOURCE_SYSTEM_ITANDI,
      destination_system: DESTINATION_SYSTEM_OBIC7,
      status: STATUS_PROCESSING,
      executed_at: Time.current,
      action_required: false
    )
  end

  # Execute OBIC7 CSV import
  def self.execute_obic7_import
    job = create!(
      source_system: "System", # or maybe "DB"
      destination_system: DESTINATION_SYSTEM_OBIC7,
      status: STATUS_PROCESSING,
      executed_at: Time.current,
      action_required: false
    )

    begin
      importer = Obic7CsvImportService.new
      # method name in service is execute
      importer.execute

      # Assuming success if no error raised
      job.update!(
        status: STATUS_SUCCESS,
        record_count: 0, # Placeholder, maybe update service to return count
        action_required: false
      )
      job
    rescue => e
      job.update!(
        status: STATUS_ERROR,
        error_message: e.message,
        action_required: true
      )
      job
    end
  end

  def import_to_obic7
    Obic7CsvImportService.new(agentic_job_id: self.id).execute
  end

  def generate_customers_csv
    require 'csv'

    # 基本情報ファイル用のCSV生成（todo.mdの1種類目）
    csv_data = CSV.generate(encoding: "Shift_JIS", force_quotes: false) do |csv|
      # ヘッダー行（日本語）
      csv << %w[
        取引先コード 顧客正式名 顧客敬称コード 顧客カナ名 顧客略名 生年月日 性別 法人区分
        連絡先名1_1 連絡先敬称コード1_1 連絡先名1_2 連絡先敬称コード1_2 連絡先名1_3 連絡先敬称コード1_3
        連絡先郵便番号1_1 連絡先郵便番号1_2 連絡先住所1_1 連絡先住所1_2
        連絡先電話番号1_1_1 連絡先電話番号1_1_2 連絡先電話番号1_1_3
        連絡先電話番号1_2_1 連絡先電話番号1_2_2 連絡先電話番号1_2_3
        連絡先電話番号1_3_1 連絡先電話番号1_3_2 連絡先電話番号1_3_3
        連絡先電話番号1_4_1 連絡先電話番号1_4_2 連絡先電話番号1_4_3
        連絡先メールアドレス1
        連絡先名2_1 連絡先敬称コード2_1 連絡先名2_2 連絡先敬称コード2_2 連絡先名2_3 連絡先敬称コード2_3
        連絡先郵便番号2_1 連絡先郵便番号2_2 連絡先住所2_1 連絡先住所2_2
        連絡先電話番号2_1_1 連絡先電話番号2_1_2 連絡先電話番号2_1_3
        連絡先電話番号2_2_1 連絡先電話番号2_2_2 連絡先電話番号2_2_3
        連絡先電話番号2_3_1 連絡先電話番号2_3_2 連絡先電話番号2_3_3
        連絡先電話番号2_4_1 連絡先電話番号2_4_2 連絡先電話番号2_4_3
        連絡先メールアドレス2
        勤務先名 勤務先敬称コード 勤務先所属部署名 勤務先役職名 勤務先連絡先名 勤務先連絡先敬称コード
        勤務先郵便番号1 勤務先郵便番号2 勤務先住所1 勤務先住所2
        勤務先電話番号1_1 勤務先電話番号1_2 勤務先電話番号1_3
        勤務先電話番号2_1 勤務先電話番号2_2 勤務先電話番号2_3
        勤務先メールアドレス
        緊急連絡先 緊急連絡先郵便番号1 緊急連絡先郵便番号2 緊急連絡先住所1 緊急連絡先住所2
        緊急連絡先電話番号1_1 緊急連絡先電話番号1_2 緊急連絡先電話番号1_3
        緊急連絡先電話番号2_1 緊急連絡先電話番号2_2 緊急連絡先電話番号2_3
        緊急連絡先借主との関係
        委託会社コード 代表予約区分 代表契約番号 請求書レイアウト区分 退去精算書レイアウト区分
        督促状レイアウト区分 書類送付先コード DM区分 請求書発行区分 延滞任意区分 保証会社コード 備考
        会計取引先コード キャンセル区分 キャンセル日 キャンセル事由 入金方法区分 入金種別コード
        引落先口座コード 引落元銀行コード 引落元支店コード 引落元預金種別区分 引落元口座番号 引落元口座名義人カナ名
        引落元新規区分 引落元顧客番号 支払方法区分
        連絡先1:住所1カナ 連絡先1:住所2カナ 連絡先2:住所1カナ 連絡先2:住所2カナ
        勤務先:住所1カナ 勤務先:住所2カナ 緊急連絡先:住所1カナ 緊急連絡先:住所2カナ
        口座コード バーチャル口座番号 回収月区分 入金期日 休日処理区分 法人番号
      ]

      contract_entries.each do |entry|
        # 物件名と部屋番号を分離
        property_only = extract_property_name_only(entry.property_name)
        room_number = entry.room_id.presence || extract_room_from_property_name(entry.property_name)
        property_with_room = "#{property_only} #{room_number}".strip

        # 連絡先1の電話番号を分割
        phone1_parts = split_phone_number(entry.contact1_phone1)
        # 連絡先1の郵便番号を分割
        postal1_parts = split_postal_code(entry.contact1_postal_code)
        # 連絡先2の電話番号を分割
        phone2_parts = split_phone_number(entry.contact2_phone1)
        # 連絡先2の郵便番号を分割
        postal2_parts = split_postal_code(entry.contact2_postal_code)
        # 勤務先の電話番号を分割
        workplace_phone_parts = split_phone_number(entry.workplace_phone)
        # 勤務先の郵便番号を分割
        workplace_postal_parts = split_postal_code(entry.workplace_postal_code)
        # 緊急連絡先の電話番号を分割
        emergency_phone_parts = split_phone_number(entry.emergency_contact_phone)
        # 緊急連絡先の郵便番号を分割
        emergency_postal_parts = split_postal_code(entry.emergency_contact_postal_code)

        csv << [
          "9999999999",  # 取引先コード（固定）
          format_name_for_customer(entry.applicant_name, entry.applicant_name_kana),  # 顧客正式名
          "1",  # 顧客敬称コード（固定）
          format_kana_name(entry.applicant_name_kana),  # 顧客カナ名
          format_name_for_customer(entry.applicant_name, entry.applicant_name_kana),  # 顧客略名
          format_date_slash(entry.applicant_birth_date),  # 生年月日
          entry.applicant_gender || 2,  # 性別
          entry.applicant_is_corporate ? 1 : 0,  # 法人区分
          # 連絡先1
          property_with_room,  # 連絡先名1_1
          nil,
          format_name_for_customer(entry.applicant_name, entry.applicant_name_kana), # 連絡先名1_2（顧客正式名と同じ）
          "1", nil, nil,
          postal1_parts[0], postal1_parts[1],  # 連絡先郵便番号1
          entry.contact1_address1, entry.contact1_address2,  # 連絡先住所1
          phone1_parts[0], phone1_parts[1], phone1_parts[2],  # 連絡先電話番号1_1
          nil, nil, nil, nil, nil, nil, nil, nil, nil,  # 他の電話番号（空）
          entry.contact1_email,  # 連絡先メールアドレス1
          # 連絡先2
          property_with_room,  # 連絡先名2_1
          nil,
          format_name_for_customer(entry.applicant_name, entry.applicant_name_kana), # 連絡先名2_2（申込者名）
          "1", nil, nil,
          postal2_parts[0], postal2_parts[1],  # 連絡先郵便番号2
          entry.contact2_address1, entry.contact2_address2,  # 連絡先住所2
          phone2_parts[0], phone2_parts[1], phone2_parts[2],  # 連絡先電話番号2_1
          nil, nil, nil, nil, nil, nil, nil, nil, nil,  # 他の電話番号（空）
          entry.contact2_email,  # 連絡先メールアドレス2
          # 勤務先
          format_workplace_name_halfwidth_kana(entry.workplace_name),  # 勤務先名
          "3",  # 勤務先敬称コード（固定）
          entry.workplace_department, entry.workplace_position,
          format_name_for_customer(entry.applicant_name, entry.applicant_name_kana), "1",  # 勤務先連絡先名
          workplace_postal_parts[0], workplace_postal_parts[1],  # 勤務先郵便番号
          normalize_for_shift_jis(entry.workplace_address), nil,  # 勤務先住所
          workplace_phone_parts[0], workplace_phone_parts[1], workplace_phone_parts[2],  # 勤務先電話番号1
          nil, nil, nil, nil,  # 勤務先電話番号2（空）
          # 緊急連絡先
          entry.emergency_contact_name,
          emergency_postal_parts[0], emergency_postal_parts[1],  # 緊急連絡先郵便番号
          entry.emergency_contact_address, nil,  # 緊急連絡先住所
          emergency_phone_parts[0], emergency_phone_parts[1], emergency_phone_parts[2],  # 緊急連絡先電話番号1
          nil, nil, nil,  # 緊急連絡先電話番号2（空）
          entry.emergency_contact_relationship,  # 緊急連絡先借主との関係
          # 固定値
          nil, nil, nil, "0", "0", "0", "1", "0", "1",  # 委託会社コード、代表予約区分、代表契約番号、請求書レイアウト区分、退去精算書レイアウト区分、督促状レイアウト区分、書類送付先コード、DM区分、請求書発行区分
          nil, nil, nil, nil, nil,  # 延滞任意区分、保証会社コード、備考、会計取引先コード、キャンセル区分
          nil, nil, "0", nil, nil, nil, nil, nil, nil, nil, nil, nil, "9",  # 入金方法など
          # カナ住所（空）
          nil, nil, nil, nil, nil, nil, nil, nil,
          # 口座関連（空）
          nil, nil, nil, nil, nil, nil
        ]
      end
    end

    # docs/にファイルを保存
    filename = "customers_#{id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    output_dir = Rails.root.join('docs')
    FileUtils.mkdir_p(output_dir)
    output_path = output_dir.join(filename)
    File.open(output_path, 'wb') do |file|
      file.write(csv_data)
    end
    Rails.logger.info "Customer CSV saved to: #{output_path}"

    # Active Storageにも保存（Redisエラーが出ても処理を続行）
    begin
      customers.attach(
        io: StringIO.new(csv_data),
        filename: filename,
        content_type: 'text/csv'
      )
    rescue RedisClient::CannotConnectError => e
      Rails.logger.warn "Redis connection failed, but CSV file was saved to docs/: #{e.message}"
    end
  end

  def generate_contracts_csv
    require 'csv'

    # 契約ファイル用のCSV生成（todo.mdの2種類目）
    csv_data = CSV.generate(encoding: "Shift_JIS", force_quotes: false) do |csv|
      # ヘッダー行（日本語）
      csv << %w[
        受入元契約番号 物件コード 部屋番号 契約者コード 契約者請求書発行区分 契約者書類送付先コード 契約者申込金額
        入居者コード 入居者続柄コード 入居者請求書発行区分 入居者書類送付先コード 入居者申込金額
        保証人コード 保証人続柄コード 保証人請求書発行区分 保証人書類送付先コード 保証人申込金額
        保証人コード2 保証人続柄コード2 保証人書類送付先コード2
        来店日 申込日 入居日 契約完了日 月額消費税基準日 初回契約日 実績集計年月 売上計上日 賃料発生日
        日割日数 翌月以降請求月数 契約日 更新期間(年) 更新期間(月) 満了日
        請求形態区分 契約処理区分 契約区分 計上部門コード 保証会社コード 保証番号 契約金入金口座コード 契約金入金期日
        仲介手数料区分 仲介手数料配分(％) 仲介手数料金額 仲介業者コード 未払計上日 支払予定日
        契約担当者コード1 契約件数1 契約担当者コード2 契約件数2 契約担当者コード3 契約件数3
        管理担当者コード 担当宅建士コード 督促担当者コード 使用目的コード
        駐車場1NO 駐車場1利用車輌 駐車場2NO 駐車場2利用車輌
        反響コード 退去時注意事項
        決定理由コード1 決定理由コード2 決定理由コード3 決定理由コード4 決定理由コード5
        決定理由コード6 決定理由コード7 決定理由コード8 決定理由コード9 決定理由コード10
        入居計算書顧客書式 入居計算書家主書式 契約書借地書式 契約書定期書式
        重要事項説明書借地書式 重要事項説明書定期書式 取引成立台帳書式 敷金預り証書式
        定期契約の説明書式 鍵預り証書式 更新契約書借地書式 更新契約書定期書式
        退去精算書書式 解約申込書書式
        税計算区分 月額回収月区分 月額入金期日 月額休日処理区分 会計連携用契約番号 仲介業者備考
      ]

      contract_entries.each do |entry|
        # 契約日から各種日付を計算
        move_in = entry.move_in_date || entry.contract_start_date || entry.application_date&.to_date
        contract_date = move_in
        contract_end = move_in ? move_in + 2.years - 1.day : nil
        result_month = move_in&.strftime("%y-%b")
        month_end = move_in ? Date.new(move_in.year, move_in.month, -1) : nil

        # 日割日数と回収月区分を計算
        daily_rent_days = nil
        billing_month = nil
        if move_in
          daily_rent_days = move_in.day <= 10 ? 0 : 1
          billing_month = daily_rent_days
        end

        # 未払計上日と支払予定日
        today = Date.today
        # 支払予定日は未払計上日の翌月25日
        payment_scheduled = Date.new(today.year, today.month, 25).next_month

        # 物件名から部屋番号を抽出
        room_number = entry.room_id.presence || extract_room_from_property_name(entry.property_name)

        csv << [
          "999999999999",  # 受入元契約番号（固定）
          entry.property_code,  # 物件コード（マスタから取得）
          room_number,  # 部屋番号
          nil,  # 契約者コード（空欄）
          "0",  # 契約者請求書発行区分（固定）
          "1",  # 契約者書類送付先コード（固定）
          entry.rent,  # 契約者申込金額（家賃）
          nil,  # 入居者コード（契約者コードと同じ = 空）
          nil, "0", "1", nil,  # 入居者情報
          nil, nil, nil, nil, nil, nil, nil, nil,  # 保証人情報（不要）
          nil,  # 来店日
          entry.application_date&.to_date,  # 申込日
          move_in,  # 入居日
          nil,  # 契約完了日（不要）
          move_in,  # 月額消費税基準日（入居日と同じ）
          move_in,  # 初回契約日（入居日と同じ）
          result_month,  # 実績集計年月（入居日の月）
          month_end,  # 売上計上日（入居日の月の月末）
          move_in,  # 賃料発生日（入居日と同じ）
          nil,  # 日割日数（不要）
          daily_rent_days,  # 翌月以降請求月数
          contract_date,  # 契約日（入居日と同じ）
          "2",  # 更新期間(年)（固定）
          "0",  # 更新期間(月)（固定）
          contract_end,  # 満了日（入居日の2年後の前日）
          "1",  # 請求形態区分（固定）
          "0",  # 契約処理区分（固定）
          "1",  # 契約区分（固定）
          "001",  # 計上部門コード（固定）
          nil, nil, nil, nil,  # 保証会社コード、保証番号、契約金入金口座コード、契約金入金期日
          "0", nil, nil, nil,  # 仲介手数料区分、配分、金額、業者コード
          today,  # 未払計上日（現在日）
          payment_scheduled,  # 支払予定日（翌月25日）
          "004", "1", nil, "0", nil, "0",  # 契約担当者コード
          nil, "004", nil, "1",  # 管理担当者コード、担当宅建士コード、督促担当者コード、使用目的コード
          nil, nil, nil, nil,  # 駐車場情報
          nil, nil,  # 反響コード、退去時注意事項
          nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,  # 決定理由コード
          nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,  # 書式関連
          nil, nil, nil, nil, nil, nil  # 税計算区分など
        ]
      end
    end

    # docs/にファイルを保存
    filename = "contracts_#{id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    output_dir = Rails.root.join('docs')
    FileUtils.mkdir_p(output_dir)
    output_path = output_dir.join(filename)
    File.open(output_path, 'wb') do |file|
      file.write(csv_data)
    end
    Rails.logger.info "Contract CSV saved to: #{output_path}"

    # Active Storageにも保存（Redisエラーが出ても処理を続行）
    begin
      contracts.attach(
        io: StringIO.new(csv_data),
        filename: filename,
        content_type: 'text/csv'
      )
    rescue RedisClient::CannotConnectError => e
      Rails.logger.warn "Redis connection failed, but CSV file was saved to docs/: #{e.message}"
    end
  end

  private

  def split_phone_number(phone)
    return [nil, nil, nil] if phone.nil? || phone.empty?
    parts = phone.gsub(/[^0-9]/, "").scan(/\d+/)
    if parts.length == 3
      parts
    elsif parts.length == 1
      # 10桁または11桁の電話番号を分割
      num = parts[0]
      if num.length == 10
        [num[0..2], num[3..6], num[7..9]]
      elsif num.length == 11
        [num[0..2], num[3..6], num[7..10]]
      else
        [num, nil, nil]
      end
    else
      [parts[0], parts[1], parts[2]]
    end
  end

  def split_postal_code(postal)
    return [nil, nil] if postal.nil? || postal.empty?
    # "-"またはスペースで分割
    parts = postal.split(/[-\s]+/)
    [parts[0], parts[1]]
  end

  def extract_room_from_property_name(property_name)
    # 物件名から部屋番号を抽出（例: "ステージファースト武蔵小山 104" → "104"）
    return nil if property_name.nil?
    if property_name =~ /\s+(\d+[A-Za-z]?)\s*$/
      $1
    else
      nil
    end
  end

  def extract_property_name_only(property_name)
    # 物件名から部屋番号を除去（例: "ステージファースト武蔵小山 104" → "ステージファースト武蔵小山"）
    return nil if property_name.nil?
    if property_name =~ /^(.+?)\s+\d+[A-Za-z]?\s*$/
      $1
    else
      property_name
    end
  end

  def format_name_for_customer(name, kana)
    # 氏名（漢字）のカタカナ部分を半角に変換、スペースは全角スペースに統一
    # 例: "テスト 太郎" → "ﾃｽﾄ　太郎"（全角スペース）
    require 'nkf'
    NKF.nkf('-w -Z4', name.to_s).gsub(/\s+/, "　")  # 全角スペースに変換
  end

  def format_kana_name(kana)
    # スペースなし、半角カタカナ (-Z4: 全角カナ→半角カナ)
    require 'nkf'
    NKF.nkf('-w -Z4', kana.to_s).gsub(/\s+/, "")
  end

  def format_workplace_name_halfwidth_kana(name)
    # カタカナを半角に統一
    require 'nkf'
    NKF.nkf('-w -Z4', name.to_s).gsub(/\s+/, " ")
  end

  def format_date_slash(date)
    date&.strftime("%Y/%-m/%-d")
  end

  def normalize_for_shift_jis(text)
    return "" if text.nil? || text.empty?
    # 全角英数字を半角に変換
    require 'nkf'
    NKF.nkf('-w -Z1', text.to_s)
  end
end
