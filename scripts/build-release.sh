#!/usr/bin/env bash
# 只是转发到 release 构建。
set -euo pipefail

# 进入脚本所在目录。
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 转发到主构建脚本。
"${ROOT}/scripts/build.sh" release
