## 検討した設計課題

Ktorのモックサーバーで複雑なデータ構造のFixtureを120+80=200件入れないといけないのですが、この場合どのようにするのがベストでしょうか？ scenario切り替えで返すFixtureも変えられるようになっている必要が有ります。 デフォルトは200件全てを返す必要が有ります。  データの中身が医薬品と疾患のダミーデータで、一件一件異なるデータにする必要が有るのと、マークダウン形式のStringがデータ構造にあります。 この場合どうしますか？    既存仕様が実際の医薬品と疾患のデータ構造で200件はこれに沿ってそれぞれ異なるデータを扱う必要が有ります。  この要件をRed→GreenサイクルのTDDに落とし込むことは出来ますか？ 実装が密結合で複雑なので実装担当者に頼む前だとどんな最小テスト単位になるのか見当もつきません。  別案として200件を直接全部持つのではなく、 ### (C') 分類軸別追加フィールド発火 ### (F) 分布設計 に応じたRepository,Genaratorパターンを提唱していました。
実装担当者が参照できるように、設計方針・ディレクトリ構成・TDD 分解・実装順序を整理する。

## 定義

この要件での最適解は、**200件の完成形JSONを直接管理すること**ではなく、次の4層に分けることです。

1. **CoverageSpec**
   何を網羅するために何件必要かを定義する層です。
   既存プランでも、医薬品 120 件・疾患 80 件は「分類軸」「UI ブロック発火条件」「条件付き必須項目」のカバレッジを満たすための件数として導かれています。

2. **Blueprint / Template**
   1件ごとの「骨格」を表す層です。
   例: `ATC J群 / 注射剤 / 劇薬 / 警告あり / PK必須` のような、分類軸と条件必須フィールドの組だけを持ちます。
   医薬品側は ATC 14 群・投与経路 8・規制区分 11・剤形 13 などの分類軸があり、疾患側は ICD-10 22章・診療科 16・慢性度 4・感染性 boolean などがあるため、最初に Blueprint を分けないと Fixture がすぐ破綻します。

3. **Generator**
   Blueprint から実際のダミーデータを埋める層です。
   マークダウン本文、ダミー医薬品名、ダミー疾患名、年齢帯、頻度帯、検査値などを**固定シード**で生成します。
   共通プランでも「自由記述が本質の段落のみ String/Markdown に残し、それ以外は値オブジェクト化する」方針になっているので、Generator は自由文字列を乱雑に作るのではなく、構造化済みフィールドに対して埋める役割に限定すべきです。

4. **ScenarioRepository**
   `default` では200件全部返し、`scenario=...` で subset や差し替えを返す層です。
   共通プランにも「Fixture 作成ルール」「サーバ側検証」「クライアント側はUI表示条件で吸収」という運用が定義されているため、最終的に Ktor route から見る依存先は `ScenarioRepository` だけにするのが最も扱いやすいです。

---

## 要点

結論から言うと、**Repository + Generator パターンが正しいです**。
ただし、別セッションで出ていた案をそのまま採用するのではなく、次の形に絞るのがよいです。

### 採用すべき構成

* **直接200件を hand-written JSON で持たない**
* **200件をその場で毎回ランダム生成しない**
* **Blueprint を定義して、固定 seed で deterministic に生成する**
* **生成後に validation をかけて fixture を凍結する**
* **scenario は「完成済み fixture の選択」と「差し替えルール」に限定する**

この形にすると、以下が同時に満たせます。

* 200件が全部異なる
* scenario 切り替え可能
* デフォルトは全200件
* Markdown 文字列を含められる
* TDD の最小単位を細かく切れる
* 実装担当者 に「どこから実装するか」を明確に渡せる

### 避けるべき構成

#### 1. 200件を全部ベタ書き

初期は速そうに見えますが、分類軸の修正や schema 変更が入った瞬間に全件の保守コストが爆発します。
今回の設計は医薬品側だけでも `warning`, `contraindications`, `indications`, `dosage`, `precautionsForSpecificPopulations`, `interactions`, `adverseReactions`, `pharmacokinetics` など入れ子が深く、疾患側も `epidemiology`, `symptoms`, `diagnosticCriteria`, `severityGrading`, `treatments` を持つため、手修正前提は危険です。

#### 2. 完全ランダム生成

再現性がなく、TDD と相性が悪いです。
特に今回のように「注射剤なら PK 必須」「感染性なら prevention 必須」などの軟制約が多いケースでは、ランダム生成は failure cause の切り分けを難しくします。

---

## 比較

### A. 200件ベタ持ち

**利点**

* 目視で分かりやすい
* 初期の route 接続だけなら速い

**欠点**

* 仕様変更に極端に弱い
* scenario ごとの差分管理がつらい
* TDD の単位が「巨大 JSON 比較」になりがち
* 実装担当者 が大規模変更時に壊しやすい

