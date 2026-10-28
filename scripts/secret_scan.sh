#!/usr/bin/env bash
# secret_scan.sh — 插件发布前的密钥与隐私扫描（工作树 + 全历史）
# 用法: bash secret_scan.sh <repo-path> [<repo-path2> ...]
# 退出码: 0 = 扫描完成（不代表干净）；1 = 参数缺失
set -u

if [ "$#" -eq 0 ]; then
  echo "用法: bash secret_scan.sh <repo-path> [<repo-path2> ...]" >&2
  exit 1
fi

# 高置信密钥形态
PAT='sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|hf_[A-Za-z0-9]{20,}|ms-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY'

# 键值对形式的凭据
PAT_KV='(api[_-]?key|apikey|access[_-]?token|secret|passwd|password|authorization)[^A-Za-z0-9]{1,4}[:=][^A-Za-z0-9]{0,4}[A-Za-z0-9_\-\.]{12,}'

for repo in "$@"; do
  echo "=============================================================="
  echo "REPO: $repo"
  echo "=============================================================="
  cd "$repo" || { echo "  [MISSING] 路径不存在"; continue; }

  echo "--- remote ---"
  git remote -v 2>/dev/null || true
  echo "--- commits / tracked files ---"
  printf 'commits: %s\n' "$(git rev-list --all --count 2>/dev/null || echo 0)"
  printf 'files:   %s\n' "$(git ls-files 2>/dev/null | wc -l)"

  echo "--- 1) 工作树: 高置信密钥 ---"
  git grep -I -n -E "$PAT" -- . 2>/dev/null | head -40 || echo "  (none)"

  echo "--- 2) 工作树: 键值对凭据 ---"
  git grep -I -n -i -E "$PAT_KV" -- . 2>/dev/null | head -40 || echo "  (none)"

  echo "--- 3) 工作树: 本机路径/内网端点/邮箱/手机号 ---"
  git grep -I -n -E '(C:\\\\Users\\\\[^\\]+|/home/[a-z0-9_-]+/|/Users/[A-Za-z0-9._-]+/|127\.0\.0\.1:[0-9]{2,5}|localhost:[0-9]{2,5}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|1[3-9][0-9]{9})' -- . 2>/dev/null | head -40 || echo "  (none)"

  if [ -d .git ]; then
    echo "--- 4) 全历史: 高置信密钥 ---"
    git grep -I -n -E "$PAT" $(git rev-list --all) 2>/dev/null | head -60 || echo "  (none)"
    echo "--- 5) 全历史: 键值对凭据 ---"
    git grep -I -n -i -E "$PAT_KV" $(git rev-list --all) 2>/dev/null | head -60 || echo "  (none)"
    echo "--- 6) 历史新增过的可疑文件名 ---"
    git log --all --pretty=format: --name-only --diff-filter=A 2>/dev/null \
      | sort -u \
      | grep -i -E '(\.env|secret|credential|token|\.pem|\.pfx|cookie|session|\.log$)' | head -30 || echo "  (none)"
    echo "--- 7) .gitignore ---"
    cat .gitignore 2>/dev/null || echo "  (no .gitignore)"
  else
    echo "  [NO .git] 只扫工作树，历史无法检查"
  fi
  echo
done

cat <<'NOTE'
--------------------------------------------------------------
判定规则：
  - 真实 API key / token / 私钥            -> 立即吊销 + 改写历史，不许发布
  - 测试夹具（以 sk- 开头的假值）           -> 可用，但要在报告里逐条列出
  - 真实群号 / 账号 / 本机绝对路径          -> 换成虚构值（群号用 123456789，用户名用 example）
  - 127.0.0.1 本地服务默认端口              -> 通常是正常信息，按项目判断
NOTE
