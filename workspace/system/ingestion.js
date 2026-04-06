import fs from "fs";
import fetch from "node-fetch";
import dayjs from "dayjs";

const ROOT = "/home/pclaw/.openclaw/workspace";

export async function ingest(type) {
  const configPath = `${ROOT}/system/ingestion.json`;

  if (!fs.existsSync(configPath)) {
    console.error(`❌ ingestion config not found: ${configPath}`);
    process.exitCode = 1;
    return;
  }

  const config = JSON.parse(fs.readFileSync(configPath, "utf-8"));
  const sources = config[type]?.sources;

  if (!sources || !Array.isArray(sources)) {
    console.error(`❌ unknown ingestion type: ${type}`);
    process.exitCode = 1;
    return;
  }

  const results = [];

  for (const url of sources) {
    try {
      const res = await fetch(url);
      const json = await res.json();
      results.push({
        url,
        fetchedAt: new Date().toISOString(),
        data: json
      });
    } catch (e) {
      console.error(`⚠️ ingestion error: ${url}`, e?.message || e);
    }
  }

  const date = dayjs().format("YYYY-MM-DD");
  const outputDir = `${ROOT}/data/${type}`;
  const outputPath = `${outputDir}/${date}.json`;

  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(results, null, 2), "utf-8");

  console.log(`✅ ingestion saved: ${outputPath}`);
}

const isDirectRun =
  process.argv[1] === new URL(import.meta.url).pathname;

if (isDirectRun) {
  const type = process.argv[2];

  if (!type) {
    console.error("❌ missing type (market / ai)");
    process.exit(1);
  }

  await ingest(type);
}