### B. Generator のみ

**利点**

* 拡張しやすい
* 件数増減に強い

**欠点**

* カバレッジ保証が曖昧になりやすい
* scenario が曖昧になりやすい
* 何を網羅しているか読みづらい

### C. CoverageSpec + Blueprint + Generator + ScenarioRepository

**利点**

* カバレッジを先に固定できる
* 生成が deterministic
* scenario が宣言的になる
* TDD を最小単位で回せる
* 実装担当者 に作業順を明示しやすい

**欠点**

* 初期設計は少し重い

今回の要件では **C 一択** です。
特に既存プラン自体が「120件/80件の分布設計」と「分類軸別追加フィールド発火」を前提にしているため、CoverageSpec を明示しない構成は設計意図とずれます。

---

## 具体例

以下をそのまま 実装担当者 に渡せるように、**設計方針・ディレクトリ構成・TDD分解・実装順序**まで落とします。

---

# 実装担当者 向け設計指示

## 目的

Ktor モックサーバーにおいて、医薬品 120 件 + 疾患 80 件の計 200 件の fixture を、以下の要件で管理する。

* デフォルト scenario は全 200 件を返す
* scenario 切り替えで subset / override が可能
* 各レコードは互いに異なる
* Markdown 文字列を含む複雑な入れ子構造を扱う
* 生成結果は deterministic である
* fixture の条件必須項目を validation で検証する
* route 層からは scenario repository だけを参照する

設計根拠:

* 医薬品推奨件数は 120 件、疾患推奨件数は 80 件である。
* 軟制約は Kotlin 型だけでは表現できないため、fixture 作成ルール + サーバ側検証が必要である。
* 自由記述 String は段落型に限定し、それ以外は値オブジェクト化する。

---

## 採用アーキテクチャ

### 1. CoverageSpec

fixture 全体で満たすべきカバレッジ条件を定義する。

#### DrugCoverageSpec

* ATC 第1階層 14 群を全て1件以上含む
* routeOfAdministration 8 値を全て1件以上含む
* regulatoryClass の主要値を全て1件以上含む
* dosageForm の主要値を全て1件以上含む
* 条件必須:

  * 毒薬・劇薬・生物由来製品 → `warning` 非空
  * 外用・注射・吸入・貼付 → `administrationPrecautions` 非空
  * 注射剤 → `pharmacokinetics` 非 null
  * 向精神薬・麻薬 → `insuranceNotes` 非空
  * 生物由来製品 → `handlingPrecautions` 非空
  * 慢性疾患長期服用薬 → `dosageRelatedPrecautions` 非空

#### DiseaseCoverageSpec

* ICD-10 22 章を全て1件以上含む
* medicalDepartment 16 値を全て1件以上含む
* chronicity 4 値を全て1件以上含む
* infectious true/false を両方含む
* 条件必須:

  * 感染性 → `prevention` 非空
  * 内分泌代謝 → `requiredExams` 非空, `treatments.pharmacological` 非空
  * 循環器 → `severityGrading` 非 null
  * 新生物 → `severityGrading` 非 null, `prognosis` 非 null
  * 精神 → `diagnosticCriteria.required` を持つ, `relatedDrugIds` 参照あり

### 2. Blueprint

1レコードの分類軸と発火条件だけを定義する中間表現。

```kotlin
data class DrugBlueprint(
    val id: String,
    val atcGroup: AtcGroup,
    val route: RouteOfAdministration,
    val dosageForm: DosageForm,
    val regulatoryClasses: List<RegulatoryClass>,
    val requiresWarning: Boolean,
    val requiresPk: Boolean,
    val requiresAdministrationPrecautions: Boolean,
    val requiresInsuranceNotes: Boolean,
    val requiresHandlingPrecautions: Boolean,
    val requiresDosageRelatedPrecautions: Boolean,
    val scenarioTags: Set<String>,
)

data class DiseaseBlueprint(
    val id: String,
    val icd10Chapter: Icd10Chapter,
    val departments: List<MedicalDepartment>,
    val chronicity: Chronicity,
    val infectious: Boolean,
    val requiresPrevention: Boolean,
    val requiresSeverityGrading: Boolean,
    val requiresPrognosis: Boolean,
    val requiresRequiredExams: Boolean,
    val requiresPharmacologicalTreatment: Boolean,
    val scenarioTags: Set<String>,
)
```

### 3. Generator

`Blueprint -> Domain Model` へ変換する。

* `DrugTextGenerator`
* `DiseaseTextGenerator`
* `MarkdownBlockFactory`
* `NameGenerator`
* `ValueRangeGenerator`

ここでは乱数を使うとしても `Random(seed)` 固定にする。
`id` から seed を導出してもよい。

### 4. Validator

生成後に条件必須を検証する。

