# Next.js 設計ガイドライン

本ドキュメントは、Next.js (App Router) における設計ルール、Server/Client の境界管理、Server Actions の規約、およびハイドレーション最適化について定義する。

---

## 1. Server / Client の境界管理

サーバー専用処理がクライアント側に漏洩するのを防ぎ、データフローとコンポーネントの役割を明確にする。

### 1.1 `server-only` パッケージの導入

サーバー専用のモジュール（DB接続、認証用シークレットアクセス、Repository層など）のファイル先頭には必ず `import 'server-only'` を記述する。  
万が一クライアントコンポーネントから誤ってインポートされた場合、ビルド時に検知してエラーを発生させる。

#### コード例: Repository層

```typescript
// src/features/user/repositories/user-repository.ts
import 'server-only';
import { db } from '@/lib/db';

export async function getUserById(id: string) {
  return await db.user.findUnique({
    where: { id },
  });
}
```

### 1.2 ディレクトリ構造による分離

ビジネスロジックやデータ取得層（`features/`, `repositories/` など）と、UIコンポーネント（`components/`）を明確に分離する。

#### 推奨ディレクトリ構造例

```text
src/
├── app/                        # App Routerルーティング（ルーティング定義のみ）
│   ├── (authenticated)/        # 認証済み領域（要ログイン）
│   │   └── dashboard/
│   │       └── page.tsx
│   └── (guest)/                # ゲスト領域（非認証）
│       └── login/
│           └── page.tsx
├── components/                 # 汎用UIコンポーネント (Button, Modalなど)
│   └── ui/
├── features/                   # 機能ドメイン単位の集約
│   └── user/
│       ├── actions/            # CRUD単位のServer Actionsファイル(認可/フォーマットバリデーション含)
│       │   └── update-profile.ts
│       ├── components/         # ドメイン固有コンポーネント
│       │   ├── user-profile-card.tsx
│       │   └── profile-edit-form.tsx
│       ├── usecases/           # ユースケース(ビジネスロジック・ドメインバリデーション)
│       │   └── update-user.ts
│       ├── repositories/       # データ取得層 ('server-only')
│       │   └── user.ts
│       └── types/              # ドメイン型定義
└── lib/                        # 共通ライブラリ・設定
```

---

## 2. Server Actions の配置と役割の定義

`page.tsx` への処理の分散や巨大なインライン処理を防ぎ、保守性・可読性・テスト容易性を高める。

### 2.1 データフローと役割分担

Server Action は **HTTPコントローラー（単なるエントリーポイント）**、および認証認可・バリデーションポイントとして機能させる。  
DB操作やドメインロジックは記述せず、Usecase層に移譲する。

```text
[UI (Client Component)]
        │
        ▼ (Form送信 / Action呼び出し)
[Server Action (features/*/actions/*.ts)]  <-- エントリーポイント (認証確認・Zod検証)
        │
        ▼ (ドメイン処理の実行)
[UseCase / Service (features/*/usecases/*.ts)] <-- ビジネスロジック
        │
        ▼ (DB操作)
[Repository (features/*/repositories/*.ts)]    <-- 'server-only' DBアクセス
```

### 2.2 規約・ルール

1. **インライン `'use server'`（関数内での宣言）の禁止**  
   `page.tsx` や UI コンポーネント内の関数の中に直接 `'use server'` を埋め込んで定義することを禁止する。  
   Server Action を作成する際は、必ずファイルの先頭（1行目）に `'use server'` を宣言した独立した専用ファイル（`features/<ドメイン>/actions/*.ts`）を作成し、コンポーネントからはそれを `import` して呼び出すこと。
2. **ビジネスロジックの分離**  
   Server Action 内で直接 DB 操作（Prismaなど）や複雑な判定を行わず、UseCase / Service 層に委譲する。
3. **Zod による入力バリデーションの必須化**  
   クライアントから渡される入力データ（`FormData` やオブジェクト）は、必ず Zod 等で検証した上で処理を続行する。

---

### 2.3 コード具体例 (Bad / Good パターン)

#### ❌ Bad: `page.tsx` へのインライン直書き & DB直接アクセス

```tsx
// ❌ Bad: src/app/profile/page.tsx
import { db } from '@/lib/db';

export default function ProfilePage() {
  // ❌ page.tsx 内に 'use server' を直書きし、DB操作も直接記述している
  async function updateProfile(formData: FormData) {
    'use server';
    const nickname = formData.get('nickname') as string;
    
    // バリデーションがなく、DB操作も直接行われている
    await db.user.update({
      where: { id: 'user-1' },
      data: { nickname },
    });
  }

  return (
    <form action={updateProfile}>
      <input name="nickname" />
      <button type="submit">更新</button>
    </form>
  );
}
```

