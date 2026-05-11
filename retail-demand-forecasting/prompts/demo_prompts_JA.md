# Cloud Agents デモプロンプト — 小売需要予測・在庫最適化
# Cortex Code / Cloud Agents の機能をデモするプロンプト集

### --- 1. データ探索・理解 ---

**プロンプト 1-1: テーブル探索**
```
小売データベースSF_SOLUTIONSがあります。RETAIL_DEMAND_FORECAST_RAWスキーマのテーブルを確認して、どんなデータがあるか教えてください。行数と主要カラムを要約してください。
```

**プロンプト 1-2: データプロファイリング**
```
SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALESテーブルをプロファイリングしてください。
- データの期間
- ユニーク店舗数・商品数
- 総売上・総販売数
- データ品質の問題点
を教えてください。
```

**プロンプト 1-3: 分析と可視化**
```
SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALESから、売上トップ5の商品について週次の販売トレンドを折れ線グラフで表示してください。
```

---

### --- 2. MLモデル構築（Snowflake ML Forecasting）---

**プロンプト 2-1: 予測入力データの準備**
```
需要予測モデルを構築します。SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW.DAILY_SALESを使って、RETAIL_DEMAND_FORECAST_ANALYTICSスキーマに週次集計ビューを作成してください。店舗×商品でグルーピングし、SERIES_ID列（STORE_IDとPRODUCT_IDの連結）とTOTAL_UNITS列を含めてください。
```

**プロンプト 2-2: 予測モデル構築**
```
Snowflake ML Forecastingを使って、SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ANALYTICSにDEMAND_FORECAST_MODELという多変量需要予測モデルを構築してください。WEEKLY_DEMAND_WITH_SERIESビューを入力とし、SERIES_IDをシリーズ列、WEEK_STARTをタイムスタンプ、TOTAL_UNITSをターゲットにしてください。
```

**プロンプト 2-3: 予測生成と保存**
```
DEMAND_FORECAST_MODELで8週間先の予測を95%信頼区間付きで生成してください。結果をSF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ML.DEMAND_FORECASTテーブルに保存してください。カラムはSERIES_ID, STORE_ID, PRODUCT_ID, FORECAST_WEEK, FORECASTED_UNITS, FORECAST_LOWER_95, FORECAST_UPPER_95です。
```

**プロンプト 2-4: モデル評価**
```
DEMAND_FORECAST_MODELの評価指標を表示してください。精度が最も高い/低い店舗×商品の組み合わせはどれですか？上位3シリーズの予測値と実績値を可視化してください。
```

---

### --- 3. 在庫最適化ロジック ---

**プロンプト 3-1: 補充アラート構築**
```
以下のロジックで在庫補充アラートシステムを作成してください：
1. INVENTORY_SNAPSHOTとML予測結果を結合
2. 予測需要に基づく在庫残日数を計算
3. アラートレベルを設定: STOCKOUT, CRITICAL（発注点以下かつ3日未満）, REORDER_NOW, LOW_STOCK（7日未満）, EXPIRING_SOON（賞味期限3日以内）
4. 95パーセンタイル予測に基づく推奨発注量を算出

RETAIL_DEMAND_FORECAST_ANALYTICSスキーマにREPLENISHMENT_ALERTSビューとして作成してください。
```

**プロンプト 3-2: アラートダッシュボード**
```
現在、在庫問題が最も深刻な店舗はどこですか？店舗別のアラートサマリーと発注が必要な総数量を棒グラフで表示してください。
```

**プロンプト 3-3: 自動化**
```
毎朝6時（ET）に補充アラートを更新し、DAILY_ALERTSテーブルに保存するSnowflake Taskを作成してください。ウェアハウスはCOMPUTE_WHを使用します。
```

---

### --- 4. エンドツーエンド実行 ---

**プロンプト 4-1: 全パイプラインデモ**
```
小売需要予測パイプラインの全ステップを実行してください：
1. SF_SOLUTIONSのデータを確認
2. 週次需要集計を構築
3. Snowflake MLで予測モデルをトレーニング
4. 今後8週間の予測を生成
5. 予測に基づく在庫アラートを作成
6. 今すぐ対応が必要な店舗を報告

各ステップの結果を途中で見せてください。
```
