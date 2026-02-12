# テストスクリプト

このディレクトリには、CSV生成機能のテストスクリプトが含まれています。

## スクリプト一覧

### test_generate_csv.rb
OBIC7にアクセスせずにローカルのマスターCSVを使用してCSVを生成するテストスクリプト。

**使用方法:**
```bash
bundle exec ruby scripts/test_generate_csv.rb
```

**前提条件:**
- `docs/master_customers.csv` が存在すること
- `docs/master_properties.csv` が存在すること

**実行内容:**
1. テスト用のAgenticJobとContractEntryを作成
2. ローカルマスタCSVをActive Storageに添付
3. `generate_customers_csv`メソッドを実行
4. `generate_contracts_csv`メソッドを実行
5. 生成結果の検証とプレビュー表示

**オプション:**
- スクリプト実行時に既存のテストデータを削除するか確認されます
- `y` を入力すると削除、それ以外はスキップ

**出力:**
- `docs/customers_{job_id}_{timestamp}.csv`
- `docs/contracts_{job_id}_{timestamp}.csv`

**生成されるテストデータ:**
- 山田 太郎（ル･リオン練馬富士見台 101）
- 佐藤 花子（ル･リオンFREYER南砂EAST 205）

---

### regenerate_test.rb
申し込み受付くん（イタンジ）から取得した実データでCSVを生成するスクリプト。

**使用方法:**
```bash
bundle exec ruby scripts/regenerate_test.rb
```

**前提条件:**
- `docs/master_customers.csv` が存在すること
- `docs/master_properties.csv` が存在すること
- ContractEntry ID: 6 が存在すること（申し込み受付くんのテスト太郎データ）

**実行内容:**
1. 新しいAgenticJobを作成
2. ContractEntry ID: 6 を紐付け
3. 顧客マスタから最大顧客コードを取得
4. CSVを生成

**出力:**
- 顧客マスタの最大値と次の顧客コードを表示
- 生成されたCSVファイル名を表示
- `docs/customers_{job_id}_{timestamp}.csv`
- `docs/contracts_{job_id}_{timestamp}.csv`

---

## マスタCSVファイルについて

### 取得方法
マスタCSVは通常、OBIC7から以下の方法で取得します：

```ruby
# 顧客マスタのエクスポート
service = Obic7ExportMasterService.new(agentic_job_id: job_id)
service.execute_export_customer

# 物件マスタのエクスポート
service = Obic7ExportMasterService.new(agentic_job_id: job_id)
service.execute_export_properties
```

エクスポートされたファイルは `tmp/downloads/` に保存されます。

### ファイル配置
テストスクリプトを実行する前に、以下のファイルを配置してください：

```
docs/
├── master_customers.csv  # 顧客マスタ（Shift-JIS）
└── master_properties.csv # 物件マスタ（Shift-JIS）
```

**注意:** これらのファイルにはOBIC7の実データが含まれるため、`.gitignore`に追加されています。

---

## トラブルシューティング

### マスタファイルが見つからない
```
✗ Customer master not found at: /path/to/docs/master_customers.csv
```

**解決策:** `docs/` ディレクトリに `master_customers.csv` と `master_properties.csv` を配置してください。

### 物件コードが取得できない
物件名の全角/半角カタカナの違いにより、物件マスタで物件が見つからない場合があります。

**確認方法:**
```ruby
# 物件名の正規化確認
job = AgenticJob.last
property_name = "ル･リオン練馬富士見台"
normalized = job.send(:normalize_property_name, property_name)
puts normalized  # => "ﾙ･ﾘｵﾝ練馬富士見台"
```

### 顧客コードが重複する
複数回テストを実行すると、顧客マスタに以前のテストデータが残っている可能性があります。

**解決策:**
1. 顧客マスタをバックアップから復元
2. テストデータ（9999999999など）を削除
3. 再度テストを実行

---

## 関連ドキュメント

- [TEST_RESULTS.md](../TEST_RESULTS.md) - テスト結果の詳細
- [test_taro_summary.md](../docs/test_taro_summary.md) - テスト太郎のCSV生成結果
- [agentic_job_spec.md](../agentic_job_spec.md) - AgenticJobモデルの仕様
