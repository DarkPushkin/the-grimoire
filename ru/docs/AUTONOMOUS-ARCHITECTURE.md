# Evolution Protocol — Автономная Архитектура

> *Как Hermes Agent, OpenCode, Telegram Gateway, Docker и ParanoidX работают вместе, чтобы создать самоэволюционирующую систему.*

---

## Схема системы

```
                          ┌──────────────────────┐
                          │   Telegram (телефон)  │
                          │   Кнопки одобрения    │
                          └──────────┬───────────┘
                                     │ long polling
                          ┌──────────▼───────────┐
                          │   Hermes Gateway     │
                          │   (Telegram шлюз)    │
                          └──────────┬───────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          ▼                          ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Hermes Agent   │    │   OpenCode CLI   │    │   Cron Jobs      │
│   (AI ядро)      │    │   (coding агент) │    │   (фоновые)      │
└──────┬───────────┘    └────────┬─────────┘    └────────┬─────────┘
       │                         │                       │
       └──────────┬──────────────┼───────────────────────┘
                  │              │
                  ▼              ▼
         ┌────────────────────────────┐
         │     Terminal Tools         │
         │  (build, test, git, curl)  │
         └────────────┬───────────────┘
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Go Build │ │ Docker   │ │ System   │
   │ simlex   │ │ 5 сервисов│ │ команды  │
   └──────────┘ └──────────┘ └──────────┘
```

---

## Компоненты

### 1. Hermes Agent (AI Ядро)
- **Роль:** Интерпретатор команд, стратег, отчётчик
- **Провайдер:** OpenCode (DeepSeek V4 Flash Free) / OpenRouter
- **Конфиг:** `~/.hermes/config.yaml`
- **Навыки (Skills):** ~30+ procedural memory файлов
- **Память:** Cross-session memory + user profile

### 2. Hermes Gateway (Telegram Шлюз)
- **Роль:** Мост между Telegram и AI ядром
- **Протокол:** Long polling (не webhook — не требует публичного URL)
- **Кнопки:** Inline keyboard для одобрения/отклонения
- **Мультиплатформа:** Telegram, Discord, Signal, WhatsApp...

### 3. OpenCode CLI (Coding Agent)
- **Роль:** Автономный кодинг-агент (альтернатива Hermes для сложных рефакторингов)
- **Провайдер:** DeepSeek V4 Flash Free
- **Интеграция:** Через opencode-tg-listener для отчётов в Telegram

### 4. Docker (Контейнеризация)
- **Сервисы:** tor, v2ray/xray, smp-server, coturn, xftp-server
- **Сеть:** bridge + docker-compose
- **ParanoidX:** VMess + VLESS + Tor multi-layer routing

### 5. Cron Jobs (Автоматизация)
- **Статус-репорт:** Каждый час → Telegram
- **Бэкапы:** Каждый цикл
- **Health check:** Каждые 5 минут (systemd)

---

## Процесс approval (одобрение действий)

```
Пользователь в Telegram:
  ┌─────────────────────────────────────┐
  │ 🤖 Выполнить: go build ./...        │
  │ ⚠️ Риск: MEDIUM                     │
  │                                     │
  │ [ ✅ Разрешить ] [ ❌ Запретить ]    │
  └─────────────────────────────────────┘
         │                    │
         ▼                    ▼
  Hermes выполняет      Hermes отменяет
  команду               команду
         │
         ▼
  Результат → Telegram
```

**Настройка уровней риска:**
- **LOW** — `flutter pub get`, `git status` — без подтверждения
- **MEDIUM** — `go build`, `git commit` — запрос
- **HIGH** — `rm -rf`, `sudo` — обязательный запрос

---

## ParanoidX — Многослойная маршрутизация

```
Внешний мир
     │
     ▼
┌─────────────┐     Port 10808     ┌─────────────┐
│  VMESS      │◄──────────────────│  V2Ray      │
│  (:10812)   │                   │  (Docker)   │
└──────┬──────┘                   └──────┬──────┘
       │                                 │
       ▼                                 ▼
┌─────────────┐     Port 10810     ┌─────────────┐
│  VLESS      │◄──────────────────│  XRay       │
│  (:10813)   │                   │  (native)   │
└──────┬──────┘                   └──────┬──────┘
       │                                 │
       ▼                                 ▼
┌─────────────┐                    ┌─────────────┐
│  TOR        │                    │  SimpleX    │
│  (:9050)    │                    │  (:17225)   │
└─────────────┘                    └─────────────┘
```

---

## Метрики здоровья

```json
{
  "healthy": true,
  "uptime_hours": 3.1,
  "build": "px-node-C41-C60",
  "bridge": true,
  "messages": 0,
  "dc_cloud": 0,
  "dc_seeding": 0
}
```

Проверка: `curl http://127.0.0.1:8080/api/health`

---

## Путь миграции на новое железо

1. **Beelink SER9** (26GB RAM, 500GB SSD, Ryzen 9) — будущий сервер
2. **OPNsense** — фаервол с 3 VLAN: Mgmt, Onion, SMP
3. **Proxmox LXC** — виртуализация вместо Docker
4. **500Mbps fiber** — вместо Tor-only

См. `docs/TELEGRAM-GATEWAY.md` для настройки удалённого управления.