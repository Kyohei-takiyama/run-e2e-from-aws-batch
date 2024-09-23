# run-e2e-from-aws-batch

## How to run test in Local Env

```sh
docker compose up -d

# コンテナに入ったらTestコマンドを叩く
npm run test:docker
```

## How to run Push image to ECR

```sh
# Docker image を Mac で Build する場合は、--platform を指定する
docker build --platform linux/amd64 -t run-e2e-from-aws-batch-repository .
```

## Knowledge

- https://dev.classmethod.jp/articles/aws-batch-job-lifecycle-visual-walkthrough/
- https://dev.classmethod.jp/articles/understanding-aws-batch-iam-roles-through-illustrations/
