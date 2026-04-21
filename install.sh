#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/bin" "$HOME/.claude"

# ─── env-переключатели (GLM / Claude) ─────────────────────────────────────
install -m 755 "$REPO_DIR/bin/cc-glm"        "$HOME/.local/bin/cc-glm"
install -m 755 "$REPO_DIR/bin/cc-claude"     "$HOME/.local/bin/cc-claude"
if [ -f "$REPO_DIR/bin/cc-status" ]; then
  install -m 755 "$REPO_DIR/bin/cc-status"   "$HOME/.local/bin/cc-status"
fi

install -m 600 "$REPO_DIR/templates/settings.claude.json" "$HOME/.claude/settings.claude.json"
install -m 600 "$REPO_DIR/templates/settings.glm.json"    "$HOME/.claude/settings.glm.json"

# ─── параллельный профиль под Ollama ──────────────────────────────────────
install -m 755 "$REPO_DIR/bin/claude-ollama" "$HOME/.local/bin/claude-ollama"
install -m 755 "$REPO_DIR/bin/claude-kimi"   "$HOME/.local/bin/claude-kimi"

PROFILE_DIR="$HOME/.claude-ollama"
mkdir -p "$PROFILE_DIR"

# Файлы из ~/.claude/ → симлинк в профиль (общие правила, settings, hooks-scripts)
for f in CLAUDE.md RTK.md settings.json settings.local.json keybindings.json \
         mcp-disabled.json statusline-command.sh claude-usage.sh claude-usage-prompt.sh; do
  if [ -e "$HOME/.claude/$f" ]; then
    ln -sfn "$HOME/.claude/$f" "$PROFILE_DIR/$f"
  fi
done

# Директории → симлинк (правила, skills, agents, hooks, plugins, commands)
for d in rules skills agents hooks plugins commands; do
  if [ -d "$HOME/.claude/$d" ]; then
    ln -sfn "$HOME/.claude/$d" "$PROFILE_DIR/$d"
  fi
done

# MCP-серверы лежат в ~/.claude.json (верхний уровень) — симлинкнем и его
if [ -f "$HOME/.claude.json" ]; then
  ln -sfn "$HOME/.claude.json" "$PROFILE_DIR/.claude.json"
fi

# ─── GLM-токен (опционально) ──────────────────────────────────────────────
echo
echo "Вставь токен Z.ai для GLM (Enter чтобы пропустить):"
read -rs TOKEN
echo

if [ -n "$TOKEN" ]; then
  TOKEN="$TOKEN" python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.glm.json")
with open(p, "r", encoding="utf-8") as f:
    data = json.load(f)
data["env"]["ANTHROPIC_AUTH_TOKEN"] = os.environ["TOKEN"]
with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print("OK: токен записан в ~/.claude/settings.glm.json")
PY
else
  echo "GLM-токен не задан. Для GLM отредактируй ~/.claude/settings.glm.json вручную."
fi

chmod 600 "$HOME/.claude/settings.glm.json" "$HOME/.claude/settings.claude.json"

cat <<'DONE'

Готово. Команды:

  cc-glm         → включить GLM (Z.ai), env-swap в ~/.claude/
  cc-claude      → включить родной Claude (Anthropic), env-swap
  claude-ollama  → отдельный профиль ~/.claude-ollama/, подключён к Ollama
  claude-kimi    → то же, но сразу с моделью kimi-k2.6:cloud (Moonshot AI)

Проверь:
  ls -la ~/.claude-ollama/                 # должны быть symlinks на ~/.claude/
  which claude-ollama                       # ~/.local/bin/claude-ollama

Запуск:
  claude-ollama                             # интерактивный выбор модели
  claude-ollama --model minimax-m2.7:cloud  # сразу с моделью

Первый запуск claude-ollama откроет браузер для логина на ollama.com.
DONE
