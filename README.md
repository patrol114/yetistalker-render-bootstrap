# YetiStalker Render Bootstrap

Minimalny, pozbawiony sekretów bootstrap wdrożeniowy. Pełny kod aplikacji
pozostaje w prywatnym repozytorium i jest pobierany na Renderze za pomocą
klucza deploy SSH tylko do odczytu, przypisanego wyłącznie do tego repozytorium.

Wymagane zmienne Render:

- `YETI_GITHUB_DEPLOY_KEY_B64` — klucz deploy zakodowany base64,
- `YETI_GITHUB_COMMIT` — pełny SHA wdrażanego commitu.

Build command: `bash bootstrap-build.sh`

Start command: `bash bootstrap-start.sh`
