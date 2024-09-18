# Dockerfile

# ベースイメージを指定（Playwright公式イメージ）
FROM mcr.microsoft.com/playwright:v1.47.0-focal

# 作業ディレクトリを設定
WORKDIR /app

# パッケージファイルをコピー
COPY package*.json ./

# 依存関係をインストール（devDependenciesも含む）
RUN npm install

# Playwrightのブラウザをインストール
RUN npx playwright install --with-deps

# アプリケーションのソースコードをコピー
COPY . .

# TypeScriptのビルド（必要に応じて）
# RUN npm run build

# デフォルトのコマンドを設定（テストとアップロードを実行）
CMD ["npm", "run", "test-and-upload"]
