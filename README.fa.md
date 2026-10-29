<p align="center"><img src="./pixel-cat.svg" alt="PixelCat" width="120" /></p>

# PixelCat Proxy

[中文](README.md) | [Русский](README.ru.md) | **فارسی**

اسکریپت نصب و نگهداری NaiveProxy و Hysteria2 برای لینوکس، با منوی سه‌زبانه، ابزارهای بررسی شبکه و لینک دریافت یک‌بارمصرف sing-box.

## قابلیت‌ها و پیش‌نیازها

- NaiveProxy: سرویس Caddy با `klzgrad/forwardproxy@naive`، TLS، HTTP/2 CONNECT، احراز هویت و سایت پوششی.
- Hysteria2: سرور رسمی با پرش پورت UDP و استفاده مجدد از گواهی Caddy.
- BBR، کیفیت IP، دسترسی سرویس‌های پخش و مسیر بازگشت.
- لینک HTTPS تصادفی با اعتبار محدود و حداکثر یک دریافت.

به Linux، Bash، systemd و root یا sudo نیاز است؛ amd64 و arm64 پشتیبانی می‌شوند. Debian، Ubuntu و خانواده RHEL / Fedora همراه systemd مناسب‌اند. Alpine معمولی با OpenRC برای مدیریت سرویس‌ها مناسب نیست. لینک یک‌بارمصرف به Python 3.7+، فایل `one_time_link.py` از پروژه کامل و سرویس فعال PixelCat Caddy HTTPS نیاز دارد.

رکورد A/AAAA را به سرور وصل و پورت‌ها را در فایروال سیستم و ابر باز کنید:

| کاربرد | پورت |
| --- | --- |
| HTTP و گواهی | `80/tcp` |
| NaiveProxy و دریافت پیکربندی | `443/tcp` |
| Hysteria2 | `443/udp` |
| پرش پورت اختیاری | `20000-50000/udp` |

TCP و UDP می‌توانند دامنه و شماره پورت یکسان داشته باشند. سرویس دریافت تنها روی `127.0.0.1:18765` است؛ این پورت نیازی به دسترسی عمومی ندارد.

