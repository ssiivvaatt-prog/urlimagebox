# URL Image Box

URL Image Box は、HP に掲載されている画像をもとに、トレード用の画像を作成するためのアプリです。  
画像が **同じ URL パターンで 001～999.png のように連番で登録されているサイト**でのみ動作します。

例：

```
https://card001.png
https://card002.png
https://card003.png
https://card004.png
…
https://card315.png
```

---

# 大まかな機能と操作の流れ

![シリーズ作成画面](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain001.png)

まず、右下の「新規作成」から HP を読み込む設定を作成します。  
このアプリでは、この設定を **「シリーズ」** と呼びます。

---

# シリーズ編集画面の説明

![シリーズ編集画面](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain002.png)

## シリーズ編集画面とは？

この画面では、連番画像の URL パターンを登録します。  
例：`https://sample/card001.png` ～ `https://sample/card315.png`

---

## 各項目の説明

### ■ シリーズ名
この連番画像セットにつける名前です。  
一覧表示・フィルタリング・全体表示などで識別に使います。

---

### ■ 元のURLをどう分解したか？
URL は次の3つに分解して扱います。

例：`https://sample/card001.png`

- 前半：`https://sample/card`  
- 番号：`001`  
- 後半：`.png`

この3つを組み合わせて連番 URL を自動生成します。

---

### ■ 桁数（Digit Count）
番号部分が何桁で構成されているかを指定します。

例：  
- `001` → 3桁  
- `00045` → 5桁

---

### ■ ゼロ埋め（Zero Padding）
番号を指定した桁数に合わせて、足りない部分を `0` で埋めます。

- ON → `001`, `002`, `010`  
- OFF → `1`, `2`, `10`

---

### ■ 表示カラム（Columns）
画像一覧を何列で表示するかを指定します。

- 3 → 横に3枚  
- 5 → 横に5枚

後から変更可能。画面上に何枚出すかで見やすさが変わります。

---

# シリーズ作成後の操作

![シリーズ一覧](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain003.png)

シリーズ作成後は、**編集・複製・削除** ができます。

---

## シリーズをタップすると画像一覧が表示されます

![画像一覧](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain006.png)

登録した URL パターンから取得した画像が一覧で表示されます。

---

# 画像編集モードの説明

![編集モード](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain007.png)

下部のボタンで編集モードを切り替えます。

### ● 回転モード  
画像をタップすると回転します。

### ● スタンプモード  
「求」「★」などのスタンプを付けられます。  
モードを押すたびにスタンプの種類が切り替わります。

### ● 数字モード  
「所持数」「求数」「値段」などの数字を入力できます。  
モードを押すたびに数字の種類が切り替わります。

### ● 日付モード  
画像に日付を付けられます。  
モードを押すたびに日付の種類が切り替わります。

### ● クリアモード  
画像をタップすると、上記で付けた情報を削除します。

---

## 画像共有

現在表示している画像を **1枚の画像としてまとめて出力** できます。

※画像が大きすぎる場合、環境によっては出力が不安定になることがあります。

---

# 表示文字のカスタマイズ

![カスタマイズ](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain004.png)
![カスタマイズ](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain005.png)

画面上に表示する文字（求／出／★／数字など）は自由にカスタマイズできます。  
自分の用途に合わせて変更することで、さまざまな使い方が可能です。

---

# バックアップ・リストア・キャッシュ削除

![バックアップ](https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox/refs/heads/main/sample_images/explain008.png)

右上メニューから以下の操作ができます：

- **バックアップ**：画像キャッシュ以外のデータを Google Drive に保存  
- **リストア**：Android ↔ Windows 間で相互復元可能  
- **キャッシュ削除**：画像が正しく取得できない場合に再取得するための機能

---

# 主な機能まとめ

### ● 画像の取得と管理  
### ● ソート・フィルタリング  
### ● 画像の共有  
### ● バックアップ（Drive）  
### ● カスタム文字表示  

---

# ダウンロード

Windows 版はこちら：

[Windows 版 URL Image Box v1.0.0](https://github.com/ssiivvaatt-prog/urlimagebox/releases/download/v1.0.0/urlimagebox_windows_v1.0.zip)

---

# サポート・掲示板（Issues）

不具合報告・質問・要望はこちら：

https://github.com/ssiivvaatt-prog/urlimagebox/issues

---

## 注意事項

- できる限り対応しますが、**すべてに応えられるとは限りません**  
- 個人開発かつ AI コード生成を含むため、対応が難しい場合があります  
- いただいたフィードバックは今後の改善に活かします

---

# お問い合わせ

**ssiivvaatt@gmail.com**
