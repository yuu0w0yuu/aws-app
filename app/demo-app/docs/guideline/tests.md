# テスト作成方針（Testing Guidelines）

本ドキュメントは、プロジェクトにおけるテストの設計・実装・運用方針をまとめたものである。
「最小限の保守コストで最大限の価値を生み、プロダクトの持続可能な成長を支えること」を目的とする。

---

## 1. テスト設計の基本原則

### 1.1 テスト種別と責務

| 種別 | 検証対象 | 実行速度 | プロセス外依存 | テストの役割・特徴 |
| --- | --- | --- | --- | --- |
| **単体テスト** *(主軸)* | ドメインモデル<br>

<br>ビジネスロジック | 超高速 | すべてモック化 | **異常系・境界値を網羅。** 1つの「ふるまい」を検証する |
| **統合テスト** | コントローラー<br>

<br>層間の連携 | 中速 | 自チーム管理下のDB等は本物を使用 | **正常系（ハッピーパス）を中心に検証。** プロセス外依存との連携を確認 |
| **E2Eテスト** | システム全体 | 低速 | 外部サービス含むすべて接続 | **最重要シナリオのみ。** 外部結合も含めた疎通・挙動を確認 |

> **指針:** 保守コストの低い「単体テスト」を最も多く作成し、実行時間が長く壊れやすい「E2Eテスト」は最小限に抑える。

### 1.2 古典学派アプローチの採用

当プロジェクトでは「古典学派（デトロイト学派）」を採用する。

* **テスト単位:** クラス単位ではなく「1つのふるまい」単位でテストを作成する。
* **依存の扱い:** 状態を持たないオブジェクトはモックにせず実物（本物）を組み合わせて使用する。
* **検証内容:** 内部の呼び出しログではなく、最終的な「状態（出力結果・データ）」を検証する。
* **メリット:** 実装の詳細（内部構造）にテストが縛られないため、**リファクタリング時にもテストが壊れにくくなる（偽陽性の防止）。**

---

## 2. コーディングルール & アンチパターン

### 2.1 構造化：AAA (Arrange-Act-Assert) パターン

テストコードは「準備 (Arrange)」「実行 (Act)」「検証 (Assert)」の3フェーズに分けて記述する。

```typescript
it('在庫が足りる場合、購入に成功すること', () => {
  // 1. Arrange（準備）
  const store = createStoreWithInventory(Product.Shampoo, 10);
  const customer = new Customer();

  // 2. Act（実行：原則1行で記述）
  const success = customer.purchase(store, Product.Shampoo, 5);

  // 3. Assert（検証）
  expect(success).toBe(true);
  expect(store.getInventory(Product.Shampoo)).toBe(5);
});

```

### 2.2 フィクスチャ管理：`beforeEach` の禁止とファクトリ関数の利用

`beforeEach` での共通データ構築は、テストケース間の結合度を高め、前提条件を不透明にするため**原則禁止**とする。各テスト内でヘルパー（ファクトリ）関数を明示的に呼び出すこと。

```typescript
// 〇 推奨: 引数で前提条件（在庫数）を調整できるヘルパー関数
const createStoreWithInventory = (product: Product, quantity: number): Store => {
  const store = new Store();
  store.addInventory(product, quantity);
  return store;
};

```

### 2.3 パラメータ化テスト（`it.each`）の活用

同一のふるまいで入力値・期待値のみが異なる場合は、ループ処理や制御文（`if`）を書かず、テーブル駆動テストでまとめる。

```typescript
const testTable = [
  { inventory: 10, order: 5,  expected: true,  caseName: '在庫が足りるなら成功' },
  { inventory: 10, order: 15, expected: false, caseName: '在庫不足なら失敗' },
  { inventory: 0,  order: 5,  expected: false, caseName: '在庫ゼロなら失敗' },
];

it.each(testTable)('$caseName', ({ inventory, order, expected }) => {
  const store = createStoreWithInventory(Product.Shampoo, inventory);
  const customer = new Customer();
  
  const success = customer.purchase(store, Product.Shampoo, order);
  expect(success).toBe(expected);
});

```

### 2.4 禁止事項（アンチパターン）

* ❌ **1つのテストで複数のふるまいを検証する**（テストケースを分割すること）
* ❌ **テストコード内に `if` 文や `for` 文などの制御構文を書く**
* ❌ **`Act` フェーズが複数行に及ぶ**（テスト対象の設計自体に問題があるサインである）
* ❌ **単体テスト内でデータの後始末（TearDown）が発生している**（外部依存をモックできていない）

---

## 3. モック（Mock）とスタブ（Stub）の運用指針

### 3.1 モックとスタブの明瞭な使い分け

* **モック (Mock) ＝ コマンド（副作用のある操作）を検証:** 外部への書き込み・メール送信など。呼び出し回数や引数を検証する。
* **スタブ (Stub) ＝ クエリ（入力データの提供）を模倣:** DBからの参照など。**スタブの呼び出し自体を Assert（検証）してはならない。**

### 3.2 モックの適用範囲

* **〇 モック対象:** システム境界に位置する非管理下依存（外部API、メール配信サービスなど）
* **❌ モック不可:** 自チームで管理しているDB（統合テストでは本物を使用）、システム内部のクラス同士の通信

> **サードパーティライブラリのモック化:** ライブラリを直接モック化せず、自作のアダプター（腐敗防止層）でラップした上で、そのアダプターをモック化すること。

---

## 4. テストとアーキテクチャ方針

最もテストがしやすくリファクタリング耐性の高い「出力値ベーステスト（入力データを渡し、戻り値だけを検証する純粋関数のテスト）」を増やすため、**Functional Core / Mutable Shell** パターンを意識した設計を行う。

* **Functional Core（ドメイン層）:** 副作用を持たず、計算や決定のみを行う純粋関数。**単体テストで検証する。**
* **Mutable Shell（アプリ層・コントローラー）:** DB操作や通知などの副作用と入力収集を担う。**統合テストで検証する。**

```typescript
export class UserService {
  private userRepo = new UserRepository();

  async handleUpgrade(userId: string): Promise<void> {
    // 1. [Mutable Shell] DBからデータを取得
    const user = await this.userRepo.findById(userId);

    // 2. [Functional Core] ビジネスロジックの決定（純粋関数）
    const upgradedUser = upgradeUserPlan(user);

    // 3. [Mutable Shell] 決定に基づき副作用を実行
    await this.userRepo.save(upgradedUser);
  }
}

```

---

## 5. カバレッジ指標の扱い方

* **カバレッジ目標値（KPI）を設定しない:** 数値を目的化すると「検証のないテスト」が増え、品質の向上につながらない。
* **未テスト領域の確認に使う:** カバレッジが低い（例: 60%未満）場合はテスト不足を疑う判断材料とする。ただし、100%であってもテストの質は保証されない点に注意する。
* **不要なテストは削除・修正する:** 実装変更に伴って不要になったテストや、運用コストに対して効果が薄いテストはメンテナンスの過程で削除または修正を行う。