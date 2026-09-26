# -*- coding: utf-8 -*-
"""Деплой веб-сборки игры на ВМ: nginx + Let's Encrypt + бесплатный хостнейм.

Креды берутся из .env в корне проекта (строки вида "# ssh root@1.2.3.4" и пароль).
Бесплатный хостнейм строится по IP: 31-130-128-81.sslip.io (или nip.io как запас).
Сертификат — Let's Encrypt через certbot (HTTP-01), затем редирект http -> https.

Примеры:
    python tools/deploy/deploy.py probe            # что уже стоит на ВМ
    python tools/deploy/deploy.py all              # загрузить сборку, nginx, сертификат
    python tools/deploy/deploy.py upload nginx     # по шагам
    python tools/deploy/deploy.py cert --domain x.sslip.io
"""
from __future__ import annotations

import argparse
import hashlib
import os
import posixpath
import shlex
import socket
import sys
import time

import paramiko

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ENV_PATH = os.path.join(ROOT, ".env")
BUILD_DIR = os.path.join(ROOT, "build", "web")
REMOTE_DIR = "/var/www/zone"
SITE_NAME = "zone"

## index.html — точка входа: грузим его последним, когда остальные файлы новой сборки
## уже на месте. Иначе клиент, зашедший в середине деплоя, получит новую страницу
## со старым index.pck (движок стартует, но меню/менюшка виснет до перезагрузки).
UPLOAD_LAST = ("index.html",)


def read_env() -> tuple[str, str, int]:
    """Возвращает (host, password, port) из .env."""
    host, password, port = "", "", 22
    with open(ENV_PATH, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            clean = line.lstrip("#").strip()
            if "root@" in clean:
                tail = clean.split("root@", 1)[1].strip()
                host = tail.split()[0]
                if ":" in host:
                    host, port_s = host.split(":", 1)
                    port = int(port_s)
            elif host and password == "" and " " not in clean:
                password = clean
    if not host:
        raise SystemExit("Не нашёл строку 'ssh root@<ip>' в .env")
    if not password:
        raise SystemExit("Не нашёл пароль в .env")
    return host, password, port


def free_hostname(ip: str) -> list[str]:
    dashed = ip.replace(".", "-")
    return [f"{dashed}.sslip.io", f"{ip}.nip.io"]


def sha256_file(path: str, chunk: int = 1048576) -> str:
    """SHA-256 файла: по нему решаем, что уже лежит на ВМ и не нужно гнать по сети."""
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(chunk), b""):
            digest.update(block)
    return digest.hexdigest()


