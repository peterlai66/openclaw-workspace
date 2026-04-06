import fs from "fs";
import dayjs from "dayjs";

const memoryPath = "/home/pclaw/.openclaw/memory";

export function shouldRun(task) {
  const today = dayjs().format("YYYY-MM-DD");
  const file = `${memoryPath}/${today}.json`;

  if (!fs.existsSync(file)) return true;

  const data = JSON.parse(fs.readFileSync(file));
  return data[task] !== "done";
}