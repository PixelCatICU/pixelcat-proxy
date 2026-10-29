<p align="center"><img src="./pixel-cat.svg" alt="PixelCat" width="120" /></p>

# PixelCat Proxy

[中文](README.md) | **Русский** | [فارسی](README.fa.md)

Установка и обслуживание NaiveProxy / Hysteria2 на Linux, трёхъязычное меню, диагностика и одноразовая выдача конфигурации sing-box.

## Возможности и требования

- NaiveProxy: Caddy + `klzgrad/forwardproxy@naive`, TLS, HTTP/2 CONNECT, аутентификация и маскировка.
- Hysteria2: официальный сервер, смена UDP-портов, повторное использование сертификата Caddy.
- BBR, качество IP, доступность стриминга и обратный маршрут.
- Случайная HTTPS-ссылка с ограниченным сроком и однократной выдачей.

Нужны Linux, Bash, systemd, root или sudo; amd64 / arm64. Подойдут Debian, Ubuntu, RHEL-подобные системы и Fedora с systemd. Обычный Alpine/OpenRC не подходит для управления сервисами этим скриптом. Для ссылок нужны Python 3.7+, файл `one_time_link.py` из полного проекта и работающий PixelCat Caddy HTTPS.

Направьте A/AAAA на сервер и откройте порты в системном и облачном межсетевом экране:

| Назначение | Порт |
| --- | --- |
| HTTP / сертификат | `80/tcp` |
| NaiveProxy / выдача | `443/tcp` |
| Hysteria2 | `443/udp` |
| Смена портов, необязательно | `20000-50000/udp` |

TCP и UDP могут использовать один домен и номер порта. Выдача слушает `127.0.0.1:18765`; этот порт не нужно открывать наружу.

## Быстрый старт

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash -s -- --lang ru
```

Проект загружается в `/opt/pixelcat/pixelcat-naiveproxy`; существующие `.env*` сохраняются, затем открывается меню.

```bash
cd /opt/pixelcat/pixelcat-naiveproxy
./deploy.sh --lang ru
./deploy.sh --lang ru --help
```

Языки: `zh`, `ru`, `fa`; также доступно `PIXELCAT_LANG=ru ./deploy.sh`.

## Меню

| Пункт | Действие |
| --- | --- |
| 1 / 2 | Установка или обновление NaiveProxy / Hysteria2 |
| 3 / 4 | Удаление NaiveProxy / Hysteria2 |
| 5 | BBR |
| 6 | Качество IP |
| 7 | Доступность стриминга |
| 8 | Сеть / обратный маршрут |
| 9 | Одноразовая ссылка sing-box |
| 0 | Выход |

## Установка узлов

Вводите пароли интерактивно, чтобы не сохранять их в истории shell или аргументах процесса.

```bash
./deploy.sh --lang ru --install
./deploy.sh --lang ru --install-hysteria2
```

NaiveProxy требует домен, пользователя, пароль и домен маскировки; email необязателен. Домен маскировки вводится без протокола и должен отличаться от домена прокси.

HTTP-запросы, в том числе по IP сервера, перенаправляются с кодом 308 на HTTPS настроенного домена прокси с сохранением пути, параметров и нестандартного HTTPS-порта. Для прямого HTTPS по IP по-прежнему нужен соответствующий сертификат. Для обновления существующей установки скачайте новый скрипт и повторите `./deploy.sh --install`: Caddyfile будет перезаписан, а сервис перезапущен.

Hysteria2 использует домен и пароль из NaiveProxy `.env`, если они есть; иначе запрашивает домен и генерирует пароль. По умолчанию UDP 443, диапазон 20000-50000, скорость 0 (без ограничения), маскировка из NaiveProxy либо https://www.bing.com.

```bash
./deploy.sh --install-hysteria2 --hy2-hop-range off
./deploy.sh --install --build-from-source
./deploy.sh --install --skip-start
```

- `--hy2-hop-range off` отключает смену портов; `--hy2-hop-iface` задаёт интерфейс.
- `--hy2-port`, `--hy2-up-mbps`, `--hy2-down-mbps`, `--hy2-masquerade` меняют значения по умолчанию.
- `--build-from-source` принудительно собирает Caddy через Go + xcaddy. Готовые архивы проверяются по SHA-256 и наличию forward_proxy; при ошибке выполняется локальная сборка.
- `--skip-start` создаёт конфигурацию без запуска; доступен и для Hysteria2.

Сначала ищется сертификат Caddy для того же домена, затем выполняется попытка выпуска. Резервный ACME Hysteria2 требует доступного TCP 443. Работающий Caddy без подходящего сертификата может потребовать ручной проверки. Смена портов использует nftables с резервным iptables.

## Клиент

После установки выводится полный sing-box JSON. Сохраните объект целиком в `config.json` и импортируйте локально.

**Вход — mixed на `127.0.0.1:2080` (HTTP/SOCKS), без TUN/DNS для системного VPN телефона. Это не подписка Shadowrocket.** Установка сервиса не подтверждает клиентское соединение. JSON содержит пароли: не публикуйте его.

## Одноразовая выдача

В каталоге с `.env` / `.env.hysteria2` выберите пункт 9 или выполните:

```bash
cd /opt/pixelcat/pixelcat-naiveproxy
./deploy.sh --lang ru --one-time-link
./deploy.sh --lang ru --one-time-link --link-ttl 300
```

Формат: `https://proxy.example.com:443/pixelcat-once/<random-key>`.

