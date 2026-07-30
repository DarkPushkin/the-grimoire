# Evolution SOP — Standard Operating Procedure

**Версия:** 2.0
**Проект:** Saint Mary Liberty Island / simplex-node
**Цикл:** Эволюционный — бесконечный

---

## Преамбула

Каждый производственный цикл следует ровно 8 шагам. Ни один не пропускается.
Цикл начинается с бэкапа и заканчивается вызовом Администратора для одобрения.

---

## Шаг 1: БЭКАП (Backup)

Сохранение состояния перед любыми изменениями.

```bash
# Source snapshot
tar -czf /tmp/cycle-$(date +%Y%m%d-%H%M)-source.tar.gz /home/tomas/simplex-node/

# Data snapshot (registries, ledger, vault, configs)
cp ~/.local/share/simplex-node/ /home/tomas/A1-backups/cycle-N/data/

# MANIFEST
cat > /home/tomas/A1-backups/cycle-N/MANIFEST.txt << EOF
Cycle: N
Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Version: A2.0
Build: px-node-CXX-CYY
Backup by: Hermes Agent
EOF
```

**Проверка:** `diff -r ~/.local/share/simplex-node/ /home/tomas/A1-backups/cycle-N/data/`

---

## Шаг 2: ПЛАН (Plan)

Переписать THEPLAN.md с учётом:
- Текущего состояния проекта
- Новых запросов от администратора
- Приоритетов: bugs > security > features
- Предыдущих результатов тестов

```bash
cat docs/PRODUCTION-CYCLE.md docs/EVOLUTION-PLAN.md > /tmp/cycle-context.md
```

---

## Шаг 3: ОТЧЁТ О ПЛАНЕ (Report Plan)

Отправить план в Inquisitor Bot:

```bash
bash scripts/send-to-inquisitor.sh "Cycle N Plan: ..."
```

**Канал:** Telegram @opencode-tg-bot  
**Токен:** `~/.config/opencode-tg-bot.token`  
**Chat ID:** `143293811`

---

## Шаг 4: ВЫБОР ШАГОВ (Choose Steps)

Выбрать 1-3 шага для текущего цикла:
- Приоритет: bugs исправления → security → новые возможности
- Максимум 3 шага за цикл (фокус)
- Сообщить выбранные шаги администратору

---

## Шаг 5: СБОРКА (Build)

После каждого изменения:
```bash
go build ./cmd/simplex-node/    # Должен проходить
go vet ./...                    # Должен проходить
```

Коммитить после каждого завершённого шага:
```bash
git add -A && git commit -m "Cycle N: Step description"
```

---

## Шаг 6: ТЕСТЫ + ОТЛАДКА (Test + Debug)

```bash
# Короткие тесты
go test ./... -short -count=1 -timeout 30s

# Тест конкретного пакета
go test ./internal/economy/... -count=1

# Race detector (кроме internal/lock — bcrypt cost=10)
go test -race ./internal/... -count=1 -timeout 60s 2>&1 | grep -v "internal/lock"

# Интеграционные тесты (если применимо)
bash scripts/test-royal.sh

# Линтинг
go vet ./...
```

Если тест падает: дебаг → фикс → ре-тест.

---

## Шаг 7: ОТЧЁТ (Create Report)

Формат отчёта:
1. Что сделано (шаги завершены)
2. Что изменилось (файлы изменены, новые файлы)
3. Результаты тестов (pass/fail, coverage)
4. Найденные проблемы
5. Что дальше (рекомендации для следующего цикла)
6. Отправить в Inquisitor Bot

```bash
bash scripts/send-to-inquisitor.sh "Cycle N Report: ..."
```

---

## Шаг 8: ВЫЗОВ АДМИНА (Call Admin)

1. Представить отчёт
2. Спросить: одобрить, скорректировать или отклонить
3. Если одобрить → начать следующий цикл (шаг 1)
4. Если скорректировать → обновить план, перезапустить цикл
5. Если отклонить → остановить, задокументировать причину

---

## Telegram Gateway — Approval Buttons

На каждом шаге, требующем одобрения (шаги 3, 4, 7, 8), запрос приходит в Telegram с кнопками:

```
🤖 Hermes Agent запрашивает разрешение:
  Выполнить: go build ./cmd/simplex-node/
  Риск: MEDIUM

[ ✅ Разрешить ] [ ❌ Запретить ] [ 🔄 Изменить ]
```

Настройка:
```bash
hermes config set approvals.mode manual
```

---

## Глоссарий

| Термин | Описание |
|--------|----------|
| Cycle | Одна итерация 8-шагового процесса |
| Epoch | 20 циклов (полная эволюционная эпоха) |
| THEPLAN.md | Живой документ стратегии |
| Inquisitor Bot | Telegram-бот для отчётов (@opencode-tg-bot) |
| AGENTS.md | Контекстный файл для opencode/Hermes |
| ParanoidX | Многослойная система маршрутизации (VMess + VLESS + Tor) |

---

*Ad gloriam Dei et libertatem Insulae Sanctae Mariae.*