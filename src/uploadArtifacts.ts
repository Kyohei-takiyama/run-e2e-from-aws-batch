// src/uploadArtifacts.ts

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import fs from "fs";
import path from "path";
import util from "util";

// 非同期ファイルシステム操作のラッパー
const readdir = util.promisify(fs.readdir);
const stat = util.promisify(fs.stat);
const readFile = util.promisify(fs.readFile);

// AWSリージョンを環境変数から取得、デフォルトはus-west-2
const REGION = process.env.AWS_REGION || "us-west-2";

// S3クライアントの初期化
const s3 = new S3Client({ region: REGION });

/**
 * ファイルをS3にアップロードする関数
 * @param filePath - アップロードするファイルのパス
 * @param bucketName - S3バケット名
 * @param keyPrefix - S3内のキーのプレフィックス
 * @param baseDir - 基準ディレクトリのパス
 */
async function uploadFileToS3(
  filePath: string,
  bucketName: string,
  keyPrefix: string,
  baseDir: string
) {
  try {
    const fileContent = await readFile(filePath);
    const relativePath = path.relative(baseDir, filePath);
    const s3Key = `${keyPrefix}/${relativePath.replace(/\\/g, "/")}`; // Windows環境対応のためスラッシュに変換

    const params = {
      Bucket: bucketName,
      Key: s3Key,
      Body: fileContent,
    };

    const command = new PutObjectCommand(params);
    await s3.send(command);
    console.log(
      `Successfully uploaded ${relativePath} to ${bucketName}/${s3Key}`
    );
  } catch (error) {
    console.error(`Error uploading ${filePath}:`, error);
    // エラーを再スローせず、続行可能にする
  }
}

/**
 * 指定されたディレクトリ内の全ファイルを再帰的に取得する関数
 * @param dir - 検索するディレクトリのパス
 * @returns - ファイルの絶対パスの配列
 */
async function getAllFiles(dir: string): Promise<string[]> {
  let results: string[] = [];
  const list = await readdir(dir);

  for (const file of list) {
    const filePath = path.join(dir, file);
    const fileStat = await stat(filePath);
    if (fileStat && fileStat.isDirectory()) {
      const nestedFiles = await getAllFiles(filePath);
      results = results.concat(nestedFiles);
    } else {
      results.push(filePath);
    }
  }

  return results;
}

/**
 * アーティファクトディレクトリ内の全ファイルをS3にアップロードする関数
 */
async function uploadArtifacts() {
  const bucketName = process.env.E2E_ARTIFACTS_BUCKET;
  if (!bucketName) {
    throw new Error("E2E_ARTIFACTS_BUCKET environment variable is not set.");
  }

  // Commitごとに異なるプレフィックスを設定（デフォルトはplaywright-artifacts）
  const keyPrefix =
    process.env.E2E_ARTIFACTS_KEY_PREFIX || "playwright-artifacts";

  // Playwrightのアーティファクトディレクトリ（設定に応じて変更）
  const artifactsDir = path.resolve("test-results");

  if (!fs.existsSync(artifactsDir)) {
    console.error(`Artifacts directory ${artifactsDir} does not exist.`);
    return;
  }

  const files = await getAllFiles(artifactsDir);

  if (files.length === 0) {
    console.log("No artifacts to upload.");
    return;
  }

  console.log(`Found ${files.length} files to upload.`);

  // 並列アップロードのためのプロミス配列
  const uploadPromises = files.map((filePath) =>
    uploadFileToS3(filePath, bucketName, keyPrefix, artifactsDir)
  );

  await Promise.all(uploadPromises);

  console.log("All artifacts uploaded successfully.");
}

// メイン実行
uploadArtifacts().catch((error) => {
  console.error("Error during artifact upload:", error);
  process.exit(1);
});
