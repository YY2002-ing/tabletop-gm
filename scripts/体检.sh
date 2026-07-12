#!/bin/bash
# 跑团 · 体检脚本：团状态文件完整性 + 格式哨兵 + 安全扫描
# 每场落盘后、每次结算后必跑到零问题。
set -u
cd "$(dirname "$0")/.."
FAIL=0
say_fail() { echo "❌ $1"; FAIL=1; }
say_ok()   { echo "✅ $1"; }

shopt -s nullglob
CAMPS=(团/*/)
if [ ${#CAMPS[@]} -eq 0 ]; then
  echo "ℹ️  还没有任何团（团/ 为空），跳过团检查"
else
  for C in "${CAMPS[@]}"; do
    NAME=$(basename "$C")
    # 1. 必备文件
    for F in "幕后/真相.md" "幕后/伏笔台账.md" "幕后/世界状态.md" "幕后/情报规则.md" "台面/台面事实志.md"; do
      [ -f "$C$F" ] || say_fail "[$NAME] 缺少 $F"
    done
    [ -d "$C幕后/人物册" ] || say_fail "[$NAME] 缺少 幕后/人物册/"
    [ -d "$C台面/场景存档" ] || say_fail "[$NAME] 缺少 台面/场景存档/"

    # 2. 伏笔台账格式：每个条目行必须以 - [未填] 或 - [已填:场N] 开头
    if [ -f "$C幕后/伏笔台账.md" ]; then
      BADK=$(grep -E "^- " "$C幕后/伏笔台账.md" | grep -vE "^- \[(未填|已填:场[0-9]+)\]" || true)
      [ -z "$BADK" ] && say_ok "[$NAME] 伏笔台账格式合规" \
        || say_fail "[$NAME] 伏笔台账有条目缺状态标记：$(echo "$BADK" | head -2)"
    fi

    # 3. 台面事实志格式：条目行必须带 [场N]
    if [ -f "$C台面/台面事实志.md" ]; then
      BADF=$(grep -E "^- " "$C台面/台面事实志.md" | grep -vE "^- \[场[0-9]+\]" || true)
      [ -z "$BADF" ] && say_ok "[$NAME] 台面事实志格式合规" \
        || say_fail "[$NAME] 台面事实志有条目没标场号：$(echo "$BADF" | head -2)"
    fi

    # 4. 知情账本格式：条目行必须带 [时间|渠道]
    for LEDGER in "$C幕后/阵营/"*.md; do
      BADL=$(grep -E "^- " "$LEDGER" | grep -vE "^- \[[^|]+\|[^]]+\]" || true)
      [ -z "$BADL" ] || say_fail "[$NAME] $(basename "$LEDGER") 有情报没标时间和渠道：$(echo "$BADL" | head -2)"
    done

    # 5. 世界状态必备字段
    if [ -f "$C幕后/世界状态.md" ]; then
      for KEY in "剧情时间" "当前场号" "待结算"; do
        grep -q "$KEY" "$C幕后/世界状态.md" || say_fail "[$NAME] 世界状态缺「$KEY」字段"
      done
      grep -q "待结算：是" "$C幕后/世界状态.md" && say_fail "[$NAME] 有未完成的结算（待结算：是）——先跑 /结算"
    fi

    # 6. 场号连续性（缺号只警告，不算失败）
    SCENES=$(ls "$C台面/场景存档/" 2>/dev/null | grep -oE "场-[0-9]+" | grep -oE "[0-9]+" | sort -n || true)
    if [ -n "$SCENES" ]; then
      EXPECT=1
      for S in $SCENES; do
        S=$((10#$S))
        [ "$S" -eq "$EXPECT" ] || echo "⚠️  [$NAME] 场号不连续：期待场-$EXPECT，实际场-$S"
        EXPECT=$((S + 1))
      done
      say_ok "[$NAME] 场景存档 $(echo "$SCENES" | wc -l | tr -d ' ') 场"
    fi
  done
fi

# 7. 安全扫描
if [ -d .git ]; then
  git ls-files | grep -qE "^\.env" && say_fail ".env 竟然被 git 追踪" || say_ok ".env 未被追踪"
  LEAK=$(git ls-files -z | xargs -0 grep -lE "sk-[A-Za-z0-9]{20,}|api[_-]?key\s*[:=]\s*['\"][A-Za-z0-9]{16,}" 2>/dev/null || true)
  [ -z "$LEAK" ] && say_ok "key 扫描：无疑似密钥" || say_fail "key 扫描：疑似密钥出现在：$LEAK"
fi

echo "----------------------------------------"
if [ "$FAIL" -eq 0 ]; then echo "🎉 体检通过，零问题"; else echo "💥 体检未通过，先修再继续"; exit 1; fi