#### ⭕ Good: 各レイヤーに分離された実装例

##### ① Server Action (エントリーポイント & バリデーション)
```typescript
// ⭕ Good: src/features/user/actions/update-profile.ts
'use server';

import { z } from 'zod';
import { updateUserProfileUseCase } from '../usecases/update-user-profile-usecase';

const updateProfileSchema = z.object({
  userId: z.string().min(1, 'ユーザーIDは必須です'),
  nickname: z.string().min(2, 'ニックネームは2文字以上で入力してください').max(50),
});

export type ActionResult = {
  success: boolean;
  errors?: { [key: string]: string[] };
};

export async function updateProfileAction(
  prevState: ActionResult | null,
  formData: FormData
): Promise<ActionResult> {
  // 1. バリデーション実行
  const parsed = updateProfileSchema.safeParse({
    userId: formData.get('userId'),
    nickname: formData.get('nickname'),
  });

  if (!parsed.success) {
    return {
      success: false,
      errors: parsed.error.flatten().fieldErrors,
    };
  }

  try {
    // 2. UseCase (ビジネスロジック) へ処理を委譲
    await updateUserProfileUseCase(parsed.data);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      errors: { _form: ['プロフィールの更新に失敗しました'] },
    };
  }
}
```

##### ② Client Component (UI側からの利用)
```tsx
// ⭕ Good: src/features/user/components/profile-edit-form.tsx
'use client';

import { useActionState } from 'react';
import { updateProfileAction } from '../actions/update-profile';

interface ProfileEditFormProps {
  userId: string;
  initialNickname: string;
}

export function ProfileEditForm({ userId, initialNickname }: ProfileEditFormProps) {
  const [state, formAction, isPending] = useActionState(updateProfileAction, null);

  return (
    <form action={formAction} className="space-y-4">
      <input type="hidden" name="userId" value={userId} />
      
      <div>
        <label htmlFor="nickname">ニックネーム</label>
        <input
          id="nickname"
          name="nickname"
          defaultValue={initialNickname}
          disabled={isPending}
        />
        {state?.errors?.nickname && (
          <p className="text-red-500 text-sm">{state.errors.nickname[0]}</p>
        )}
      </div>

      {state?.errors?._form && (
        <p className="text-red-500 text-sm">{state.errors._form[0]}</p>
      )}

      <button type="submit" disabled={isPending}>
        {isPending ? '更新中...' : '更新'}
      </button>
    </form>
  );
}
```

---

## 3. `"use client"`（クライアント境界）の最適化

不要なクライアントバンドルの増加、レンダリングコストの上昇、およびハイドレーションエラーを予防する。

### 3.1 末端コンポーネントへの付与原則

`"use client"` ディレクティブは**最下層（末端コンポーネント）**に付与する。  
`page.tsx` や `layout.tsx` などの上位階層には絶対につけてはいけない。  
インタラクティブな操作（`onClick`, `onChange`, `useState`, `useEffect` 等）が必要な最小単位のパーツ（ボタン、フォーム要素、モーダル等）のみを Client Component 化する。

### 3.2 コンポーネントの挿入 (Children Injection) の活用

クライアント状態（アコーディオンの開閉、テーマ切替など）を持つ親コンポーネントであっても、子要素が Server Component で済む場合は `children` プロップス等を経由して受け渡す構造を徹底する。

#### コード例: Children Injection パターン

##### ❌ Bad: 親が "use client" のため子要素まで Client Component 化される

```tsx
// ❌ Bad: コンポーネント全体がクライアント側で実行される
'use client';

import { HeavyServerComponent } from './heavy-server-component';

export function SidebarLayout() {
  const [isOpen, setIsOpen] = useState(true);

  return (
    <aside>
      <button onClick={() => setIsOpen(!isOpen)}>Toggle</button>
      {isOpen && <HeavyServerComponent />} {/* サーバー専用コンポーネントが巻き込まれる */}
    </aside>
  );
}
```

##### ⭕ Good: Children Injection で Server Component を保持

```tsx
// ⭕ Good Component: クライアント状態を持つラッパー (Client Component)
// src/components/ui/collapsible-sidebar.tsx
'use client';

import { useState, ReactNode } from 'react';

interface CollapsibleSidebarProps {
  children: ReactNode; // Server Componentをそのまま受け取る
}

export function CollapsibleSidebar({ children }: CollapsibleSidebarProps) {
  const [isOpen, setIsOpen] = useState(true);

  return (
    <aside>
      <button onClick={() => setIsOpen(!isOpen)}>Toggle</button>
      {isOpen && children}
    </aside>
  );
}
```

