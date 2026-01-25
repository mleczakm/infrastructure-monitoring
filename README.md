# infrastructure-monitoring (Mikr.us FROG)

Repozytorium zawiera Compose do uruchomienia na FROG-u: **Beszel (Hub+Agent)**, **Uptime Kuma**, **Databasus** 
oraz szkielet backupów **Restic (resticprofile)**. Domyślna adresacja korzysta z subdomen `wykr.es` 
zgodnie z dokumentacją FROG.

## Szybki start

1. Sklonuj repo i uzupełnij `.env` na podstawie `.env.example`.
2. Ustaw **sekrety GitHub Actions**:
   - `FROG_SERVER`, `FROG_SSH_PORT`, `FROG_LOGIN`, `FROG_PASSWORD`.
3. Uruchom workflow **Deploy to FROG** (ręcznie lub po pushu na `main`).
4. Wejdź na:
   - Beszel: `http://$BESZEL_HOSTNAME`
   - Uptime Kuma: `http://$KUMA_HOSTNAME`
   - Databasus: `http://$DATABASUS_HOSTNAME`

## Co robi deploy

- Instaluje Docker + Compose v2 na Alpine (`apk add docker docker-cli-compose`),
- tworzy katalogi danych w `/opt/infrastructure-monitoring`,
- uruchamia trzy compose’y (Beszel, Uptime Kuma, Databasus).

## Tygodniowe logowanie i aktualizacje

Workflow `weekly-login-update.yml` raz w tygodniu loguje się przez SSH, wykonuje `apk update && apk upgrade`, a gdy logowanie się nie powiedzie — tworzy zgłoszenie w Issues z alertem.

## Uwaga o zasobach

FROG ma ~256 MB RAM, dlatego unikaj jednoczesnego wykonywania ciężkich zadań. W razie problemów ogranicz retencję danych w Beszel oraz monitoruj RAM.

## Testowanie lokalne (bez dotykania serwera)

Poniżej szybkie sposoby na sprawdzenie konfiguracji i workflowów lokalnie.

1) Walidacja YAML dla GitHub Actions
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
EOF

# Uruchom 'deploy' w trybie list/run, z mockami
act push -W .github/workflows/deploy.yml --secret-file .secrets --dryrun
```

- Uruchom ręcznie `weekly-login-update` z mockami:

```bash
act workflow_dispatch -W .github/workflows/weekly-login-update.yml --secret-file .secrets --dryrun
```

Uwaga: `appleboy/ssh-action` i `scp-action` w trybie dry-run nie łączą się z serwerem; celem jest wyłapanie błędów w YAML i w kroku przygotowania `.env`.

2) Walidacja Docker Compose

- Sprawdź składnię i interpolację environment:

```bash
# Opcjonalnie przygotuj lokalne .env z wymaganymi wartościami
cp .env.example .env 2>/dev/null || :

docker compose -f compose/beszel/compose.yml config
docker compose -f compose/uptime-kuma/compose.yml config
docker compose -f compose/databasus/compose.yml config
# docker compose -f compose/backup/resticprofile/compose.yml config
```

Polecenie `config` nie uruchamia kontenerów, ale wypluwa złączoną i zweryfikowaną konfigurację.

3) Szybki test skryptu instalacyjnego w kontenerze Alpine

- Uruchom jednorazowy kontener Alpine i przekaż skrypt do środka:

```bash
docker run --rm -it -v "$PWD/scripts:/scripts" alpine:3.19 sh -lc '
  apk add --no-cache bash curl sudo || true;
  chmod +x /scripts/install_docker_alpine.sh;
  /scripts/install_docker_alpine.sh || echo "Skrypt zakończył się kodem błędu (spodziewane w środowisku testowym)";
  which docker || echo "Docker nieaktywny w tym kontenerze — to spodziewane"
'
```

To pozwala sprawdzić, czy skrypt nie ma błędów składniowych i czy komendy `apk` działają, bez modyfikowania Twojego hosta.

4) Mini smoke test z lokalnym Dockerem

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

5) Checklist przed prawdziwym deployem
- `.env` istnieje i ma: BESZEL_HOSTNAME, KUMA_HOSTNAME, DATABASUS_HOSTNAME (oraz FROG_HOST/FROG_SSH_PORT jeśli używasz ich lokalnie).
- Sekrety repo ustawione: `FROG_SERVER`, `FROG_SSH_PORT`, `FROG_LOGIN`, `FROG_PASSWORD`.
- `docker compose ... config` przechodzi bez błędów.
- `act --dryrun` nie zgłasza błędów.

Jeśli chcesz najpewniejszego testu, uruchom deploy przeciwko sandboxowej maszynie (np. lokalny VM lub droplet) z tymi samymi sekretami — to najlepiej odwzoruje produkcję, ale nadal bez ryzyka dla FROG.
