# claude-code-switcher

Два способа переключать модель/провайдера в **Claude Code**:

1. **`env`-переключатели** (`cc-glm`, `cc-claude`) — меняют провайдера «на месте», в твоём основном `~/.claude/`. Один активный провайдер в момент времени.
2. **Отдельная команда `claude-ollama`** — параллельный профиль `~/.claude-ollama/` с теми же правилами/skills/MCP (через symlinks), всегда подключённый к Ollama. Работает одновременно с обычным `claude`.

---

## Установка

```bash
git clone https://github.com/mihailovmike/claude-code-switcher.git
cd claude-code-switcher
./install.sh
```

Что делает `install.sh`:

- Ставит в `~/.local/bin/`: `cc-glm`, `cc-claude`, `claude-ollama`, `claude-kimi` (и `cc-status`, если есть).
- Копирует шаблоны в `~/.claude/settings.glm.json`, `~/.claude/settings.claude.json`.
- Создаёт профиль `~/.claude-ollama/` и симлинкует в него правила, skills, agents, hooks, plugins, commands, settings, MCP-конфиг из основного `~/.claude/`.
- Опционально — спрашивает GLM-токен (Enter — пропустить).

Проверь, что `~/.local/bin` в `PATH`:

```bash
echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin" && echo OK || echo "добавь в ~/.zshrc:  export PATH=\"\$HOME/.local/bin:\$PATH\""
```

---

## Как это устроено

### `cc-glm` / `cc-claude` (env-swap)

Скрипты **НЕ копируют целиком** `~/.claude/settings.*.json` в `~/.claude/settings.json`.
Они заменяют **только поле `env`**, чтобы не сносить остальные настройки (`enabledPlugins`, `hooks`, `permissions`, и т.п.).

- **GLM (Z.ai)** — `https://api.z.ai/api/anthropic`, модели pinned на `glm-4.7`.
- **Claude (Anthropic)** — стандартный режим.

### `claude-ollama` (параллельный профиль)

Бинарник-обёртка в `~/.local/bin/claude-ollama`:

```bash
exec env CLAUDE_CONFIG_DIR="$HOME/.claude-ollama" ollama launch claude "$@"
```

Переменная `CLAUDE_CONFIG_DIR` сообщает Claude Code, где хранить credentials, историю и плагины. Указываем `~/.claude-ollama/` → получаем изолированный профиль. Внутри него — symlinks на всё общее из `~/.claude/`:

| Что общее (через symlinks) | Что своё в профиле |
|-|-|
| `CLAUDE.md`, `RTK.md`, `rules/` | Логин в ollama.com |
| `skills/`, `commands/`, `agents/`, `plugins/` | История сессий (`projects/`, `sessions/`) |
| `hooks/`, `settings.json`, `settings.local.json` | Кеши, telemetry, plans |
| `.claude.json` → MCP-серверы | |

Добавил skill/MCP/правило в `~/.claude/` → автоматически доступно в `claude-ollama` (symlinks).

---

## Использование

### Обычный Claude Code

```bash
claude
```

Твой привычный Claude Code, `~/.claude/`, основной аккаунт Anthropic.

### Ollama (локально или :cloud)

```bash
claude-ollama                                  # ollama спросит модель интерактивно
claude-ollama --model minimax-m2.7:cloud       # сразу с моделью
claude-ollama --model glm-5:cloud
claude-ollama --model qwen3-coder              # локальная модель
```

**Первый запуск** откроет браузер для логина на ollama.com. Дальше — просто работает. Можно открыть второй терминал и держать обычный `claude` параллельно — они не мешают друг другу.

Список облачных моделей: <https://ollama.com/search?c=cloud>

#### `claude-kimi` — быстрый старт на Kimi K2.6

