# Flow VPN

<p align="center">
  <strong>Простой Android-клиент для VLESS</strong><br>
  Добавляйте VLESS-серверы и HTTPS-подписки, выбирайте узел и подключайтесь через системный VPN Android.
</p>

<p align="center">
  <a href="https://github.com/moskvol/flow-vpn/releases/tag/v0.1.0"><img alt="Latest release" src="https://img.shields.io/github/v/tag/moskvol/flow-vpn/v0.1.0?style=flat-square"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44-02569B?style=flat-square&logo=flutter&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square">
</p>

## Авторы / Contributors`r`n`r`n- **moskvol** — автор проекта и владелец репозитория.`r`n- **OpenAI Codex (AI assistant)** — помощь с разработкой и подготовкой Android-релиза.`r`n`r`n[English](#english)

## Скачать

Откройте [страницу последнего релиза](https://github.com/moskvol/flow-vpn/releases/tag/v0.1.0) и скачайте `app-release.apk`. На Android разрешите установку приложения из выбранного источника, затем откройте APK.

> Первые сборки предназначены для тестирования и подписаны отладочным ключом. Это приложение не опубликовано в Google Play. Подключение к VPN требует действующей VLESS-конфигурации или HTTPS-подписки.

## Возможности

- Подключение и отключение Android VPN через `VpnService` и sing-box.
- Импорт одиночных VLESS-ссылок и HTTPS-подписок.
- Параметры TLS, REALITY, WebSocket и gRPC, если они указаны в ссылке.
- Список серверов, поиск, выбор и избранное.
- Защищённое системное хранилище для конфигураций.
- Интерфейс на русском языке, светлая и тёмная темы.

Поддерживаются только ссылки VLESS в текущей версии. Другие протоколы и форматы подписок не заявлены.

## Сборка из исходников

Нужны Flutter 3.44+, JDK 17 и Android SDK (API 36; минимум Android API 24).

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK появится в `build/app/outputs/flutter-apk/app-release.apk`. Для собственного распространения настройте ключ подписи в `android/app/build.gradle.kts`; не используйте отладочную подпись для публичной поставки.

## Технологии

- Flutter / Dart
- Android `VpnService`
- [sing_box](https://pub.dev/packages/sing_box) — Flutter-плагин для sing-box

## Безопасность и лицензия

Не публикуйте личные VLESS-ссылки, подписки и ключи. Перед распространением сборки ознакомьтесь с лицензией GPL-3.0 и условиями распространения sing-box и его компонентов. См. [LICENSE](LICENSE).

Сообщения об уязвимостях не размещайте в публичных issues: используйте приватный канал GitHub Security Advisories, если он включён для репозитория.

---

<a id="english"></a>

## English

Flow VPN is an early Android client for VLESS. It imports VLESS links and HTTPS subscriptions, lets you choose a server, and connects through Android's VPN service using sing-box.

### Download

Get `app-release.apk` from the [latest release](https://github.com/moskvol/flow-vpn/releases/tag/v0.1.0). The initial builds are for testing and use a debug signing key. A working VLESS server or subscription is required.

### Features

- Connect and disconnect through Android `VpnService`.
- Import VLESS links and HTTPS subscriptions.
- TLS, REALITY, WebSocket and gRPC link parameters.
- Server search, selection and favorites.
- Device secure storage for configuration data.
- Russian interface with light and dark themes.

Only VLESS links are supported in this version.

### Build

Requirements: Flutter 3.44+, JDK 17 and Android SDK API 36 (minimum API 24).

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Configure your own signing key before distributing a production build. See [LICENSE](LICENSE) for GPL-3.0 terms and third-party component notices.