class Remote:
    def __init__(self, host: str, password: str, port: int = 22) -> None:
        self.host = host
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(hostname=host, port=port, username="root", password=password,
                            timeout=25, banner_timeout=25, auth_timeout=25)
        self.sftp = self.client.open_sftp()

    def run(self, cmd: str, check: bool = False, quiet: bool = False) -> tuple[int, str]:
        if not quiet:
            print(f"    $ {cmd}")
        _in, out, err = self.client.exec_command(cmd, timeout=900)
        text = out.read().decode("utf-8", "replace")
        errtext = err.read().decode("utf-8", "replace")
        code = out.channel.recv_exit_status()
        combined = (text + errtext).strip()
        if combined and not quiet:
            for line in combined.splitlines()[-25:]:
                print("      | " + line)
        if code != 0 and check:
            raise SystemExit(f"Команда упала ({code}): {cmd}")
        return code, combined

    def remote_sha256(self, remote_dir: str, rels: list[str]) -> dict[str, str]:
        """SHA-256 файлов на ВМ — одним ssh-вызовом.

        Пустой результат означает «сравнивать не с чем» (файлов нет или утилиты
        sha256sum нет): тогда выгружается всё, как раньше.
        """
        if not rels:
            return {}
        quoted = " ".join(shlex.quote(r) for r in rels)
        code, out = self.run(f"cd {shlex.quote(remote_dir)} && sha256sum -- {quoted} 2>/dev/null",
                             quiet=True)
        sums: dict[str, str] = {}
        for line in out.splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2:
                sums[parts[1].strip().lstrip("*")] = parts[0]
        ## Если sha256sum ругнулся на отсутствующий файл — он всё равно печатает
        ## хеши остальных, так что выгружаем только те, что не попали в ответ.
        if not sums and code != 0:
            print("    sha256sum на ВМ недоступен — выгружаю все файлы")
        return sums

    def put_tree(self, local_dir: str, remote_dir: str) -> int:
        count = 0
        total = 0
        self.run(f"mkdir -p {remote_dir}")
        entries: list[tuple[str, str, str, int]] = []
        for base, _dirs, files in os.walk(local_dir):
            rel = os.path.relpath(base, local_dir).replace("\\", "/")
            target = remote_dir if rel == "." else posixpath.join(remote_dir, rel)
            self.run(f"mkdir -p '{target}'", quiet=True)
            for name in files:
                src = os.path.join(base, name)
                dst = posixpath.join(target, name)
                relfile = name if rel == "." else rel + "/" + name
                entries.append((relfile, src, dst, os.path.getsize(src)))
        ## Тяжёлые файлы (index.pck / index.wasm) — первыми, index.html — последним.
        entries.sort(key=lambda e: (e[0] in UPLOAD_LAST, -e[3], e[0]))

        remote = self.remote_sha256(remote_dir, [e[0] for e in entries])
        skipped = 0
        uploaded: list[str] = []
        for relfile, src, dst, size in entries:
            if remote.get(relfile) == sha256_file(src):
                skipped += 1
                continue
            self.sftp.put(src, dst)
            uploaded.append(relfile)
            count += 1
            total += size
        tail = f", без изменений: {skipped}" if skipped else ""
        print(f"    загружено файлов: {count} ({total / 1048576:.2f} МБ){tail}")
        if uploaded:
            order = uploaded if len(uploaded) <= 4 else uploaded[:3] + ["...", uploaded[-1]]
            print("    порядок: " + ", ".join(order))
        return count

    def close(self) -> None:
        try:
            self.sftp.close()
        finally:
            self.client.close()


def dns_check(host: str, expect_ip: str) -> bool:
    try:
        resolved = socket.gethostbyname(host)
    except OSError as exc:
        print(f"    {host}: DNS не отвечает ({exc})")
        return False
    ok = resolved == expect_ip
    print(f"    {host} -> {resolved} {'(совпадает)' if ok else '(НЕ совпадает с ' + expect_ip + ')'}")
    return ok


def cmd_probe(rem: Remote, ip: str) -> None:
    print("== состояние ВМ ==")
    rem.run("cat /etc/os-release | head -3; uname -m")
    rem.run("nginx -v 2>&1 || echo 'nginx нет'")
    rem.run("command -v certbot || echo 'certbot нет'")
    rem.run("ss -ltnp | head -20 || netstat -ltnp | head -20")
    rem.run("ls /etc/nginx/sites-enabled/ 2>/dev/null; ls /etc/nginx/conf.d/ 2>/dev/null")
    rem.run("df -h / | tail -1; free -m | head -2; nproc")
    rem.run("curl -s -o /dev/null -w '%{http_code}\\n' http://127.0.0.1/ || true")
    print("== DNS для бесплатных хостнеймов ==")
    for host in free_hostname(ip):
        dns_check(host, ip)


def cmd_upload(rem: Remote) -> None:
    if not os.path.isdir(BUILD_DIR):
        raise SystemExit(f"Нет сборки: {BUILD_DIR} (сначала выполните web-экспорт)")
    print(f"== загрузка {BUILD_DIR} -> {REMOTE_DIR} ==")
    rem.put_tree(BUILD_DIR, REMOTE_DIR)
    rem.run(f"chown -R www-data:www-data {REMOTE_DIR}; find {REMOTE_DIR} -type d -exec chmod 755 {{}} +; find {REMOTE_DIR} -type f -exec chmod 644 {{}} +")