- Срок 600 секунд, допустимо 30–3600.
- Первый подходящий GET расходует ссылку даже при обрыве загрузки. HEAD и неверный ключ не расходуют её.
- Новая ссылка отменяет старую. Не запускайте генерацию одновременно.
- Сохраните результат локально. Не открывайте ссылку для предпросмотра: повторные запросы и обновления подписки не работают.
- Объединяются узлы с существующими файлами окружения и сервисов; NaiveProxy имеет приоритет. Формат остаётся mixed JSON.
- Отмена: `sudo systemctl stop pixelcat-once.service`.

### Поведение сервиса

Ключ случайный, 256 бит. Файл подготовки имеет права 0600 и удаляется после чтения; данные остаются в памяти. Временный сервис завершается по сроку. Пути запросов не записываются, кеширование запрещается заголовками. Проверьте также журналы и кеш внешнего CDN/прокси.

Caddyfile проверяется и резервируется, затем Caddy перезапускается; соединения могут прерваться. При ошибке скрипт пытается восстановить файл и сервис. Пользовательские журналы или неподдерживаемые маршруты блокируют автоматическое изменение. Переустановка/удаление NaiveProxy переписывает Caddyfile; при необходимости создайте ссылку заново.

Одноразовость не защищает от получения ссылки другим человеком раньше вас и не отзывает скачанные пароли. При утечке смените пароль узла.

## Обслуживание и удаление

```bash
systemctl status pixelcat-naiveproxy --no-pager
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-naiveproxy -f
journalctl -u pixelcat-hysteria2 -f
systemctl restart pixelcat-naiveproxy
systemctl restart pixelcat-hysteria2
```

| Данные | Путь |
| --- | --- |
| Переменные | `.env`, `.env.hysteria2` в проекте |
| Caddy | `/etc/pixelcat-naiveproxy/Caddyfile`, `/var/lib/pixelcat-naiveproxy` |
| Hysteria2 | `/etc/pixelcat-hysteria2/config.yaml`, `/var/lib/pixelcat-hysteria2` |
| Выдача | `/usr/local/bin/pixelcat-one-time-link.py` |

Повторный запуск установщика обновляет скрипты; затем выберите установку нужного сервиса.

```bash
./deploy.sh --lang ru --uninstall
./deploy.sh --lang ru --uninstall-hysteria2
```

Удаление NaiveProxy сохраняет Caddy, сертификаты и маскировку; `--purge` удаляет локальный `.env`. Hysteria2 сохраняет конфигурацию и сертификаты; `--purge` удаляет их вместе с `.env.hysteria2`. Выдачу ссылки останавливайте отдельно.

## Диагностика и разработка

```bash
./deploy.sh --bbr
./deploy.sh --ip-quality
./deploy.sh --unlock-check
./deploy.sh --net-quality
bash tests/i18n-smoke.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

Источники: [IPQuality](https://github.com/xykt/IPQuality), [RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck), [NetQuality](https://github.com/xykt/NetQuality). Перед запуском показываются URL и SHA-256; интерактивно требуется подтверждение, `-y` и неинтерактивный режим продолжают автоматически.

Тесты проверяют конкурентность, неверные ключи, срок, HEAD/GET, объединение JSON и изменение текста Caddy. Они не заменяют проверку systemd, сертификатов и клиентской сети на Linux.

Сборка: Caddy `v2.11.4`, xcaddy `v0.4.5`, forwardproxy `naive`; переменные `CADDY_VERSION`, `XCADDY_VERSION`, `CADDY_FORWARDPROXY_REF`. Release или ручной Actions `Build PixelCat Caddy` создаёт amd64/arm64 архивы и контрольные суммы.

## Ссылки

[Сайт](https://pixelcat.icu) · [YouTube](https://www.youtube.com/@PixelCatICU) · [GitHub](https://github.com/PixelCatICU) · [X](https://x.com/PixelCatICU)

Лицензия: [GNU GPL v3.0](LICENSE).
