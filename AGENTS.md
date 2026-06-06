# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter application using GetX for routing, state management, and dependency injection. Main source code lives in `lib/`. Pages are organized under `lib/page/<feature>/view/`, shared base classes under `lib/base/`, wallet domain code under `lib/wallet/`, reusable widgets under `lib/widget/`, utilities under `lib/utils/`, and generated localization/routing code under `lib/generated/`. Tests live in `test/`. Static assets are in `assets/icons/`, `assets/img/`, and `assets/svg/`. Platform folders (`android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/`) should only be changed for platform-specific work.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart/Flutter dependencies.
- `flutter run`: run the app on the selected device.
- `flutter test`: run all tests.
- `flutter test test/wallet_crypto_service_test.dart`: run a focused test file.
- `flutter analyze`: run static analysis using `analysis_options.yaml`.
- `dart format lib test`: format Dart sources.
- `flutter pub run intl_utils:generate`: regenerate localization files after editing `lib/l10n/*.arb`.
- `flutter pub run build_runner build`: regenerate route/model code when generator-backed files change.
- `flutter build apk --release` / `flutter build ipa --release`: create Android/iOS release builds.

## Coding Style & Naming Conventions

Use Dart defaults: two-space indentation, `lowerCamelCase` for variables and methods, `UpperCamelCase` for classes, and `snake_case.dart` filenames. Prefer existing base classes: `BaseController`, `BasePage`, and `BaseScaffoldPage`. Keep UI text localized through `S.of(context).key`; add keys to both `intl_en.arb` and `intl_zh.arb`. Use `ScreenUtil` sizing (`.w`, `.h`, `.sp`) for UI dimensions.

## Testing Guidelines

Use `flutter_test`. Add focused unit tests for services, encoders, amount parsing, and wallet logic. Keep test files named `*_test.dart`. Avoid tests that require real blockchain transfers; mock or cover pure logic where possible. Run `flutter test` before submitting changes.

## Commit & Pull Request Guidelines

History is mixed, but concise imperative messages are preferred; `feat: ...` is acceptable for feature work. PRs should include a short summary, verification commands run, linked issue if any, and screenshots for UI changes. Note generated-file updates explicitly when localization, routes, or JSON models are regenerated.

## Security & Configuration Tips

This app currently stores private keys locally and is suitable for testing only. Do not commit real private keys, seed phrases, API secrets, or production wallet data. Treat transfer-related code as high risk: validate addresses, amounts, chain selection, and error handling carefully.
