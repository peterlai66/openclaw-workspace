import fs from "fs";
import dayjs from "dayjs";
import { execSync } from "child_process";
import { shouldRun } from "/home/pclaw/.openclaw/workspace/system/scheduler.js";

const ROOT = "/home/pclaw/.openclaw/workspace";
process.chdir(ROOT);

const config = JSON.parse(
  fs.readFileSync("/home/pclaw/.openclaw/workspace/system/scheduler.json", "utf-8")
);

function runTask(task) {
  try {
    console.log(`[RUN] ${task}`);

    const message =
      task === "market"
        ? "請執行今日 market 自動任務：若今日尚未完成，先 ingestion market，再整理成今日市場摘要；若已完成則不要重跑。"
        : "請執行今日 ai 自動任務：若今日尚未完成，先 ingestion ai，再整理成今日 AI/科技摘要；若已完成則不要重跑。";

    execSync(
      `openclaw agent --agent main --message ${JSON.stringify(message)} --timeout 900`,
      { stdio: "inherit" }
    );
  } catch (e) {
    console.error(`[ERROR] ${task}`, e.message);
  }
}

function inTimeWindow(window) {
  const now = dayjs();
  const [start, end] = window;

  const [startHour, startMinute] = start.split(":").map(Number);
  const [endHour, endMinute] = end.split(":").map(Number);

  const startTime = dayjs().hour(startHour).minute(startMinute).second(0);
  const endTime = dayjs().hour(endHour).minute(endMinute).second(59);

  return now.isAfter(startTime) && now.isBefore(endTime);
}

function main() {
  for (const job of config.jobs) {
    if (!shouldRun(job.task)) continue;
    if (!inTimeWindow(job.window)) continue;
    runTask(job.task);
  }
}

main();