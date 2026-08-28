<p align="center">
  <img src="./pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# PixelCat Proxy

[中文](README.md) | **Русский** | [فارسی](README.fa.md)

PixelCat Proxy — трёхъязычный установщик для Linux-серверов. Интерфейс доступен на китайском, русском и персидском языках. Проект развёртывает и обслуживает:

- **NaiveProxy**: Caddy с модулем `github.com/klzgrad/forwardproxy@naive`, TLS, HTTP/2 CONNECT, Basic Auth, probe resistance и сайтом-маскировкой.
- **Hysteria2**: официальный сервер Hysteria2 на QUIC/UDP со сменой портов.
- **Диагностику**: BBR, качество IP, разблокировку стриминговых сервисов и обратный маршрут.

Используйте проект только законным способом. Соблюдайте местное законодательство, условия хостинга и сетевые правила вашей организации.

## Архитектура

| Компонент | Сервис | Протокол | Порт по умолчанию |
| --- | --- | --- | --- |
| NaiveProxy | `pixelcat-naiveproxy.service` | HTTPS/TCP | `443/tcp` |
| Hysteria2 | `pixelcat-hysteria2.service` | QUIC/UDP | `443/udp` |
| Смена портов | `pixelcat-hysteria2-hop.service` | UDP DNAT | `20000-50000/udp` |

NaiveProxy и Hysteria2 могут использовать один домен и номер порта, потому что первый работает по TCP, а второй — по UDP.

## Требования

- Linux с systemd: Debian, Ubuntu, RHEL-подобная система, Fedora или Alpine.
- Архитектура `amd64` или `arm64`.
- Запись `A` или `AAAA` домена должна указывать на сервер.
- Откройте `80/tcp`, `443/tcp`, `443/udp` и, при смене портов, `20000-50000/udp`.

## Быстрая установка

Запуск сразу на русском языке:

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash -s -- --lang ru
```

Если репозиторий уже находится на сервере:

```bash
./deploy.sh --lang ru
```

Альтернативно используйте переменную окружения:

```bash
PIXELCAT_LANG=ru ./deploy.sh
```

Без `--lang` интерактивный режим показывает выбор языка. В неинтерактивном режиме язык по умолчанию — китайский.

## Меню

```text
1) Установить / обновить PixelCat NaiveProxy
2) Установить / обновить PixelCat Hysteria2
3) Удалить PixelCat NaiveProxy
4) Удалить PixelCat Hysteria2
5) Включить BBR
6) Проверка качества IP
7) Проверка разблокировки стриминга
8) Качество сети / обратный маршрут
0) Выход
```

Все параметры:

```bash
./deploy.sh --lang ru --help
```

## Установка NaiveProxy

В меню выберите `1` и укажите домен, имя пользователя, надёжный пароль, домен сайта-маскировки, email сертификата и порты. Домен маскировки вводится без `https://`.

Неинтерактивный пример:

```bash
./deploy.sh --lang ru --install -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

Для рабочего сервера безопаснее вводить пароль интерактивно: значение `--password` может остаться в истории shell или списке процессов.

## Установка Hysteria2

В меню выберите `2`. Если NaiveProxy уже установлен, скрипт может повторно использовать домен, пароль и сертификат Caddy.

```bash
./deploy.sh --lang ru --install-hysteria2 -y \
  --hy2-domain proxy.example.com \
  --hy2-port 443 \
  --hy2-hop-range 20000-50000 \
  --hy2-up-mbps 0 \
  --hy2-down-mbps 0 \
  --hy2-masquerade https://www.example.com
```

`--hy2-hop-range off` отключает смену портов. Значение `0` для скорости означает отсутствие лимита.

## Проверка

```bash
systemctl status pixelcat-naiveproxy --no-pager
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-naiveproxy -f
journalctl -u pixelcat-hysteria2 -f
ss -lntup
```

## Обновление и удаление

Повторный запуск `install.sh` загружает актуальную версию. Для удаления:

```bash
./deploy.sh --lang ru --uninstall
./deploy.sh --lang ru --uninstall-hysteria2
```

Добавляйте `--purge` только если хотите удалить локальные файлы конфигурации и данные, перечисленные в запросе подтверждения.

## Ссылки

- Сайт: [pixelcat.icu](https://pixelcat.icu)
- YouTube: [@PixelCatICU](https://www.youtube.com/@PixelCatICU)
- GitHub: [PixelCatICU](https://github.com/PixelCatICU)
- X: [@PixelCatICU](https://x.com/PixelCatICU)
- Лицензия: GNU GPL v3.0
