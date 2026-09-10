# Expense App (Working Name)

A production-quality personal expense and income tracking mobile application built with Flutter, Riverpod, Drift (SQLite), and Material 3.

---

## Architecture Overview

This project follows **Feature-First Clean Architecture**:

- **`lib/app/`**: Root app widget, Material 3 theme design tokens (`AppColors`, `AppTypography`, `AppSpacing`, `AppTheme`), and GoRouter routing configuration.
- **`lib/core/`**: Centralized SQLite database configuration (`AppDatabase`), tables, providers, MoneyUtils (minor unit handling), and core shared utilities.
- **`lib/features/`**: Feature modules (`dashboard`, `transactions`, `screenshot_import`, `insights`, `settings`), each separated into `data/`, `domain/`, and `presentation/` layers.
- **`lib/shared/`**: App-wide domain enums (`TransactionType`, `TransactionSource`) and shared models/widgets.

---

## Folder Structure

```
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
│       ├── app_colors.dart
│       ├── app_typography.dart
│       ├── app_spacing.dart
│       └── app_theme.dart
│
├── core/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── database_tables.dart
│   │   └── database_provider.dart
│   ├── errors/
│   ├── constants/
│   ├── extensions/
│   ├── utils/
│   │   └── money_utils.dart
│   └── widgets/
│
├── features/
│   ├── dashboard/
│   ├── transactions/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── drift_transaction_repository.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── transaction_entity.dart
│   │   │   └── repositories/
│   │   │       └── transaction_repository.dart
│   │   └── presentation/
│   │       └── providers/
│   │           └── transaction_providers.dart
│   ├── screenshot_import/
│   ├── insights/
│   └── settings/
│
├── shared/
│   ├── enums/
│   │   └── transaction_enums.dart
│   ├── models/
│   └── widgets/
│
└── main.dart
```

---

## Installation & Setup

1. **Clone & Navigate**:
   ```bash
   cd e:/Dev/scanex
   ```

2. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Code Generation (Drift DB)**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run Tests**:
   ```bash
   flutter test
   ```

5. **Run App (Android / Mobile)**:
   ```bash
   flutter run
   ```

---

## Current V1 Scope & Phase 1 Boundaries

**Phase 1 (Active)** focuses strictly on project foundation, Clean Architecture, SQLite database setup with minor units, theme palette, routing foundation, and Riverpod DI.

**Intentionally NOT Implemented in Phase 1**:
- Application UI screens (Dashboard, Analytics, Transaction lists, Settings)
- OCR / Vision AI logic for screenshot parsing
- Authentication / Firebase / Supabase / Google Sign-In
- Cloud sync / Cloud APIs (App is 100% local-first)
