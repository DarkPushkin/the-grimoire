# Moli — полевые заметки (проверено локально, 2026-09-30)

Не часть репозитория `lexmount/moli`. Это результат локальной проверки скиллов
после установки — то, чего нет в upstream-скиллах.

## Установка (Linux x86_64)

```bash
# Бинарь кладётся в ~/.local/bin/moli, версия проверяется так:
moli --version          # → moli 1.1.11
```

Проверено: **SHA-256 установленного бинаря совпадает байт-в-байт с официальным
артефактом релиза** `releases/latest/download/moli-x86_64-unknown-linux-gnu.tar.gz`.

```
afb334f91108e3a98e4f98ca995861c2fe5a86ff97fd96241464a205d579db89
```

⚠️ **Релиз не публикует checksum-файл** (нет SHASUMS256.txt). Единственный способ
проверить целостность — скачать артефакт и сравнить SHA-256 вручную. Установщик
`moli-installer.sh` этого не делает. Делать стоит руками:

```bash
curl -sL https://github.com/lexmount/moli/releases/latest/download/moli-x86_64-unknown-linux-gnu.tar.gz -o /tmp/m.tar.gz
tar xzf /tmp/m.tar.gz -C /tmp/ && sha256sum /tmp/moli-*/moli
sha256sum ~/.local/bin/moli      # сравнить
```

## Что реально работает (проверено запуском, не по README)

| Возможность | Команда | Результат |
|---|---|---|
| Markdown | `moli fetch --dump markdown --wait-until done URL` | ✅ exit 0, реальный контент |
| JS-рендеринг | CERN W3-страница | ✅ контент после исполнения JS |
| Точечный eval | `moli fetch --eval "document.title" URL` | ✅ `Example Domain` |
| Дерево ролей | `--dump semantic_tree_text` | ✅ роли/доступные имена |
| Метаданные | `--dump json` | ✅ `status`, `final_url`, `title`, `headers` |
| Скриншот | `moli fetch --layout --dump screenshot URL > f.png` | ✅ PNG 1920×1080 |
| Через Tor-прокси | SOCKS5 в `*_proxy` в env | ✅ работает |

`--dump json` удобен для проверки, что страница не заглушка:
```bash
moli fetch --dump json --wait-until done "$URL" | python3 -c \
 "import sys,json;d=json.load(sys.stdin);print(d['status'],d['title'])"
```

## 🐛 Найденный баг: line-height не вычисляется

**Симптом:** на `https://example.com` скриншот `--layout --dump screenshot`
сложил все пять абзацев в одну наложенную кучу вместо пяти строк.

**Причина:** в HTML страницы `line-height` отсутствует полностью
(`grep -c 'line-height'` → **0**), всё на дефолтном `normal`. Движок
не вычисляет нормальную высоту строки для `normal`.

**Границы проверенного (не переоценивать):** выборка всего из 3 страниц,
из них сломанная 1. Контрольные `info.cern.ch` и `rust-lang.org`
отрендерились корректно (верстка, цвета, градиент, навигация). Поэтому
системным багом движка это назвать нельзя — возможен частный случай
вложенности на example.com. Не проверялось, воспроизводится ли на других
сайтах без `line-height`.

**Практический вывод:**
- для текстовых задач (`markdown`, `semantic_tree_text`) почти не важно;
- **скриншоты нельзя принимать как доказательство вёрстки без визуальной
  проверки глазами** — они могут быть верны по структуре и сломаны по геометрии.

## Окружение

- В системе прописан Tor: `socks5://127.0.0.1:9050` во всех `*_proxy`.
  Moli через него работает, но при сбоях сети первой проверкой стоит
  пробовать `env -u http_proxy -u https_proxy -u ALL_PROXY -u all_proxy
  -u HTTP_PROXY -u HTTPS_PROXY moli ...`.
- Playwright и Puppeteer в системе **не установлены** — moli частично их
  заменяет, но для полноценной CDP-автоматизации их надо доставить отдельно.
- `--layout` платит за layout/paint. Для текстовых задач не включать.

## Безопасность при установке скиллов

Прогон `grep -rniE 'curl.*\| *sh|eval\(|base64 -d|api_key|token|password|exfil'`
по всем файлам даёт срабатывания, которые **ложные**: в
`moli-websearch/references/cdp-driver.md` и `imagesearch-engines.md`
упоминаются `api_key` / `X-CSRF-Token` / `x-api-key` — но это рецепты
reverse-image-search, где пользователь подставляет **свои** ключи к
сторонним сервисам (Lykdat, FuzzySearch, Picarta, Amazon StyleSnap).
Эксфильтрации, вредоносных команд и автоустановки в скиллах нет.

⚠️ Эти же recipes содержат рабочие эндпоинты загрузки в сторонние сервисы
(FuzzySearch, Lykdat, SearchThisImage, StyleSnap). При копировании в другие
окружения стоит перечитать перед использованием.

## Ссылки

- Репозиторий: https://github.com/lexmount/moli
- Релиз v1.1.11 опубликован 2026-09-26