```kotlin
interface FixtureValidator<T> {
    fun validate(item: T): List<String>
}
```

* `DrugFixtureValidator`
* `DiseaseFixtureValidator`
* `CrossReferenceValidator`

  * `relatedDiseaseIds`
  * `relatedDrugIds`
  * interaction の参照
  * dangling reference 禁止

### 5. ScenarioRepository

完成済み fixture を scenario ごとに束ねる。

```kotlin
interface ScenarioRepository {
    fun allDrugs(scenario: Scenario = Scenario.Default): List<Drug>
    fun allDiseases(scenario: Scenario = Scenario.Default): List<Disease>
}
```

`Scenario.Default` は 200 件全件。
`Scenario.InjectionHeavy`, `Scenario.Psychiatry`, `Scenario.InfectiousOnly`, `Scenario.MinimalSmoke` などを追加可能。

---

## ディレクトリ構成案

```text
src/main/kotlin/.../fixture/
  coverage/
    DrugCoverageSpec.kt
    DiseaseCoverageSpec.kt
    FixtureDistributionPlan.kt

  blueprint/
    DrugBlueprint.kt
    DiseaseBlueprint.kt
    DrugBlueprintFactory.kt
    DiseaseBlueprintFactory.kt

  generator/
    name/
      DrugNameGenerator.kt
      DiseaseNameGenerator.kt
    markdown/
      MarkdownBlockFactory.kt
    drug/
      DrugGenerator.kt
      DrugFieldGenerator.kt
    disease/
      DiseaseGenerator.kt
      DiseaseFieldGenerator.kt

  validation/
    DrugFixtureValidator.kt
    DiseaseFixtureValidator.kt
    CrossReferenceValidator.kt
    ValidationException.kt

  scenario/
    Scenario.kt
    ScenarioFilter.kt
    DefaultScenarioRepository.kt

  seed/
    SeedPolicy.kt

  catalog/
    GeneratedDrugCatalog.kt
    GeneratedDiseaseCatalog.kt
```

---

## 実装方針

### 1. fixture は起動時に1回だけ生成

リクエストごとに生成しない。
アプリ起動時または test bootstrap 時に生成してメモリに保持する。

理由:

* deterministic を保ちやすい
* route test が安定する
* scenario 切り替えがフィルタだけで済む

### 2. scenario は「生成ロジック切替」ではなく「完成物の選別」

ここが重要です。
scenario ごとに別 Generator を持つと複雑化します。

正しくは:

* まず全 120 drug / 80 disease を生成
* その後 scenario で filter / sort / override

例:

* `Default`: 200 件全部
* `InfectiousOnly`: `disease.infectious == true` とその関連 drug
* `Psychiatry`: ICD-10 V章 + N群 + 向精神薬
* `MinimalSmoke`: 各大分類最低1件ずつだけ返す

### 3. Markdown はテンプレート化

本文を毎回文字列連結で作らない。

```kotlin
interface MarkdownTemplate<TContext> {
    fun render(context: TContext): String
}
```

例:

* `DrugWarningTemplate`
* `DrugDosageTemplate`
* `DiseaseSummaryTemplate`
* `DiseaseEtiologyTemplate`

こうすると、医薬品名・年齢帯・検査値だけ差し替えて量産できます。

### 4. 直接 JSON ファイルを source of truth にしない

source of truth は Kotlin 側の Blueprint + Generator に置く。
必要ならデバッグ用に generated JSON を吐き出す。

---

## Red → Green の最小テスト単位

この要件は、最初から route integration test で入ると大きすぎます。
最小単位は次の順です。

### Phase 1: Blueprint 単位

#### Red

* 120件の drug blueprint が作られること
* 80件の disease blueprint が作られること
* ATC 14群が揃うこと
* ICD-10 22章が揃うこと

#### Green

* `DrugBlueprintFactory`
* `DiseaseBlueprintFactory`

#### テスト例

```kotlin
@Test
fun `drug blueprint factory covers all ATC groups`() { ... }

@Test
fun `disease blueprint factory covers all ICD10 chapters`() { ... }
```

この段階ではまだ Markdown も本文生成もしません。

---

### Phase 2: 条件必須ルール単位

#### Red

* 注射剤 blueprint から生成された drug は `pharmacokinetics != null`
* 生物由来製品は `warning` と `handlingPrecautions` が非空
* 感染性 disease は `prevention` 非空
* 新生物 disease は `severityGrading` と `prognosis` を持つ

#### Green

* `DrugGenerator`
* `DiseaseGenerator`
* `DrugFixtureValidator`
* `DiseaseFixtureValidator`

#### テスト例

```kotlin
@Test
fun `injection drugs must have pharmacokinetics`() { ... }

@Test
fun `infectious diseases must have prevention`() { ... }
```

---

### Phase 3: Markdown 生成単位

