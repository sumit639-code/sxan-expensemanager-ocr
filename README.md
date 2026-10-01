# 📱 ScanEx — Smart, Private & Local-First Expense Manager

<p align="center">
  <img src="assets/icon/sxan.png" width="120" height="120" alt="ScanEx Logo" />
</p>

<p align="center">
  <strong>Effortless expense tracking powered by on-device OCR, automated Bank SMS intelligence, and zero-compromise privacy.</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Architecture-Clean%20%2B%20Riverpod-6C5CE7" alt="Architecture">
  <img src="https://img.shields.io/badge/Database-Drift%20(SQLite)-009688" alt="Drift SQLite">
  <img src="https://img.shields.io/badge/Privacy-100%25%20Offline%20First-4CAF50" alt="100% Offline">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform Android">
</p>

---

## 🌟 Overview

**ScanEx** is an open-source, production-grade personal finance and expense management mobile application. Designed from the ground up to respect user privacy, ScanEx runs **100% offline on your device** without requiring cloud accounts, remote servers, or third-party analytics.

Whether you're paying via **UPI (Google Pay, PhonePe, Paytm, CRED)**, debit/credit cards, or cash, ScanEx captures and categorizes your transactions seamlessly through **On-Device Machine Learning OCR** and **Smart Bank SMS Detection**.

---

## ✨ Key Features

### 📸 1. Instant Receipt & Payment Screenshot OCR
- **Direct Share Extension**: Take a payment screenshot in GPay, PhonePe, or Paytm and tap **Share → ScanEx**. The app parses the transaction in milliseconds and stages it in your inbox.
- **On-Device ML Engine**: Powered by an embedded ONNX vision pipeline and Google MLKit fallback. No images are ever uploaded to the internet.
- **Auto-Extraction**: Accurately extracts merchant/payee name, transaction amount, date/time, and auto-assigns relevant spending categories.

### 📩 2. Automated Bank & UPI SMS Detection
- **Real-Time Background Sync**: Catches debit and credit transaction SMS from major Indian & global banks (HDFC, SBI, ICICI, Axis, Kotak, PNB, etc.) in real time.
- **Inbox Staging**: SMS transactions land in your Pending Inbox for quick 1-tap approval so your main ledger stays clean and verified.
- **Duplicate Prevention**: Multi-layered fuzzy duplicate detector matches SMS timestamps with manual entries or screenshot imports to prevent double-counting.

### 🛡️ 3. Smart Privacy & Spam/OTP Restriction
- **100% On-Device Filtering**: Only genuine financial transaction messages are parsed.
- **Zero OTP or Spam Access**: OTPs, verification codes, personal contacts, promotional discounts, loan spam, and lottery messages are **strictly filtered out and discarded immediately**.
- **Configurable Exceptions**: Customize keyword exclusion lists to block specific promo keywords forever.

### 🎨 4. Deep Personalization & Theme Engine
- **8 Curated Accent Palettes**: Brand Purple, Royal Violet, Electric Indigo, Ocean Blue, Emerald Green, Sunset Orange, Radiant Rose, and Vibrant Teal.
- **Appearance Modes**: Full support for System Default, Crisp Light Mode, Sleek Dark Mode, and True-Black OLED styling.
- **Typography & Card Styling**: Choose between 8 font presets and customize card corner radii and surface elevations.
- **Multi-Currency Support**: Native formatting for `₹` (INR), `$` (USD), `€` (EUR), `£` (GBP), `¥` (JPY/CNY), `₩` (KRW), and more.

### 🔒 5. Zero Telemetry & Local SQLite Storage
- **Drift (SQLite)**: High-speed relational storage with reactive streams.
- **Minor-Unit Financial Math**: Zero floating-point roundoff errors (all balances stored internally in minor units / paise).
- **JSON Data Backup & Restore**: Export your full transaction history anytime in standard JSON format.

---

## 🛡️ Safety & Google Play Protect Notice

When downloading and installing the standalone APK release directly on Android, you may see a warning from **Google Play Protect**:

<p align="center">
  <img src="https://raw.githubusercontent.com/google/material-design-icons/master/png/action/shield/materialicons/48dp/2x/baseline_shield_black_48dp.png" width="40" height="40" alt="Shield" />