## شروع سریع

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash -s -- --lang fa
```

پروژه کامل در `/opt/pixelcat/pixelcat-naiveproxy` دریافت می‌شود، `.env*` موجود حفظ می‌شود و منو باز می‌شود.

```bash
cd /opt/pixelcat/pixelcat-naiveproxy
./deploy.sh --lang fa
./deploy.sh --lang fa --help
```

زبان‌ها `zh`، `ru` و `fa` هستند؛ `PIXELCAT_LANG=fa ./deploy.sh` هم قابل استفاده است.

## منو

| گزینه | عملکرد |
| --- | --- |
| 1 / 2 | نصب یا به‌روزرسانی NaiveProxy / Hysteria2 |
| 3 / 4 | حذف NaiveProxy / Hysteria2 |
| 5 | فعال‌کردن BBR |
| 6 | کیفیت IP |
| 7 | دسترسی سرویس‌های پخش |
| 8 | شبکه و مسیر بازگشت |
| 9 | لینک یک‌بارمصرف sing-box |
| 0 | خروج |

## نصب گره‌ها

رمز را تعاملی وارد کنید تا در تاریخچه shell یا آرگومان پردازش نماند.

```bash
./deploy.sh --lang fa --install
./deploy.sh --lang fa --install-hysteria2
```

NaiveProxy به دامنه، نام کاربری، رمز و دامنه پوششی نیاز دارد؛ ایمیل اختیاری است. دامنه پوششی باید بدون پروتکل و متفاوت از دامنه پروکسی باشد.

درخواست‌های HTTP، از جمله دسترسی با IP سرور، با کد 308 به HTTPS دامنهٔ تنظیم‌شدهٔ پروکسی هدایت می‌شوند؛ مسیر، پارامترهای پرس‌وجو و پورت غیراستاندارد HTTPS حفظ می‌شوند. دسترسی مستقیم HTTPS با IP همچنان به گواهی منطبق نیاز دارد. برای اعمال تغییر در نصب موجود، اسکریپت جدید را دریافت و `./deploy.sh --install` را دوباره اجرا کنید؛ Caddyfile بازنویسی و سرویس راه‌اندازی مجدد می‌شود.

Hysteria2 دامنه و رمز را در صورت وجود از `.env` مربوط به NaiveProxy می‌گیرد؛ در غیر این صورت دامنه را می‌پرسد و رمز می‌سازد. پیش‌فرض UDP 443، بازه 20000-50000، سرعت 0 (نامحدود) و سایت پوششی NaiveProxy یا https://www.bing.com است.

```bash
./deploy.sh --install-hysteria2 --hy2-hop-range off
./deploy.sh --install --build-from-source
./deploy.sh --install --skip-start
```

- `--hy2-hop-range off` پرش را غیرفعال می‌کند؛ `--hy2-hop-iface` رابط را مشخص می‌کند.
- `--hy2-port`، `--hy2-up-mbps`، `--hy2-down-mbps` و `--hy2-masquerade` پیش‌فرض‌ها را عوض می‌کنند.
- `--build-from-source` ساخت محلی Caddy با Go و xcaddy را اجباری می‌کند. نسخه آماده با SHA-256 و افزونه forward_proxy بررسی و در شکست، محلی ساخته می‌شود.
- `--skip-start` تنظیمات را بدون شروع سرویس می‌سازد؛ برای Hysteria2 هم قابل استفاده است.

ابتدا گواهی هم‌دامنه Caddy جست‌وجو و سپس صدور امتحان می‌شود. ACME جایگزین Hysteria2 به TCP 443 آزاد نیاز دارد. Caddy فعال بدون گواهی مناسب ممکن است بررسی دستی بخواهد. پرش پورت ابتدا nftables و سپس iptables را استفاده می‌کند.

## کلاینت

پس از نصب، JSON کامل sing-box چاپ می‌شود. شیء را با تمام آکولادها در `config.json` ذخیره و محلی وارد کنید.

**ورودی mixed روی `127.0.0.1:2080` برای HTTP/SOCKS است؛ TUN/DNS موردنیاز VPN سراسری گوشی را ندارد و اشتراک Shadowrocket نیست.** نصب موفق سرویس اتصال کلاینت را تأیید نمی‌کند. JSON حاوی رمز است؛ عمومی نکنید.

## دریافت یک‌بارمصرف

در پوشه دارای `.env` / `.env.hysteria2` گزینه ۹ را انتخاب یا اجرا کنید:

```bash
cd /opt/pixelcat/pixelcat-naiveproxy
./deploy.sh --lang fa --one-time-link
./deploy.sh --lang fa --one-time-link --link-ttl 300
```

قالب: `https://proxy.example.com:443/pixelcat-once/<random-key>`.

- اعتبار پیش‌فرض ۶۰۰ ثانیه و بازه مجاز ۳۰ تا ۳۶۰۰ ثانیه است.
- اولین GET معتبر لینک را مصرف می‌کند، حتی اگر دانلود قطع شود. HEAD و کلید اشتباه مصرف نمی‌کنند.
- لینک جدید قبلی را لغو می‌کند؛ هم‌زمان در چند ترمینال تولید نکنید.
- نتیجه را محلی ذخیره کنید. لینک را پیش‌نمایش نکنید؛ تلاش مجدد یا تازه‌سازی اشتراک شکست می‌خورد.
- گره‌های دارای فایل محیط و سرویس ادغام می‌شوند؛ NaiveProxy اولویت دارد. خروجی همان mixed JSON است.
- لغو: `sudo systemctl stop pixelcat-once.service`.

### رفتار سرویس

کلید تصادفی ۲۵۶ بیتی است. فایل آماده‌سازی مجوز 0600 دارد و پس از خواندن حذف می‌شود؛ محتوا در حافظه می‌ماند. سرویس موقت پس از انقضا خارج می‌شود. مسیر درخواست ثبت نمی‌شود و پاسخ هدر منع کش دارد. لاگ و کش CDN یا پراکسی بالادستی را جداگانه بررسی کنید.