NGINX_HTTP = """# ЗОНА: Пикник на обочине — статика Godot Web (HTTP-этап, до выпуска сертификата)
server {{
    listen 80;
    listen [::]:80;
    server_name {host};

    root {root};
    index index.html;

    # проверка домена для Let's Encrypt (HTTP-01)
    location ^~ /.well-known/acme-challenge/ {{
        root {root};
        default_type text/plain;
    }}

    add_header X-Content-Type-Options nosniff always;

    gzip on;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_vary on;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml application/javascript application/json
               application/wasm application/octet-stream image/svg+xml;

    location ~* \\.wasm$ {{ default_type application/wasm; }}
    location ~* \\.(pck|data)$ {{ default_type application/octet-stream; }}
    location / {{ try_files $uri $uri/ /index.html =404; }}
}}
"""

NGINX_HTTPS = """# ЗОНА: Пикник на обочине — статика Godot Web (HTTP → HTTPS, TLS от Let's Encrypt)
server {{
    listen 80;
    listen [::]:80;
    server_name {host};

    location ^~ /.well-known/acme-challenge/ {{
        root {root};
        default_type text/plain;
    }}

    location / {{ return 301 https://$host$request_uri; }}
}}

server {{
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name {host};

    ssl_certificate     /etc/letsencrypt/live/{cert}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{cert}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    root {root};
    index index.html;

    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy no-referrer-when-downgrade always;

    gzip on;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_vary on;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml application/javascript application/json
               application/wasm application/octet-stream image/svg+xml;

    # MIME для WebAssembly и пакета ресурсов + политика кэша.
    # HTML/JS/WASM/PCK перепроверяются у сервера (ETag → 304, если файл не изменился):
    # сборка меняется на каждом деплое, и с долгим max-age браузер и service worker
    # держали бы старый пак до 7 суток — игра «не обновлялась» после выкладки.
    # expires -1 = Cache-Control: no-cache и наследуемые add_header из server.
    location ~* \\.wasm$ {{
        default_type application/wasm;
        expires -1;
    }}
    location ~* \\.(pck|data)$ {{
        default_type application/octet-stream;
        expires -1;
    }}
    location ~* \\.(js|css)$ {{
        expires -1;
    }}
    # иконки и шрифты оболочки между сборками не меняются — их кэшируем надолго
    location ~* \\.(png|jpg|svg|ttf|woff2|ico)$ {{
        expires 7d;
    }}
    location = /index.html {{ expires -1; }}
    location = / {{ expires -1; }}
    location / {{ try_files $uri $uri/ /index.html =404; }}
}}
"""


def cert_name_for(host: str) -> str:
    return "zone-" + host.split(".")[0]


def cmd_nginx(rem: Remote, host: str) -> None:
    """Пишем конфиг сами: с TLS, если сертификат уже выпущен, иначе только HTTP."""
    cert = cert_name_for(host)
    has_cert = rem.run(f"test -f /etc/letsencrypt/live/{cert}/fullchain.pem && echo yes || echo no",
                       quiet=True)[1].strip() == "yes"
    conf = (NGINX_HTTPS if has_cert else NGINX_HTTP).format(host=host, root=REMOTE_DIR, cert=cert)
    print(f"== конфиг nginx для {host} ({'с TLS' if has_cert else 'HTTP, ждём сертификат'}) ==")
    remote_path = f"/etc/nginx/sites-available/{SITE_NAME}.conf"
    with rem.sftp.file(remote_path, "w") as fh:
        fh.write(conf)
    rem.run("mkdir -p /etc/nginx/sites-enabled")
    rem.run(f"ln -sf {remote_path} /etc/nginx/sites-enabled/{SITE_NAME}.conf")
    # Чужие сайты на этой ВМ не трогаем: наш блок матчится по server_name.
    code, out = rem.run("nginx -t 2>&1", quiet=True)
    print("    nginx -t:", out.replace("\n", " | "))
    if code != 0:
        raise SystemExit("конфиг nginx не проходит проверку")
    rem.run("systemctl reload nginx || service nginx reload", check=False)
    rem.run("command -v ufw >/dev/null && ufw allow 80/tcp && ufw allow 443/tcp || true", check=False)



