# Só Serviços — Marca no App Prestador (F2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use checkbox syntax.

**Goal:** Trocar a identidade KZ/amarela do app Prestador pela marca "Só Serviços" (laranja `#FF9A52`), com logos, ícone, splash e nome visível.

**Architecture:** Tokens de marca num único sítio (`AppColors` + novo `AppBrand`); todo o resto referencia esses tokens. Assets copiados de `tellin/public/brand/` (não gerados). Ícones nativos gerados com `flutter_launcher_icons` (já é dev dependency).

**Tech Stack:** Flutter 3.41.6, flutter_test, flutter_launcher_icons 0.14.4.

**Spec:** `tellin/docs/superpowers/specs/2026-11-05-so-servicos-reativacao-design.md` §3, §4 (contrato do orquestrador).

## Global Constraints

- Primária `#FF9A52` · escura `#E68B4A` · clara `#FFB27A` · rosa `#E54C65` · texto sobre primária `#1F2430` (nunca branco sobre laranja) · degradê `#E54C65 → #FF9A52`.
- Substituir `#FEBF22`, `#e5ab1e`, `#FFD700`, `#FFA000` e amber/yellow; manter verde de sucesso e azul secundário.
- Nome visível "Só Serviços"; "KZ"/"pela KZ"/"equipe KZ" nos textos visíveis → "Só Serviços".
- NÃO alterar `applicationId`/bundle id, `firebase_options.dart`, `google-services.json`. Sem commit/push. Não reverter alterações pré-existentes.
- Logo branca em fundo escuro, logo escura em fundo claro.

## Review Focus

- Botão laranja com texto/ícone branco (3 sítios hoje) → ilegível; teste de guarda proíbe.
- Amarelos soltos fora de `AppColors` (splash, rota, avisos) → teste de guarda varre `lib/`.
- Texto "KZ" em strings interpoladas/`const` → o analyzer falha se `const` ficar errado.
- Splash nativo preto a piscar antes do splash Flutter → mesmo fundo `#16161D` nos dois.

---

### Task 1: Tokens de marca (TDD)
**Files:** Modify `lib/core/constants/app_colors.dart`; Create `lib/core/constants/app_brand.dart`; Test `test/core/constants/brand_tokens_test.dart`
**Interfaces — Produces:** `AppColors.highlight/highlightDark/highlightLight/brandPink/onHighlight/highlightSoft/brandDark` (`Color`), `AppColors.brandGradient` (`LinearGradient`); `AppBrand.name`, `AppBrand.appName`, `AppBrand.tagline`, `AppBrand.logoWhite/logoDark/logoIcon` (asset paths).
- [ ] Teste (RED): valores exatos acima; `AppBrand.name == 'Só Serviços'`.
- [ ] Implementar; teste GREEN.

### Task 2: Guarda anti-amarelo + eliminar amarelos e brancos-sobre-laranja
**Files:** Test `test/core/constants/brand_guard_test.dart`; Modify os ficheiros que o teste apontar (botões `foregroundColor`, `route_polyline_builder.dart`, `active_trip_panels.dart`, `trip_request_card.dart`, `trip_history_page.dart`, `splash_page.dart`).
- [ ] Teste (RED): varre `lib/**/*.dart` e falha se achar hex amarelos antigos ou `Colors.amber`; falha se `backgroundColor: AppColors.highlight` for seguido de `foregroundColor: Colors.white`.
- [ ] Corrigir até GREEN (`onHighlight` nos botões).

### Task 3: Nome e textos
**Files:** Modify `lib/main.dart` (title), `push_notification_service.dart` (título por omissão), textos "KZ" visíveis (chat_page, schedules_page, active_trip_page, active_trip_panels, cancel_trip_sheet, benefits_*), testes desatualizados da baseline (5).
- [ ] Alinhar os 5 testes da baseline aos textos novos (RED→GREEN já definido pelo código).
- [ ] Substituir "KZ" visível por `AppBrand.name`; `flutter test` sem regressões.

### Task 4: Assets, splash, login, ícones, nativo
**Files:** Create `assets/brand/*` (copiados); Modify `pubspec.yaml` (assets + flutter_launcher_icons), `splash_page.dart`, `login_page.dart`/`auth_bottom_sheet.dart` (logo), Android (`AndroidManifest.xml` label, `styles*.xml`, `launch_background*.xml`), iOS `Info.plist` (`CFBundleDisplayName`), `web/index.html`, `web/manifest.json`, `web/icons/*`.
- [ ] Copiar logos para `assets/brand/` e fontes dos ícones para `assets/brand/launcher/`.
- [ ] `dart run flutter_launcher_icons` com fundo `#16161D`.
- [ ] Nome "Só Serviços Prestador" (Android/iOS/web); fundo nativo e do splash Flutter `#16161D`.

### Task 5: Verificação
- [ ] `flutter analyze --no-pub` → sem problemas; `flutter test --no-pub` → tudo verde; `flutter build apk --debug` compila; captura visual no Chrome.
