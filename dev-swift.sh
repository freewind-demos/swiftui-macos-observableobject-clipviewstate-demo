#!/usr/bin/env bash
# 自动重编并重启 app；有 fswatch 就持续监听，没有就先编 1 次。
set -euo pipefail

# 固定用本机完整 Xcode。
export DEVELOPER_DIR=/System/Volumes/Data/Applications/Xcode.app/Contents/Developer

# 定位到项目根目录。
ROOT="$(cd "$(dirname "$0")" && pwd)"

# 固定 app 名，避免再解析 yaml。
APP_NAME="ClipViewStateDemo"

# 固定 Debug 产物目录。
APP_PATH="${ROOT}/build/DerivedData/Build/Products/Debug/${APP_NAME}.app"

# 定义 1 次构建并重启流程。
run_once() {
  # 进入根目录再执行脚本。
  cd "$ROOT"

  # 先编译。
  ./scripts/build.sh

  # 杀掉旧进程；没有时忽略。
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  # 打开新 app。
  open "$APP_PATH"
}

# 如果没装 fswatch，就只跑 1 次并提示。
if ! command -v fswatch >/dev/null 2>&1; then
  echo "warning: fswatch not found; run once only"
  run_once
  exit 0
fi

# 先跑首轮。
run_once

# 监听源码与工程文件变化。
fswatch -o "$ROOT/Sources" "$ROOT/project.yml" | while read -r _; do
  # 任意变化后重新编并重启。
  run_once
done
