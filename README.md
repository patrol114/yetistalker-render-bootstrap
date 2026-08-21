# YetiStalker Render Bootstrap

Minimalny, pozbawiony sekretów bootstrap wdrożeniowy. Pełny kod aplikacji
pozostaje w prywatnym repozytorium i jest pobierany na Renderze za pomocą
klucza deploy SSH tylko do odczytu, przypisanego wyłącznie do tego repozytorium.

Wymagane zmienne Render:

- `YETI_GITHUB_DEPLOY_KEY_B64` — klucz deploy zakodowany base64,
- `YETI_GITHUB_COMMIT` — pełny SHA wdrażanego commitu.

Build command: `bash bootstrap-build.sh`

Start command: `bash bootstrap-start.sh`

## Kandydat YetiTV fast-start

Plik `release-manifest.json` jest pozbawionym sekretów opisem kandydata do
wdrożenia. Pole `application_commit` wskazuje dokładny, przetestowany commit
prywatnej aplikacji. Przed canary ustaw na Renderze:

```text
YETI_GITHUB_COMMIT=<application_commit z release-manifest.json>
YETI_FAST_START=1
YETI_PROBE_BACKGROUND=1
```

Nie dodawaj do tego repo klucza deploy, tokenu ingest ani klucza
`SUPABASE_SERVICE_ROLE_KEY`. Wartości sekretów pozostają wyłącznie w chronionych
zmiennych środowiskowych Render/Supabase.

Weryfikacja po deployu:

1. `/webtv/api/health` zwraca HTTP 200 i `probe_state` równe `warming` lub
   `ready`.
2. UI `/webtv/` otwiera się przed zakończeniem pełnego skanu.
3. Po teście odtwarzania nie występuje pętla reconnectów ani wyciek danych
   upstream.

Rollback aplikacyjny nie wymaga zmiany bootstrapu: przywróć poprzednią wartość
`YETI_GITHUB_COMMIT` i uruchom nowy deploy. Doraźnie można również ustawić
`YETI_FAST_START=0`.

## Render Free i cold start

Plan Free usypia usługę po okresie bez ruchu. Nie należy dodawać sztucznego
pingowania ani trzymać procesu aktywnego kosztem limitu; trzeba rozróżniać
czas wybudzenia infrastruktury Render od czasu gotowości aplikacji.
Fast-start skraca tylko tę drugą część: proces binduje `$PORT` na
`0.0.0.0`, wystawia healthcheck, a probe playlisty wykonuje asynchronicznie.

Po zmianie release pinu sprawdź kolejno:

```text
HTTP /webtv/api/health = 200
probe_state = warming lub ready
publiczne /webtv/ = 200
po zakończeniu probe: channel_key zaczyna się od ch_
```

System plików usługi Free jest efemeryczny, dlatego cache operacyjny i stan
probe powinny być traktowane jako opcjonalne lokalnie, a trwały stan należy
utrzymywać w Supabase. Awaria Supabase nie może blokować health ani playera.

## Bezpieczna aktualizacja release pinu

Endpoint Render do aktualizacji zmiennych środowiskowych zastępuje cały
zestaw zmiennych. Przed zapisem trzeba więc pobrać istniejący zestaw, zmienić
wyłącznie `YETI_GITHUB_COMMIT`, zachować sekrety poza logami i wykonać osobny
deploy. Klucz Render powinien pochodzić z lokalnego środowiska
(`RENDER_API_KEY`), nigdy z repozytorium, promptu ani historii shell.
