# infrastructure-monitoring (Mikr.us FROG)

Repozytorium zawiera Compose do uruchomienia na FROG-u: **Beszel (Hub+Agent)**, **Uptime Kuma**
oraz szkielet backupów **Restic (resticprofile)**. Domyślna adresacja korzysta z subdomen `wykr.es`
zgodnie z dokumentacją FROG.

---

## Szybki start

1. Sklonuj repo i uzupełnij `.env` na podstawie `.env.example`.
2. Ustaw **sekrety GitHub Actions**:
   - `FROG_SERVER`, `FROG_SSH_PORT`, `FROG_LOGIN`, `FROG_PASSWORD`
   - `BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN`, `BESZEL_AGENT_HUB_URL`
3. Uruchom workflow **Deploy to FROG** (ręcznie lub po pushu na `main`).
4. Wejdź na:
   - Beszel: `http://$BESZEL_HOSTNAME`
   - Uptime Kuma: `http://$KUMA_HOSTNAME`

---

## Co robi deploy

- Instaluje Docker + Compose v2 na Alpine (`apk add docker docker-cli-compose`)
- Tworzy katalogi danych w `/opt/infrastructure-monitoring`
- Kopiuje pliki Compose i `.env` na serwer
- Uruchamia Compose dla Beszel i Uptime Kuma
- Sekrety (klucze, tokeny) są przekazywane wyłącznie przez zmienne środowiskowe i nie są trzymane w repozytorium

---

## Sekrety i bezpieczeństwo

- **.env** oraz pliki z sekretami są ignorowane przez git (`.gitignore`)
- **ansible-inventory** nie zawiera żadnych sekretów ani haseł – tylko host(y)
- Wszystkie sekrety są przekazywane do Ansible przez zmienne środowiskowe (lokalnie: `export`, w CI: `env:` w workflow)
- Playbook Ansible automatycznie ustawia użytkownika, port i hasło SSH na podstawie zmiennych środowiskowych

---

## Tygodniowe logowanie i aktualizacje

Workflow `weekly-login-update.yml` raz w tygodniu loguje się przez SSH, wykonuje `apk update && apk upgrade`, a gdy logowanie się nie powiedzie — tworzy zgłoszenie w Issues z alertem.

---

## Testowanie lokalne (bez dotykania serwera)

### 1. Walidacja YAML dla GitHub Actions

- Zainstaluj `act` (lokalny runner GitHub Actions):

```bash
brew install act
```

- Uruchom dry-run workflowu deploy (bez faktycznego SSH):

```bash
# Skonfiguruj plik .secrets z wartościami testowymi
cat > .secrets <<'EOF'
FROG_SERVER=127.0.0.1
FROG_SSH_PORT=2222
FROG_LOGIN=test
FROG_PASSWORD=test
BESZEL_AGENT_KEY=testkey
BESZEL_AGENT_TOKEN=testtoken
BESZEL_AGENT_HUB_URL=http://localhost:8090
EOF

# Uruchom 'deploy' w trybie list/run, z mockami
act push -W .github/workflows/deploy.yml --secret-file .secrets --dryrun
```

- Uruchom ręcznie `weekly-login-update` z mockami:

```bash
act workflow_dispatch -W .github/workflows/weekly-login-update.yml --secret-file .secrets --dryrun
```

Uwaga: `appleboy/ssh-action` i `scp-action` w trybie dry-run nie łączą się z serwerem; celem jest wyłapanie błędów w YAML i w kroku przygotowania `.env`.

---

### 2. Walidacja Docker Compose

- Sprawdź składnię i interpolację environment:

```bash
# Opcjonalnie przygotuj lokalne .env z wymaganymi wartościami
cp .env.example .env 2>/dev/null || :

docker compose -f compose/beszel/compose.yml config
docker compose -f compose/uptime-kuma/compose.yml config
# docker compose -f compose/backup/resticprofile/compose.yml config
```

Polecenie `config` nie uruchamia kontenerów, ale wypluwa złączoną i zweryfikowaną konfigurację.

---

### 3. Szybki test skryptu instalacyjnego w kontenerze Alpine

- Uruchom jednorazowy kontener Alpine i przekaż skrypt do środka:

```bash
docker run --rm -it -v "$PWD/scripts:/scripts" alpine:3.19 sh -lc '
  apk add --no-cache bash curl sudo || true;
  chmod +x /scripts/install_docker_alpine.sh;
  /scripts/install_docker_alpine.sh || echo "Skrypt zakończył się kodem błędu (spodziewane w środowisku testowym)";
  which docker || echo "Docker nieaktywny w tym kontenerze — to spodziewane"
'
```

---

### 4. Mini smoke test z lokalnym Dockerem

Jeśli chcesz uruchomić usługi lokalnie (na własnym Macu), pamiętaj o ograniczeniach portów i katalogów danych. Możesz wykonać:

```bash
# Upewnij się, że masz Docker Desktop
open -a Docker

# Uruchom pojedynczo, np. Uptime Kuma
docker compose -f compose/uptime-kuma/compose.yml up -d

# Podgląd logów
docker compose -f compose/uptime-kuma/compose.yml logs -f --tail=100

# Zatrzymanie
docker compose -f compose/uptime-kuma/compose.yml down
```

---

### 5. Checklist przed prawdziwym deployem

- `.env` istnieje i ma: BESZEL_HOSTNAME, KUMA_HOSTNAME (oraz FROG_HOST/FROG_SSH_PORT jeśli używasz ich lokalnie)
- Sekrety repo ustawione: `FROG_SERVER`, `FROG_SSH_PORT`, `FROG_LOGIN`, `FROG_PASSWORD`, `BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN`, `BESZEL_AGENT_HUB_URL`
- `docker compose ... config` przechodzi bez błędów
- `act --dryrun` nie zgłasza błędów

Jeśli chcesz najpewniejszego testu, uruchom deploy przeciwko sandboxowej maszynie (np. lokalny VM lub droplet) z tymi samymi sekretami — to najlepiej odwzoruje produkcję, ale nadal bez ryzyka dla FROG.

---

## FAQ

- **Gdzie są sekrety?**  
  W .env (lokalnie, nie w repo) i/lub jako sekrety GitHub Actions.  
  Inventory Ansible nie zawiera żadnych haseł.

- **Jak dodać nowy serwis?**  
  Dodaj plik Compose w `compose/`, zaktualizuj `.env.example` i playbook Ansible.

---