def cmd_install(rem: Remote) -> None:
    print("== установка nginx и certbot ==")
    _code, out = rem.run("command -v apt-get >/dev/null && echo apt || echo other", quiet=True)
    if "apt" in out:
        rem.run("export DEBIAN_FRONTEND=noninteractive; apt-get update -y -qq")
        rem.run("export DEBIAN_FRONTEND=noninteractive; apt-get install -y -qq nginx "
                "certbot python3-certbot-nginx curl")
    else:
        rem.run("command -v dnf >/dev/null && dnf install -y nginx certbot python3-certbot-nginx || "
                "yum install -y nginx certbot python3-certbot-nginx", check=False)
    rem.run("systemctl enable --now nginx || service nginx start", check=False)
    rem.run("nginx -v 2>&1")
    rem.run("certbot --version 2>&1")


def cmd_cert(rem: Remote, host: str, email: str = "") -> bool:
    """Сертификат через webroot (без правки nginx самим certbot — конфиг наш)."""
    print(f"== сертификат Let's Encrypt для {host} ==")
    name = cert_name_for(host)
    existing = rem.run(f"test -f /etc/letsencrypt/live/{name}/fullchain.pem && echo yes || echo no",
                       quiet=True)[1]
    if "yes" in existing:
        print("    сертификат уже есть — пробуем продление")
        rem.run(f"certbot renew --cert-name {name} --non-interactive --keep-until-expiring",
                check=False)
        return True
    mail = f"-m {email}" if email else "--register-unsafely-without-email"
    rem.run(f"mkdir -p {REMOTE_DIR}/.well-known/acme-challenge")
    code, _out = rem.run(
        f"certbot certonly --webroot -w {REMOTE_DIR} -d {host} --cert-name {name} "
        f"--expand --non-interactive --agree-tos {mail} --keep-until-expiring 2>&1", check=False)
    if code != 0:
        print("    certbot не смог выдать сертификат (см. вывод выше)")
        return False
    return True


def verify(url: str) -> bool:
    import ssl
    import urllib.request
    print(f"== проверка {url} ==")
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(url, timeout=30, context=ctx) as resp:
            body = resp.read(4000).decode("utf-8", "replace")
            ctype: str = resp.headers.get("Content-Type", "")
            print(f"    HTTP {resp.status} | {ctype} | {len(body)} символов")
            for needle in ("canvas", "ЗОНА", "godot"):
                if needle.lower() in body.lower():
                    print(f"    в ответе найдено: {needle}")
                    return True
            print("    ответ не похож на оболочку Godot")
            return False
    except Exception as exc:  # noqa: BLE001
        print(f"    ошибка запроса: {type(exc).__name__}: {exc}")
        return False


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Деплой веб-сборки игры на ВМ")
    ap.add_argument("steps", nargs="*", default=["all"],
                    help="probe | install | upload | nginx | cert | verify | all")
    ap.add_argument("--domain", default="", help="свой домен вместо бесплатного хостнейма")
    ap.add_argument("--email", default="", help="почта для Let's Encrypt")
    args = ap.parse_args(argv)
    steps: list[str] = args.steps or ["all"]
    if "all" in steps:
        steps = ["probe", "install", "upload", "nginx", "cert", "nginx", "verify"]

    host_ip, password, port = read_env()
    print(f"[i] ВМ: root@{host_ip}:{port}")
    rem = Remote(host_ip, password, port)
    print("[i] подключение установлено")
    domain: str = args.domain
    if not domain:
        for cand in free_hostname(host_ip):
            if dns_check(cand, host_ip):
                domain = cand
                break
        if not domain:
            domain = free_hostname(host_ip)[0]
            print(f"[!] DNS бесплатного хостнейма не подтверждён, всё равно пробую {domain}")
    print(f"[i] домен: {domain}")

    t0 = time.time()
    try:
        for step in steps:
            if step == "probe":
                cmd_probe(rem, host_ip)
            elif step == "install":
                cmd_install(rem)
            elif step == "upload":
                cmd_upload(rem)
            elif step == "nginx":
                cmd_nginx(rem, domain)
            elif step == "cert":
                cmd_cert(rem, domain, args.email)
            elif step == "verify":
                verify(f"https://{domain}/")
                verify(f"https://{domain}/index.wasm")
                rem.run("tail -5 /var/log/nginx/error.log 2>/dev/null || true", check=False)
            else:
                print(f"[!] неизвестный шаг: {step}")
    finally:
        rem.close()
    print(f"[i] готово за {time.time() - t0:.1f} с")
    print(f"[i] игра: https://{domain}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))