Caddyfile اعتبارسنجی و پشتیبان‌گیری می‌شود و Caddy دوباره راه‌اندازی می‌شود؛ اتصال‌های جاری ممکن است قطع شوند. در شکست، بازگرداندن فایل و سرویس امتحان می‌شود. لاگ سفارشی یا مسیر ناسازگار مانع تغییر خودکار است. نصب یا حذف دوباره NaiveProxy فایل Caddyfile را بازنویسی می‌کند؛ در صورت نیاز لینک جدید بسازید.

یک‌بارمصرف بودن مانع دریافت زودتر توسط دیگری نمی‌شود و رمز دانلودشده را پس نمی‌گیرد. در صورت افشا رمز گره را تغییر دهید.

## نگهداری و حذف

```bash
systemctl status pixelcat-naiveproxy --no-pager
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-naiveproxy -f
journalctl -u pixelcat-hysteria2 -f
systemctl restart pixelcat-naiveproxy
systemctl restart pixelcat-hysteria2
```

| داده | مسیر |
| --- | --- |
| متغیرها | `.env` و `.env.hysteria2` در پروژه |
| Caddy | `/etc/pixelcat-naiveproxy/Caddyfile` و `/var/lib/pixelcat-naiveproxy` |
| Hysteria2 | `/etc/pixelcat-hysteria2/config.yaml` و `/var/lib/pixelcat-hysteria2` |
| برنامه دریافت | `/usr/local/bin/pixelcat-one-time-link.py` |

اجرای دوباره نصب‌کننده اسکریپت‌ها را به‌روز می‌کند؛ سپس نصب سرویس را انتخاب کنید.

```bash
./deploy.sh --lang fa --uninstall
./deploy.sh --lang fa --uninstall-hysteria2
```

حذف NaiveProxy سرویس Caddy، گواهی و پوشش را نگه می‌دارد؛ `--purge` فایل محلی `.env` را حذف می‌کند. Hysteria2 تنظیمات و گواهی را نگه می‌دارد؛ `--purge` آن‌ها و `.env.hysteria2` را پاک می‌کند. سرویس دریافت را جداگانه متوقف کنید.

## عیب‌یابی و توسعه

```bash
./deploy.sh --bbr
./deploy.sh --ip-quality
./deploy.sh --unlock-check
./deploy.sh --net-quality
bash tests/i18n-smoke.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

منابع: [IPQuality](https://github.com/xykt/IPQuality)، [RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck)، [NetQuality](https://github.com/xykt/NetQuality). قبل از اجرا URL و SHA-256 نمایش داده می‌شود؛ حالت تعاملی تأیید می‌خواهد و `-y` یا حالت غیرتعاملی خودکار ادامه می‌دهد.

تست‌ها هم‌زمانی، کلید اشتباه، انقضا، HEAD/GET، ادغام JSON و تغییر متن Caddy را بررسی می‌کنند؛ جای آزمایش systemd، گواهی و اتصال واقعی در لینوکس را نمی‌گیرند.

ساخت پیش‌فرض: Caddy `v2.11.7`، xcaddy `v0.4.7` و forwardproxy `naive`. متغیرها: `CADDY_VERSION`، `XCADDY_VERSION`، `CADDY_FORWARDPROXY_REF`. Release یا Actions دستی `Build PixelCat Caddy` آرشیو amd64/arm64 و فایل صحت‌سنجی می‌سازد.

نسخهٔ پیش‌فرض Hysteria2 برابر `app/v2.13.0` است و با `HY2_VERSION` یا `HY2_RELEASE_BASE_URL` تغییر می‌کند. ساخت CI از Go `1.27.3` استفاده می‌کند؛ ساخت محلی حداقل Go 1.26 می‌خواهد و ابزار قدیمی را به‌روز می‌کند. نصب مجدد، Caddy و xcaddy ناسازگار با نسخهٔ انتخابی را به‌روز می‌کند؛ بستهٔ آمادهٔ قدیمی Caddy باعث ساخت از سورس می‌شود. گزینهٔ `--build-from-source` ساخت مجدد را اجباری می‌کند.

## پیوندها

[وب‌سایت](https://pixelcat.icu) · [YouTube](https://www.youtube.com/@PixelCatICU) · [GitHub](https://github.com/PixelCatICU) · [X](https://x.com/PixelCatICU)

مجوز: [GNU GPL v3.0](LICENSE).