#### Red

* `summary` が空でない
* `dosage.standardDosage` が Markdown を含められる
* 禁止した Markdown 記法を含まない
* 見出しレベルや表現ルールに従う

共通基盤では Markdown の扱いと許容方言が定義されています。

#### Green

* `MarkdownBlockFactory`
* 個別 Template 実装

#### テスト例

```kotlin
@Test
fun `disease summary markdown is deterministic`() { ... }

@Test
fun `drug dosage markdown does not use h1 heading`() { ... }
```

---

### Phase 4: 参照整合性単位

#### Red

* `relatedDrugIds` が存在する drug を指す
* `relatedDiseaseIds` が存在する disease を指す
* interaction の `drugId` が dangling しない

#### Green

* `CrossReferenceValidator`

#### テスト例

```kotlin
@Test
fun `all related drug ids must exist in catalog`() { ... }
```

---

### Phase 5: Scenario 単位

#### Red

* `Default` で drug 120 / disease 80 が返る
* `Psychiatry` で向精神薬系のみ返る
* `MinimalSmoke` で小さいが必要分類を落とさない

#### Green

* `DefaultScenarioRepository`
* `ScenarioFilter`

#### テスト例

```kotlin
@Test
fun `default scenario returns full catalog`() { ... }

@Test
fun `minimal smoke scenario keeps at least one item per critical axis`() { ... }
```

---

### Phase 6: Route 単位

最後にだけ Ktor の route test に入ります。

#### Red

* `/drugs` が default scenario で 120 件返す
* `/diseases` が default scenario で 80 件返す
* scenario query で subset が返る

#### Green

* routes と repository 接続

---

## 実装担当者 に渡す実装順序

以下の順で固定してください。

1. `BlueprintFactory` だけ実装
2. `CoverageSpec` テストを通す
3. `DrugGenerator` / `DiseaseGenerator` 実装
4. `FixtureValidator` 実装
5. `CrossReferenceValidator` 実装
6. `ScenarioRepository` 実装
7. 最後に Ktor route 接続

**最初から route を触らせない**のが重要です。
密結合な既存実装に 実装担当者 を最初から入れると、fixture 問題と route 問題が混ざって壊れやすいからです。

---

## 最初の最小TDDチケット

実装担当者 に最初にやらせるべき最小単位はこれです。

### チケット1

* `DrugBlueprintFactory` を作る
* 120件生成する
* ATC 14群が揃うことをテストする
* route にはまだつながない

### チケット2

* `DiseaseBlueprintFactory` を作る
* 80件生成する
* ICD-10 22章が揃うことをテストする
* route にはまだつながない

### チケット3

* `DrugGenerator` を作る
* 注射剤で `pharmacokinetics` が必須になることをテストする

### チケット4

* `DiseaseGenerator` を作る
* 感染性疾患で `prevention` が必須になることをテストする

この4チケットまでは、既存Ktor 実装に触れずに進められます。
これが最小の Red → Green 単位です。

---

## 実装担当者 へ渡す指示文

```markdown
目的:
Ktor mock server 用の fixture 基盤を作る。医薬品 120 件、疾患 80 件、合計 200 件を deterministic に生成し、default scenario では全件返し、scenario 切り替えで subset を返せるようにする。

制約:
- 200件を hand-written JSON で直接管理しない
- Blueprint -> Generator -> Validator -> ScenarioRepository の4層で分離する
- route 接続は最後に行う
- まずは BlueprintFactory とそのテストから着手する
- 既存 route や serializer への影響は最小化する
- Markdown を含む自由記述は template 化して deterministic に生成する
- 条件必須項目は validator で検証する
- dangling reference を禁止する

今回最初にやること:
1. DrugBlueprintFactory を実装
2. 120件生成する
3. 全 ATC 第1階層 14群が最低1件含まれるテストを追加
4. 注射剤・外用・向精神薬・生物由来製品などの条件タグを Blueprint に保持できるようにする
5. route はまだ触らない

期待する成果:
- コンパイルが通る
- BlueprintFactory の unit test が通る
- 生成件数と分類軸カバレッジがテストで担保される
```

---

## 最終結論

この要件は、**「巨大 fixture をどう置くか」の問題ではなく、「分類軸カバレッジをどう deterministic に管理するか」の問題**です。

したがって採るべき設計は、

* **CoverageSpec**
* **BlueprintFactory**
* **Generator**
* **Validator**
* **ScenarioRepository**

の5段構成です。

そして TDD の最小単位は、
**1レコード完成**ではなく
**1つの分類軸カバレッジまたは1つの条件必須ルール**
に置くのが正解です。

既存添付の設計プラン自体も、件数 120/80 を「分布設計」「UI 発火条件」「条件付き必須項目」から導いており、単純な固定 JSON 羅列よりこの設計の方が整合します。
