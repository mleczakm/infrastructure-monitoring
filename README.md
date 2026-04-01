
# infrastructure-monitoring (Mikr.us FROG)

Repozytorium zawiera deklaratywną konfigurację Ansible do uruchomienia monitoringu Beszel (HUB + Agent) na Mikr.us FROG (Alpine Linux).

## Architektura

- FROG (Alpine Linux) z Dockerem
- Beszel HUB, wystawiony na świat przez wbudowaną we FROGa domenę z https
- Beszel Agent
- Zarządzanie przez Ansible (`community.docker`)

## Szybki start

1. Sklonuj repozytorium.
2. Ustaw sekrety GitHub Actions: `FROG_SERVER`, `FROG_SSH_PORT`, `FROG_LOGIN`, `FROG_PASSWORD`.
3. Jeśli masz już wstępnie skonfigurowany serwer BESZEL, ustaw też `BESZEL_AGENT_KEY` i `BESZEL_AGENT_TOKEN` aby zdeployować agenta do samoobserwacji.
3. Uruchom workflow **Deploy to FROG** (ręcznie lub po pushu na `main`).
4. Wejdź na: `https://{twoj-frog}-{SSH_PORT + 10000}.wykr.es`

## Co robi deploy

- Instaluje Docker + Python Docker SDK
- Uruchamia Beszel HUB i (jeśli są sekrety) Beszel Agent jako kontenery
- Tworzy named volumes: `beszel_data`, `beszel_agent_data`
- Automatycznie restartuje kontenery przy zmianach, usuwa agenta jeśli brak sekretów
- Health-check: HTTP dla HUB, `docker inspect` dla agenta

## Bezpieczeństwo

- Repo nie zawiera sekretów ani haseł
- Sekrety tylko jako zmienne środowiskowe/GitHub Actions
- Nie są zapisywane na serwerze ani w plikach

## Testowanie lokalne

Do testowania workflow lokalnie użyj `act`:

```bash
brew install act
act push -W .github/workflows/deploy.yml --secret-file .secrets --dryrun
```

## Checklista przed deployem

- Sekrety repo: `FROG_SERVER`, `FROG_SSH_PORT`, `FROG_LOGIN`, `FROG_PASSWORD`, `BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN`
- `act --dryrun` bez błędów

## FAQ

- **Gdzie są sekrety?** Tylko jako sekrety GitHub Actions lub zmienne środowiskowe. Repo i inventory Ansible nie zawierają haseł.
- **Czy Beszel Agent wystawia porty?** Nie, działa wyłącznie outbound przez HTTPS.