Тот же профиль `~/.claude-ollama/`, но с зашитой моделью [`kimi-k2.6:cloud`](https://ollama.com/library/kimi-k2.6) (Moonshot AI, open-source multimodal agentic, 256K контекст):

```bash
claude-kimi              # = claude-ollama --model kimi-k2.6:cloud
claude-kimi --resume
```

Дополнительные аргументы прокидываются в `ollama launch claude` дальше, так что можно переопределить модель на лету (`claude-kimi --model kimi-k2.6:cloud-thinking`) или передать любой другой флаг.

### GLM (Z.ai) / нативный Claude через env-swap

```bash
cc-glm       # включить GLM, pinned glm-4.7
cc-claude    # вернуть нативный Claude
```

После переключения в TRAE/VS Code: **Cmd+Shift+P → Developer: Reload Window**.

---

## Когда какой подход

| Сценарий | Команда |
|-|-|
| Хочу временно сменить модель на GLM | `cc-glm` |
| Хочу попробовать Ollama один раз | `claude-ollama --model <...>` |
| Хочу быстро запустить Kimi K2.6 | `claude-kimi` |
| Держу Max-аккаунт и Ollama параллельно в разных вкладках | `claude` + `claude-ollama` |
| Нужны разные истории сессий | профиль (т.е. `claude-ollama`) |
| Основной `~/.claude/` ни в коем случае не трогать | профиль |

---

## Где лежат файлы

```
~/.local/bin/
├── claude-ollama            # бинарник-обёртка
├── claude-kimi              # claude-ollama с моделью kimi-k2.6:cloud
├── cc-glm                   # env-swap на GLM
└── cc-claude                # env-swap на нативный Claude

~/.claude/                   # основной профиль Claude Code
├── settings.json            # активный конфиг
├── settings.glm.json        # шаблон env для GLM (с токеном)
├── settings.claude.json     # шаблон env для нативного Claude
├── rules/, skills/, ...     # общие правила и skills

~/.claude-ollama/            # параллельный профиль (symlinks на ~/.claude/)
├── CLAUDE.md  ->  ~/.claude/CLAUDE.md
├── rules      ->  ~/.claude/rules
├── skills     ->  ~/.claude/skills
├── .claude.json ->  ~/.claude.json       # MCP-серверы
├── sessions/, projects/     # СВОЯ история (не symlink)
└── .credentials / keychain  # СВОЙ логин
```

> Токены не хранятся в репозитории — локально в `~/.claude/settings.glm.json`.

---

## Отладка

**`settings.json` — валидный JSON:**

```bash
python3 -m json.tool ~/.claude/settings.json >/dev/null && echo OK
```

**Текущий env-режим:**

```bash
python3 - <<'PY'
import json, os
env = json.load(open(os.path.expanduser("~/.claude/settings.json"))).get("env", {})
print("BASE_URL:", env.get("ANTHROPIC_BASE_URL", "(native Claude)"))
print("OPUS:   ", env.get("ANTHROPIC_DEFAULT_OPUS_MODEL"))
print("SONNET: ", env.get("ANTHROPIC_DEFAULT_SONNET_MODEL"))
print("HAIKU:  ", env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL"))
print("TOOL_SEARCH:", env.get("ENABLE_TOOL_SEARCH"))
PY
```

**Профиль Ollama — symlinks на месте:**

```bash
ls -la ~/.claude-ollama/
```

**Ollama-демон доступен:**

```bash
curl -s http://localhost:11434/api/tags | head -c 200
```

**Какой профиль активен в текущем терминале:**

```bash
echo "${CLAUDE_CONFIG_DIR:-(default ~/.claude)}"
```

---

## Обновление профиля после изменений в `~/.claude/`

Ничего делать не надо — всё через symlinks. Добавил новый skill, hook, MCP-сервер — он сразу в `claude-ollama`.

Если что-то переехало/переименовалось и ссылки сломались:

```bash
cd claude-code-switcher && ./install.sh
```

(безопасно — скрипт идемпотентен, `ln -sfn` перезаписывает битые ссылки).

---

## Почему `enabledPlugins` может быть пустым

Если раньше переключатель делал `cp settings.glm.json -> settings.json`, можно было потерять `enabledPlugins` — его перетирало.

Текущая версия:

- **не удаляет** `enabledPlugins`
- **не восстанавливает** его, если оно уже было удалено раньше

Если поле отсутствует — обычно появляется после действий в UI плагинов Claude Code.

---

## Uninstall

```bash
./uninstall.sh
```

Удаляет бинарники из `~/.local/bin`. Профиль `~/.claude-ollama/` и шаблоны `~/.claude/settings.*` **не трогает** (там твоя история и токены). Снести профиль целиком:

```bash
rm -rf ~/.claude-ollama
```
