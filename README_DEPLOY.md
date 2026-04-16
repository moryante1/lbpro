# LoadBalancer Pro — دليل التثبيت الكامل

## متطلبات النظام
| المتطلب | الإصدار |
|---------|---------|
| Ubuntu  | 22.04 LTS |
| PHP     | 8.3 FPM |
| MySQL   | 8.0 |
| Nginx   | 1.18+ |
| RAM     | 1 GB minimum / 2 GB مُوصى |
| Storage | 10 GB+ |

---

## الخطوة 1 — تحميل الملفات على الخادم

### الطريقة أ: عبر SCP من جهازك
```bash
# من جهازك المحلي:
scp -r ./lbpro/ user@YOUR_SERVER_IP:/tmp/lbpro

# على الخادم:
sudo mv /tmp/lbpro /var/www/
```

### الطريقة ب: عبر Git
```bash
# على الخادم:
cd /var/www
sudo git clone https://github.com/YOUR_REPO/lbpro.git
```

### الطريقة ج: ضغط وتحميل
```bash
# من جهازك — ضغط المشروع:
zip -r lbpro.zip lbpro/

# رفع على الخادم:
scp lbpro.zip user@YOUR_SERVER_IP:/tmp/

# على الخادم:
cd /var/www && sudo unzip /tmp/lbpro.zip
```

---

## الخطوة 2 — تشغيل سكريبت التثبيت

```bash
# الدخول للخادم
ssh user@YOUR_SERVER_IP

# الانتقال لمجلد المشروع
cd /var/www/lbpro

# منح صلاحية التنفيذ
chmod +x install.sh

# تشغيل التثبيت (يحتاج root)
sudo bash install.sh
```

### ماذا يفعل install.sh تلقائياً؟
1. تحديث حزم Ubuntu
2. تثبيت Nginx + PHP 8.3 FPM + MySQL 8.0 + Redis
3. إنشاء قاعدة البيانات والمستخدم
4. نسخ ملفات المشروع إلى `/var/www/lbpro`
5. إعداد ملف config.php بالبيانات المُدخلة
6. استيراد مخطط قاعدة البيانات (schema.sql)
7. إنشاء مستخدم admin
8. ضبط Nginx virtual host
9. ضبط صلاحيات sudo لأوامر الشبكة
10. تفعيل IP Forwarding وكرنل parameters
11. إعداد Cron Jobs للمراقبة
12. تحميل وحدة VLAN (8021q)

---

## الخطوة 3 — الوصول للوحة التحكم

بعد انتهاء التثبيت:
```
http://YOUR_SERVER_IP
المستخدم: admin
كلمة المرور: (ما أدخلته أو المُولَّدة تلقائياً)
```

---

## هيكل الملفات

```
/var/www/lbpro/
├── install.sh              ← سكريبت التثبيت
├── config/
│   ├── config.php          ← الإعدادات الرئيسية (auto-generated)
│   └── schema.sql          ← مخطط قاعدة البيانات
├── includes/
│   ├── bootstrap.php       ← تحميل كل الأصناف
│   ├── Database.php        ← PDO wrapper
│   ├── Auth.php            ← Session + API Key auth
│   ├── Network.php         ← عمليات الشبكة
│   └── Logger.php          ← سجل الأحداث + Response helper
├── api/
│   └── index.php           ← REST API router كامل
├── public/
│   ├── index.php           ← الواجهة الرئيسية
│   ├── login.php           ← صفحة تسجيل الدخول
│   ├── logout.php
│   ├── auth/
│   │   └── change-password.php
│   ├── pages/
│   │   ├── dashboard.php   ← لوحة التحكم
│   │   ├── interfaces.php  ← الواجهات
│   │   ├── vlans.php       ← VLANs
│   │   ├── pppoe.php       ← PPPoE
│   │   ├── dhcp.php        ← DHCP Server
│   │   ├── static.php      ← Static IP & Routes
│   │   ├── loadbalancer.php← Load Balancer
│   │   ├── routing.php     ← Routing Table
│   │   ├── api.php         ← API Manager
│   │   ├── logs.php        ← System Logs
│   │   └── settings.php    ← الإعدادات
│   └── assets/
│       ├── css/app.css     ← كل الأنماط
│       └── js/app.js       ← JavaScript
└── cron/
    ├── monitor.php         ← مراقبة الخطوط (كل 30 ثانية)
    ├── daily_stats.php     ← إحصائيات يومية
    └── cleanup.php         ← تنظيف قاعدة البيانات
```

---

## REST API — أمثلة عملية

### استيراد حالة الخطوط
```bash
curl -H "X-API-Key: lbpro_xxxx" http://YOUR_IP/api/v1/interfaces
```

### إضافة VLAN
```bash
curl -X POST http://YOUR_IP/api/v1/vlans \
  -H "X-API-Key: lbpro_xxxx" \
  -H "Content-Type: application/json" \
  -d '{"vlan_id":50,"name":"DMZ","interface_id":1,"ip_address":"10.0.50.1","subnet":24}'
```

### تحديث أوزان Load Balancer
```bash
curl -X PUT http://YOUR_IP/api/v1/loadbalancer/weights \
  -H "X-API-Key: lbpro_xxxx" \
  -H "Content-Type: application/json" \
  -d '{"weights":{"1":8,"2":4,"3":2}}'
```

### الإحصائيات اللحظية
```bash
curl -H "X-API-Key: lbpro_xxxx" http://YOUR_IP/api/v1/stats/realtime
```

---

## الأوامر المفيدة بعد التثبيت

```bash
# مراقبة السجلات
tail -f /var/www/lbpro/logs/system.log
tail -f /var/log/nginx/lbpro_access.log
tail -f /var/log/nginx/lbpro_error.log

# إعادة تشغيل الخدمات
sudo systemctl restart nginx php8.3-fpm mysql

# حالة الخدمات
sudo systemctl status nginx php8.3-fpm mysql redis-server

# قراءة جدول التوجيه
ip route show

# مراقبة الواجهات
ip link show
ip addr show

# اختبار PPPoE يدوي
sudo pppd call lbpro_eth0

# مراقبة Traffic
iftop -n -i eth0
```

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| صفحة 502 Bad Gateway | `sudo systemctl restart php8.3-fpm` |
| خطأ قاعدة البيانات | تحقق من `config/config.php` وبيانات MySQL |
| PPPoE لا يتصل | تحقق من `/var/log/syslog` و `/var/run/ppp-eth*.pid` |
| VLAN لا يظهر | `modprobe 8021q` ثم `ip link show` |
| صلاحيات رفض | `sudo visudo` وتحقق من `/etc/sudoers.d/lbpro` |
| Cron لا يعمل | `crontab -l -u www-data` |

---

## HTTPS / SSL (موصى به في الإنتاج)

```bash
# تثبيت Certbot
sudo apt install certbot python3-certbot-nginx -y

# الحصول على شهادة (تحتاج domain حقيقي)
sudo certbot --nginx -d yourdomain.com

# تجديد تلقائي
sudo crontab -e
# أضف: 0 12 * * * certbot renew --quiet
```

---

## الأمان في الإنتاج

```bash
# تغيير كلمة admin فوراً من لوحة التحكم
# الإعدادات > تغيير كلمة المرور

# إغلاق المنافذ غير الضرورية
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 3306/tcp  # MySQL — داخلي فقط

# تشفير config.php
sudo chmod 600 /var/www/lbpro/config/config.php
```

---
**LoadBalancer Pro v2.4.1 | Ubuntu 22.04 LTS**
