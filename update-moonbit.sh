#!/usr/bin/env bash
set -euo pipefail
set -x
PKG_FILE="pkgs/moonbit/default.nix"
BINARY_URL="https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz"
CORE_URL="https://cli.moonbitlang.com/cores/core-latest.tar.gz"
PKG_FILE="pkgs/moonbit/default.nix"
echo "--- 调试步骤：验证文件路径和内容 ---"
echo "当前工作目录是: $(pwd)"
echo "正在检查文件是否存在于: $PKG_FILE"

# 检查文件是否存在，如果不存在就报错退出
if [ ! -f "$PKG_FILE" ]; then
  echo "错误: 找不到文件 $PKG_FILE !"
  echo "请检查 PKG_FILE 变量的路径是否正确，以及 GitHub Actions 的 checkout 步骤是否成功。"
  exit 1
fi

echo "文件存在。正在打印文件内容以供检查："
cat "$PKG_FILE"
echo "--- 调试步骤结束 ---"

OLD_BINARY_HASH=$(grep -A 1 'url = "'$BINARY_URL'"' "$PKG_FILE" | grep 'sha256' | sed -e 's/.*sha256 = "\(.*\)";/\1/')
OLD_CORE_HASH=$(grep -A 1 'url = "'$CORE_URL'"' "$PKG_FILE" | grep 'sha256' | sed -e 's/.*sha256 = "\(.*\)";/\1/')

echo "Current binary hash: $OLD_BINARY_HASH"
echo "Current core hash:   $OLD_CORE_HASH"

NEW_BINARY_HASH=$(nix-prefetch-url "$BINARY_URL")
NEW_CORE_HASH=$(nix-prefetch-url "$CORE_URL")

echo "Latest binary hash: $NEW_BINARY_HASH"
echo "Latest core hash:   $NEW_CORE_HASH"

if [ "$OLD_BINARY_HASH" != "$NEW_BINARY_HASH" ] || [ "$OLD_CORE_HASH" != "$NEW_CORE_HASH" ]; then
  echo "New version found! Updating $PKG_FILE..."
  # Use `sed` to find and replace the old hashes with the new ones.
  sed -i "s|sha256 = \"$OLD_BINARY_HASH\";|sha256 = \"$NEW_BINARY_HASH\";|" "$PKG_FILE"
  sed -i "s|sha256 = \"$OLD_CORE_HASH\";|sha256 = \"$NEW_CORE_HASH\";|" "$PKG_FILE"
  echo "Update complete. The Nix expression is now pointing to the latest version."
else
  echo "Package is already up-to-date. No changes needed."
fi
