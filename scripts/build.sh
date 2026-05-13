#!/usr/bin/env bash
# 生成工程并命令行编译；默认 Debug，传 release 则编 Release。
set -euo pipefail

# 固定用本机完整 Xcode。
export DEVELOPER_DIR=/System/Volumes/Data/Applications/Xcode.app/Contents/Developer

# 定位项目根目录。
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 固定工程名。
PROJ_NAME="ClipViewStateDemo"

# 进入项目根目录。
cd "$ROOT"

# 读取模式；默认 debug。
MODE="$(echo "${1:-debug}" | tr '[:upper:]' '[:lower:]')"

# 每次先重新生成工程，避免工程文件过期。
xcodegen generate

# 按模式准备输出目录。
if [[ "$MODE" == "release" ]]; then
  CONFIG="Release"
  DERIVED="${ROOT}/build/ReleaseDerivedData"
  rm -rf "${ROOT}/dist" "$DERIVED"
  mkdir -p "${ROOT}/dist"
else
  CONFIG="Debug"
  DERIVED="${ROOT}/build/DerivedData"
  rm -rf "$DERIVED"
fi

# 执行编译。
xcodebuild -project "${PROJ_NAME}.xcodeproj" \
  -scheme "${PROJ_NAME}" \
  -configuration "${CONFIG}" \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build

# Release 时复制到 dist；Debug 时只回显产物位置。
if [[ "$MODE" == "release" ]]; then
  ditto "${DERIVED}/Build/Products/Release/${PROJ_NAME}.app" "${ROOT}/dist/${PROJ_NAME}.app"
  echo "Release app: ${ROOT}/dist/${PROJ_NAME}.app"
else
  echo "Debug app: ${DERIVED}/Build/Products/Debug/${PROJ_NAME}.app"
fi
