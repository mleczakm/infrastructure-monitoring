# infrastructure-monitoring (Mikr.us FROG)

Repozytorium zawiera **deklaratywną konfigurację Ansible** do uruchomienia na **Mikr.us FROG (Alpine Linux)** monitoringu **Beszel (HUB + Agent)**.

- **Beszel HUB** jest wystawiany publicznie przez subdomenę `wykr.es`
- **Beszel Agent** działa wyłącznie **outbound** (nie wystawia żadnych portów na hoście)
- Całość jest zarządzana deklaratywnie przez Ansible (`community.docker`)

Domyślna adresacja korzysta z subdomen `wykr.es` zgodnie z dokumentacją FROG.

---

## Architektura (skrót)

- FROG (Alpine Linux)
    - Docker (zarządzany przez Ansible)
    - `beszel` (HUB)
        - port: `{SSH_PORT + 10000}` → `*.wykr.es`
    - `beszel-agent`
        - **tylko outbound** do HUB
        - brak publikowanych portów

---

## Szybki start

1. Sklonuj repozytorium.
2. Ustaw **sekrety GitHub Actions**:
    - `FROG_SERVER`
    - `FROG_SSH_PORT`
    - `FROG_LOGIN`
    - `FROG_PASSWORD`
    - `BESZEL_AGENT_KEY`
    - `BESZEL_AGENT_TOKEN`  
      (dostępne po skonfigurowaniu Beszel HUB)
3. Uruchom workflow **Deploy to FROG**:
    - ręcznie (`workflow_dispatch`)
    - lub automatycznie po pushu na `main`
4. Wejdź na adres:

```
https://{twoj-frog}-{SSH_PORT + 10000}.wykr.es
```

Przykład:
```
https://frog03-12222.wykr.es
```

---

## Co robi deploy

Playbook Ansible wykonuje **w pełni deklaratywny deploy**:

- instaluje Docker + Python Docker SDK na Alpine (`apk`)
- uruchamia **Beszel HUB** jako kontener Docker
- uruchamia **Beszel Agent** tylko jeśli dostępne są:
    - `BESZEL_AGENT_KEY`
    - `BESZEL_AGENT_TOKEN`
- tworzy wymagane **named volumes**:
    - `beszel_data`
    - `beszel_agent_data`
- **nie używa `docker run` ani `shell`**
- automatycznie:
    - restartuje kontenery przy zmianach
    - usuwa `beszel-agent`, jeśli sekrety nie są ustawione
- wykonuje health-checki:
    - HTTP dla HUB
    - `docker inspect` dla agenta

---

## Sekrety i bezpieczeństwo

- repo **nie zawiera żadnych sekretów**
- `.env`, pliki lokalne i artefakty są ignorowane przez `.gitignore`
- inventory Ansible **nie zawiera haseł**
- wszystkie sekrety są przekazywane:
    - lokalnie: przez `export`
    - w CI: przez **GitHub Actions secrets**
- sekrety:
    - **nie są zapisywane na serwerze**
    - **nie są zapisywane w plikach**
    - są przekazywane wyłącznie do procesu uruchamiania kontenerów
- taski z sekretami mają `no_log: true`

---

## Tygodniowe logowanie i aktualizacje

Workflow `weekly-login-update.yml`:

- raz w tygodniu:
    - loguje się przez SSH na FROG
    - wykonuje:
      ```sh
      apk update && apk upgrade
      ```
- jeśli logowanie się **nie powiedzie**:
    - automatycznie tworzy **Issue** z alertem

Celem workflow jest:
- wykrycie problemów z dostępem SSH
- wczesne wykrycie problemów z FROG
- regularna aktualizacja systemu bazowego

---

## Testowanie lokalne (bez dotykania serwera)

### 1. Walidacja workflow GitHub Actions

Do lokalnego testowania workflow używany jest `act`.

#### Instalacja `act`

```bash
brew install act
```

#### Przygotowanie mocków sekretów

```bash
cat > .secrets <<'EOF'
FROG_SERVER=127.0.0.1
FROG_SSH_PORT=2222
FROG_LOGIN=test
FROG_PASSWORD=test
BESZEL_AGENT_KEY=testkey
BESZEL_AGENT_TOKEN=testtoken
EOF
```

#### Dry-run deploy workflow

```bash
act push   -W .github/workflows/deploy.yml   --secret-file .secrets   --dryrun
```

#### Dry-run weekly login update

```bash
act workflow_dispatch   -W .github/workflows/weekly-login-update.yml   --secret-file .secrets   --dryrun
```

> Uwaga:  
> `appleboy/ssh-action` oraz `scp-action` w trybie `--dryrun` **nie łączą się z serwerem**.  
> Celem jest walidacja YAML, zmiennych środowiskowych i logiki workflow.

---

## Checklist przed prawdziwym deployem

- ✅ ustawione sekrety repo:
    - `FROG_SERVER`
    - `FROG_SSH_PORT`
    - `FROG_LOGIN`
    - `FROG_PASSWORD`
    - `BESZEL_AGENT_KEY`
    - `BESZEL_AGENT_TOKEN`
- ✅ `act --dryrun` bez błędów
- ✅ poprawna subdomena `wykr.es`

Jeśli chcesz najpewniejszego testu:
- uruchom deploy na **sandboxowej VM**
- z tym samym zestawem sekretów  
  To najlepiej odwzoruje produkcję bez ryzyka dla FROG.

---

## FAQ

### Gdzie są sekrety?
Wyłącznie jako:
- sekrety GitHub Actions
- zmienne środowiskowe

Repozytorium i inventory Ansible **nie zawierają haseł**.

---

### Czy Beszel Agent wystawia porty?
Nie.  
Agent działa **wyłącznie outbound** i komunikuje się z HUB-em przez HTTPS.

---

### Jak dodać nowy serwis?
Dodaj nowy task w playbooku Ansible:
- `community.docker.docker_volume`
- `community.docker.docker_container`

Repo jest przygotowane pod dalszą rozbudowę w tym samym stylu deklaratywnym.
