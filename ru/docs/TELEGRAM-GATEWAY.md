# Telegram Gateway — Интерфейс с кнопками одобрения

**Настройка Hermes Telegram Gateway для удалённого управления эволюцией с телефона.**

---

## Зачем?

Сидеть за ноутбуком 24/7 — больная спина. Telegram-интерфейс с кнопками позволяет:
- Одобрять/отклонять действия одним нажатием
- Получать отчёты и статусы в реальном времени
- Отдавать команды голосом (Telegram voice → STT)
- Управлять эволюцией с телефона из любой точки мира

---

## Архитектура

```
┌─────────────────┐     Telegram API     ┌──────────────────┐
│   Telegram App  │◄──────────────────►  │  Hermes Gateway  │
│   (телефон)     │    long polling      │  (сервер)        │
└─────────────────┘                      └────────┬─────────┘
                                                   │
                                                   ▼
                                          ┌──────────────────┐
                                          │  Hermes Agent    │
                                          │  (AI ядро)       │
                                          └────────┬─────────┘
                                                   │
                                                   ▼
                                          ┌──────────────────┐
                                          │  Terminal Tools  │
                                          │  (команды, код)  │
                                          └──────────────────┘
```

---

## Установка на новом устройстве

### Шаг 1: Установить Hermes Agent

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
```

### Шаг 2: Создать Telegram бота

1. Открыть Telegram → найти @BotFather
2. Отправить `/newbot`
3. Назвать (например, `IsleStewardBot`)
4. Получить токен вида `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`

### Шаг 3: Настроить Hermes Gateway

```bash
# Установить провайдера и модель
hermes setup

# Настроить Telegram
hermes config set TELEGRAM_BOT_TOKEN "ваш_токен_сюда"
# ИЛИ через .env: TELEGRAM_BOT_TOKEN=ваш_токен

# Разрешить только себе (по user_id)
hermes config set TELEGRAM_ALLOWED_USERS "143293811"
```

### Шаг 4: Включить кнопки одобрения

```bash
hermes config set approvals.mode manual
```

### Шаг 5: Запустить Gateway

```bash
# Запустить gateway-сервер
hermes gateway run

# Или установить как systemd-сервис
hermes gateway install
```

### Шаг 6: Подключиться

1. Найти своего бота в Telegram
2. Нажать /start
3. Готово! Все запросы одобрения придут с кнопками ✅

---

## Структура approval-кнопок

Когда Hermes хочет выполнить действие, требующее одобрения:

```
⚠️ Запрос на выполнение:
  Команда: go build ./cmd/simplex-node/
  Риск: MEDIUM (компиляция кода)
  Сессия: CLI #3

[ ✅ Разрешить ] [ ❌ Запретить ] [ ⏰ 5 мин ]
```

- **Разрешить** — выполнить сейчас
- **Запретить** — отклонить
- **5 мин** — отложить на 5 минут (напоминание)

Настройка таймаута:
```bash
hermes config set approvals.timeout 120  # секунд
```

---

## Перенос конфигурации на другой ноутбук

### Вариант А: Через этот репозиторий

```bash
# На новом ноутбуке
git clone https://github.com/PerfectFriend/evolution-protocol.git ~/evolution-protocol
cp ~/evolution-protocol/configs/hermes-config.yaml ~/.hermes/config.yaml
# Отредактировать secrets в .env
hermes gateway run
```

### Вариант Б: Автоматический bootstrap

```bash
bash ~/evolution-protocol/scripts/bootstrap.sh
```

### Вариант В: Ручная настройка

```bash
# Минимальный конфиг
hermes config set approvals.mode manual
hermes config set terminal.backend local
hermes config set display.skin default
# Telegram токен в .env
echo 'TELEGRAM_BOT_TOKEN=ваш_токен' >> ~/.hermes/.env
hermes gateway run
```

---

## Критичные настройки config.yaml

```yaml
approvals:
  mode: manual           # ВСЕГДА запрашивать одобрение
  timeout: 120           # Таймаут ожидания ответа

telegram:
  allowed_users:
    - "143293811"        # Только вы
  home_channel: "143293811"
  parse_mode: markdown   # Красивое форматирование
```

---

## Telegram voice commands

Telegram поддерживает голосовые сообщения. Hermes автоматически:
1. Расшифровывает голос → текст (через Whisper/local STT)
2. Выполняет команду
3. Отвечает текстом или голосом

Не нужно ничего настраивать — работает из коробки.

---

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| Кнопки не работают | Гермес должен быть запущен через `hermes gateway run`, а не через opencode-tg-bot |
| Нет ответа от бота | Проверить `hermes gateway status`, логи: `journalctl -u hermes-gateway` |
| Tor блокирует Telegram API | `unset HTTP_PROXY HTTPS_PROXY` перед стартом gateway |
| "Bot token is invalid" | Проверить TELEGRAM_BOT_TOKEN в .env, пересоздать у @BotFather |

---

*Спина скажет спасибо.*