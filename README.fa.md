<p align="center">
  <img src="./pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# PixelCat Proxy

[中文](README.md) | [Русский](README.ru.md) | **فارسی**

PixelCat Proxy یک نصب‌کننده سه‌زبانه برای سرورهای لینوکس است. رابط برنامه به زبان‌های چینی، روسی و فارسی ارائه می‌شود و موارد زیر را نصب و نگهداری می‌کند:

- **NaiveProxy**: کدی (Caddy) با افزونه `github.com/klzgrad/forwardproxy@naive`، TLS، پروکسی HTTP/2 CONNECT، احراز هویت، probe resistance و سایت پوششی.
- **Hysteria2**: سرور رسمی Hysteria2 مبتنی بر QUIC/UDP همراه پرش پورت.
- **ابزارهای عیب‌یابی**: BBR، کیفیت IP، دسترسی سرویس‌های پخش و مسیر بازگشت شبکه.

از پروژه فقط به‌شکل قانونی استفاده کنید و قوانین محل، شرایط شرکت میزبانی و سیاست شبکه سازمان خود را رعایت کنید.

## معماری

| بخش | سرویس | پروتکل | پورت پیش‌فرض |
| --- | --- | --- | --- |
| NaiveProxy | `pixelcat-naiveproxy.service` | HTTPS/TCP | `443/tcp` |
| Hysteria2 | `pixelcat-hysteria2.service` | QUIC/UDP | `443/udp` |
| پرش پورت | `pixelcat-hysteria2-hop.service` | UDP DNAT | `20000-50000/udp` |

NaiveProxy و Hysteria2 می‌توانند از یک دامنه و شماره پورت استفاده کنند، زیرا اولی TCP و دومی UDP است.

## پیش‌نیازها

- لینوکس همراه systemd؛ مانند Debian، Ubuntu، توزیع‌های خانواده RHEL، Fedora یا Alpine.
- معماری `amd64` یا `arm64`.
- رکورد `A` یا `AAAA` دامنه باید به سرور اشاره کند.
- پورت‌های `80/tcp`، `443/tcp`، `443/udp` و در صورت استفاده از پرش پورت، `20000-50000/udp` را باز کنید.

## نصب سریع

اجرای مستقیم با رابط فارسی:

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash -s -- --lang fa
```

اگر مخزن از قبل روی سرور است:

```bash
./deploy.sh --lang fa
```

روش جایگزین با متغیر محیطی:

```bash
PIXELCAT_LANG=fa ./deploy.sh
```

اگر `--lang` وارد نشود، حالت تعاملی ابتدا زبان را می‌پرسد. زبان پیش‌فرض حالت غیرتعاملی چینی است.

## منو

```text
1) نصب / به‌روزرسانی PixelCat NaiveProxy
2) نصب / به‌روزرسانی PixelCat Hysteria2
3) حذف PixelCat NaiveProxy
4) حذف PixelCat Hysteria2
5) فعال‌کردن BBR
6) بررسی کیفیت IP
7) بررسی دسترسی سرویس‌های پخش
8) کیفیت شبکه / مسیر بازگشت
0) خروج
```

نمایش همه پارامترها:

```bash
./deploy.sh --lang fa --help
```

## نصب NaiveProxy

در منو گزینه `1` را انتخاب کنید و دامنه، نام کاربری، گذرواژه قوی، دامنه سایت پوششی، ایمیل گواهی و پورت‌ها را وارد کنید. دامنه پوششی را بدون `https://` بنویسید.

نمونه غیرتعاملی:

```bash
./deploy.sh --lang fa --install -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

برای سرور عملیاتی بهتر است گذرواژه را تعاملی وارد کنید؛ مقدار `--password` ممکن است در تاریخچه shell یا فهرست پردازش‌ها باقی بماند.

## نصب Hysteria2

در منو گزینه `2` را انتخاب کنید. اگر NaiveProxy نصب باشد، اسکریپت می‌تواند دامنه، گذرواژه و گواهی کدی را دوباره استفاده کند.

```bash
./deploy.sh --lang fa --install-hysteria2 -y \
  --hy2-domain proxy.example.com \
  --hy2-port 443 \
  --hy2-hop-range 20000-50000 \
  --hy2-up-mbps 0 \
  --hy2-down-mbps 0 \
  --hy2-masquerade https://www.example.com
```

`--hy2-hop-range off` پرش پورت را غیرفعال می‌کند. مقدار سرعت `0` به معنی نامحدود است.

## بررسی سرویس‌ها

```bash
systemctl status pixelcat-naiveproxy --no-pager
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-naiveproxy -f
journalctl -u pixelcat-hysteria2 -f
ss -lntup
```

## به‌روزرسانی و حذف

اجرای دوباره `install.sh` نسخه تازه را دریافت می‌کند. برای حذف:

```bash
./deploy.sh --lang fa --uninstall
./deploy.sh --lang fa --uninstall-hysteria2
```

فقط زمانی `--purge` را اضافه کنید که قصد حذف فایل‌های پیکربندی محلی و داده‌های ذکرشده در پیام تأیید را دارید.

## پیوندها

- وب‌سایت: [pixelcat.icu](https://pixelcat.icu)
- YouTube: [@PixelCatICU](https://www.youtube.com/@PixelCatICU)
- GitHub: [PixelCatICU](https://github.com/PixelCatICU)
- X: [@PixelCatICU](https://x.com/PixelCatICU)
- مجوز: GNU GPL v3.0
