<!-- markdownlint-disable MD013 MD033 MD041 -->

![ヘッダー画像](./assets/readme/header.png)

# specification

ポートフォリオ用の仕様書・API契約・設計メモを管理するリポジトリです。
複数のアプリや関連サービスの仕様を、実装リポジトリから参照しやすい形で保管します。

[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.1-6BA539?logo=openapiinitiative&logoColor=white)](./fictional-drug-and-disease-ref/openapi.json)
[![License](https://img.shields.io/github/license/Corvus400/specification)](./LICENSE)
[![Documentation](https://img.shields.io/badge/docs-specification-555555)](./)

---

## DISCLAIMER

このリポジトリに含まれる医薬品・疾患・臨床計算ツール関連の仕様は、架空データを扱うサンプルアプリ向けの設計資料です。該当する仕様は、医療判断・診断・処方・服薬判断その他のいかなる医療行為にも一切用いないでください。

Some specifications in this repository describe FICTIONAL drug, disease, and clinical-calculation sample data. They are NOT medical advice and MUST NOT be used for diagnosis, treatment, prescribing, or any other medical decision.

---

## 主な特徴

- **仕様書を実装から分離** — アプリや関連サービスから参照する仕様・設計メモを独立管理
- **アプリ単位で仕様を整理** — プロジェクトごとにディレクトリを分け、画面仕様、データモデル、API 契約、永続化スキーマを配置
- **契約ファイルを同梱** — OpenAPI など、実装側が参照する machine-readable な契約も必要に応じて保管
- **ポートフォリオ向けの短い説明構成** — README は参照実装リポジトリと同じ流れで、初見でも役割が分かる構成に統一

---

## 仕様の置き場所

仕様はアプリまたはサービス単位のディレクトリにまとめます。README では個別ファイルを列挙せず、各ディレクトリを仕様セットの入口として扱います。

現在は `fictional-drug-and-disease-ref/` に、架空医薬品・疾患リファレンスアプリと連携 mock-server の仕様を配置しています。この配下には、画面仕様、データモデル、DB スキーマ、fixture 設計、OpenAPI 契約が含まれます。

今後別アプリの仕様を追加する場合も、同じ粒度でディレクトリを追加し、README は代表的な仕様領域と運用方針だけを説明します。

---

## 現在の関連リポジトリ

- [fictional-drug-and-disease-ref-flutter](https://github.com/Corvus400/fictional-drug-and-disease-ref-flutter) — Flutter 参考実装
- [fictional-drug-and-disease-ref-mock-server](https://github.com/Corvus400/fictional-drug-and-disease-ref-mock-server) — Ktor mock-server
- [resume-flutter](https://github.com/Corvus400/resume-flutter) — ポートフォリオ履歴書

---

## ライセンス

本プロジェクトは [MIT License](./LICENSE) で公開しています。