</p>

### Why does Google Play Protect show a warning?
> **Play Protect warns users whenever an APK is installed outside the Google Play Store (sideloaded) and has not undergone Google's paid cloud certification process.** 
>
> Because ScanEx is **100% open-source, non-commercial, and free of proprietary trackers**, the APK is directly compiled from this repository and signed with a release developer key.

### Is ScanEx Safe to Use?
**Yes, ScanEx is 100% safe and private:**
1. **Fully Auditable**: You can inspect every single line of Dart, Kotlin, and Gradle code in this repository.
2. **Zero Internet Traffic**: ScanEx requires no server accounts and never sends your financial data or SMS anywhere.
3. **No Trackers / Ads**: ScanEx has zero advertisement SDKs, zero Facebook/Google tracking SDKs, and zero telemetry.

### 📲 How to Install the APK:
1. Download the latest `scanex-release.apk` from the [GitHub Releases](../../releases) section.
2. Tap the downloaded `.apk` file to start installation.
3. When the **"Blocked by Play Protect"** or **"Unrecognized app"** prompt appears:
   - Tap **"More details"** (or the dropdown arrow).
   - Tap **"Install anyway"**.
4. Once installed, launch ScanEx and enjoy complete financial control!

---

## 🏗️ Architecture & Tech Stack

```
lib/
├── app/                  # Application initialization, design tokens & GoRouter
│   ├── router/           # Navigation routes & splash redirect logic
│   └── theme/            # Theme tokens, colors, typography, and card styles
├── core/                 # Shared database, money math, storage & audio services
│   ├── database/         # Drift SQLite schemas, queries & DAOs
│   ├── services/         # Audio feedback and sound effects
│   ├── storage/          # SharedPreferences & settings persistence
│   └── utils/            # MoneyUtils minor-unit arithmetic
├── features/             # Feature-driven modular architecture
│   ├── onboarding/       # 6-Step animated setup & onboarding experience
│   ├── dashboard/        # Financial summary cards, charts & quick actions
│   ├── transactions/     # Ledger management, filters, and transaction editor
│   ├── import/           # On-device OCR parser, direct share handler & Bank SMS service
│   └── settings/         # Appearance, SMS exceptions, OCR engine & data management
└── shared/               # Reusable domain entities, enums, buttons, and inputs
```

### Key Libraries
- **Framework**: [Flutter](https://flutter.dev) (Dart 3.10+)
- **State Management**: [Riverpod 2.6](https://riverpod.dev) + StateNotifiers
- **Local Database**: [Drift](https://drift.simonbinder.eu/) (SQLite) with reactive streams
- **Routing**: [GoRouter 14](https://pub.dev/packages/go_router)
- **Computer Vision / OCR**: [Google MLKit](https://pub.dev/packages/google_mlkit_text_recognition) & [ONNX Runtime](https://onnxruntime.ai/)
- **Audio Feedback**: [Audioplayers](https://pub.dev/packages/audioplayers)

---

## 🚀 Getting Started & Local Development

### Prerequisites
- **Flutter SDK**: `>= 3.10.0`
- **Dart SDK**: `>= 3.0.0`
- **Android Studio / SDK**: Android SDK 21+ (Android 5.0 Lollipop or later)

### Build Instructions

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/sumit639-code/sxan-expensemanager-ocr.git
   cd sxan-expensemanager-ocr
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Code Generation** (for Drift SQLite & Freezed models):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```

5. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```
   The compiled APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔒 Privacy Guarantee

- **No Remote Servers**: Your data lives exclusively in an encrypted SQLite database on your physical device.
- **No Cloud Accounts**: No email, phone number, or login credentials required.
- **Local SMS Parsing**: Bank SMS text is parsed instantaneously in memory and immediately discarded. Unrelated messages (OTPs, personal chats, spam) are never stored or logged.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author & Contributions

Created with ❤️ by **Sumit Kumar Dandia**.

Contributions, bug reports, and feature suggestions are always welcome! Feel free to fork the repository, open an issue, or submit a pull request.