```tsx
// ⭕ Good Usage: page.tsx (Server Component) から注入
// src/app/(authenticated)/dashboard/page.tsx
import { CollapsibleSidebar } from '@/components/ui/collapsible-sidebar';
import { HeavyServerComponent } from '@/features/dashboard/components/heavy-server-component';

export default function DashboardPage() {
  return (
    <CollapsibleSidebar>
      {/* サーバー側でレンダリングされた状態で注入される */}
      <HeavyServerComponent />
    </CollapsibleSidebar>
  );
}
```

---

## 4. 認証・認可の二重ガード規約

ミドルウェア（`middleware.ts`）と Server Actions 内の認可は、同じ「認可・ガード」であっても守る対象と目的（レイヤー）が全く異なる。両方を組み合わせた「多層防御（二重セキュリティ）」によって初めて安全なアプリケーションが実現する。

### 4.1 役割分担の原則

| 項目 | ミドルウェア (`middleware.ts`) | Server Action 内の認可 |
| :--- | :--- | :--- |
| **守る対象** | **画面（URL / ページ）** | **処理・データ（Mutation）** |
| **実行タイミング** | HTTPリクエストがページに届く前 | Server Action が実行される瞬間 |
| **主な役割** | 未ログインユーザーを `/login` に弾く | 他人のデータを勝手に書き換えさせない |
| **チェックの粗さ** | **粗い（Pathベース）**<br>例: `/dashboard/*` は全員ログイン必須 | **細かい（コンテキストベース）**<br>例: この `postId` はログイン中のユーザーのものか |

> [!CAUTION]
> **ミドルウェア内での DB アクセス禁止**  
> ミドルウェアはすべてのリクエストの最前線で実行されるため、ミドルウェア内で直接 DB 検索を行うと全体のパフォーマンスが著しく低下します。ミドルウェアでは Cookie/トークンの存在確認などの**軽量なチェック**にとどめ、DB アクセスを伴う詳細な権限検証は Server Action または Data Access Layer で行います。

---

### 4.2 併用する具体的な設計パターン

#### 1. ミドルウェア（入口の門番）
未ログインのユーザーが保護されたページへ直接アクセスした場合、画面が描画される前に即座にログイン画面へリダイレクトする。

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('session_token');

  // 未ログインで認証必須ページにアクセスしたらログインへ飛ばす（Pathベースの粗いチェック）
  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
}
```

#### 2. Server Action（金庫の鍵）
ミドルウェアを通過した（＝ログイン済みの）ユーザーであっても、「自分以外のデータを操作しようとしていないか」「本当にその操作を行う権限（管理者権限など）があるか」を個別の Action 内で厳密に検証する。

```typescript
// src/features/post/actions/delete-post.ts
'use server';

import { getServerSession } from '@/lib/auth';
import { db } from '@/lib/db';

export async function deletePostAction(postId: string) {
  // ① 認証チェック（セッション確認）
  const session = await getServerSession();
  if (!session?.user) {
    return { error: '未ログインです' };
  }

  // ② 認可チェック（所有権確認）
  const post = await db.post.findUnique({ where: { id: postId } });
  if (post?.authorId !== session.user.id) {
    return { error: '他人の投稿は削除できません' }; // <-- ミドルウェアでは判断できない領域
  }

  // 削除処理の実行...
  await db.post.delete({ where: { id: postId } });

  return { success: true };
}
```

---

### 4.3 片方のみの場合のリスク

* **ミドルウェア「だけ」の場合:**  
  Server Action は外部から直接呼び出せる POST エンドポイントであるため、悪意のあるユーザーが DevTools 等から直接 Server Action のリクエストを送信した場合、ミドルウェアのパスチェックをすり抜けて他人のデータを更新・削除されてしまう重大な脆弱性（IDOR）が発生する。
* **Server Action「だけ」の場合:**  
  未ログインユーザーが保護されたページを開いた際、画面が表示されてから「データ取得失敗」のエラーが出ることになり、UX（ユーザー体験）が著しく低下する。

#### 結論
* **ミドルウェア**: 「ログインしていないなら、そもそも画面を見せない（リダイレクト）」
* **Server Action 内**: 「ログインしていても、他人のデータは触らせない（エラーレスポンス）」

