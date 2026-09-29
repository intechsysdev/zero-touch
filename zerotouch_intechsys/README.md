# ZeroTouch Intechsys (Mobile App)

Cross-platform Flutter application for managing device provisioning with **Android Zero-touch** and **Samsung Knox Cloud Services**.

## Features

- **Authentication**: Multi-tenant client login via `clientId` and `password`.
- **Dual Enrollment Support**:
  - Android Zero-touch provisioning
  - Samsung Knox Cloud Services
- **Device Management**:
  - Real-time device inventory listing
  - Single device claim (IMEI or Serial + Manufacturer + Model)
  - Bulk device claim
  - Device unclaim
- **Barcode & QR Scanner**: Built-in camera scanning for instant IMEI/Serial input.
- **Secure Architecture**: All operations route through the Intechsys Zero-touch backend API (never exposes vendor credentials directly in the mobile client).

## Tech Stack

- **Flutter** 3.x / **Dart**
- **Mobile Scanner** (camera QR & barcode reading)
- **Http & Crypto** for network requests and secure communication

## Configuration

The app points to the backend API configured in `lib/src/core/config/app_config.dart`.

Default backend URL:
`https://intechsys-backend-prod-w2.lemondesert-86c4a20f.westus2.azurecontainerapps.io`

To run pointing to a custom backend or local environment:

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://your-api-domain.com
```

## Getting Started

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run the App

- **Android**:
  ```bash
  flutter run -d android
  ```
- **iOS** (macOS required):
  ```bash
  flutter run -d ios
  ```
- **macOS Desktop**:
  ```bash
  flutter run -d macos
  ```
- **Web**:
  ```bash
  flutter run -d chrome
  ```

### 3. Build Release Packages

- **Android APK**:
  ```bash
  flutter build apk --release --dart-define=BACKEND_BASE_URL=https://your-api-domain.com
  ```
- **Android App Bundle (AAB)**:
  ```bash
  flutter build appbundle --release --dart-define=BACKEND_BASE_URL=https://your-api-domain.com
  ```
- **iOS Archive**:
  ```bash
  flutter build ipa --release --dart-define=BACKEND_BASE_URL=https://your-api-domain.com
  ```
