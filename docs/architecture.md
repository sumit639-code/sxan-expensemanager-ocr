# Architecture & Dependency Flow

This document details the Clean Architecture dependency flow and design rules enforced in Expense App.

---

## Layer Dependency Rules

```
Presentation (Riverpod & GoRouter)
      ↓
Application / Providers
      ↓
Domain (Entities & Repository Contracts)
      ↓
Data Implementation (Drift / SQLite Repositories)
      ↓
Local Database (AppDatabase / SQLite3)
```

### Key Principles

1. **Pure Domain Layer**: The domain layer (`lib/features/*/domain`) contains pure Dart entities and abstract repository interface contracts (`TransactionRepository`). It contains **zero** imports from Flutter UI, Drift, SQLite, or external frameworks.
2. **Data Decoupling**: Database rows (`TransactionData`) are converted to pure Domain entities (`Transaction`) inside the data layer repository (`DriftTransactionRepository`).
3. **UI Isolation**: The presentation layer never queries `AppDatabase` or Drift tables directly. All interactions flow through Riverpod providers exposing `TransactionRepository`.
4. **Local-First & Cloud-Ready**: Repositories are defined as abstract contracts. Future sync engines can implement `SyncingTransactionRepository` without altering domain logic or UI code.
5. **Exact Money Precision**: Financial values are stored as integers representing minor currency units (paise/cents) to eliminate floating-point calculation errors.
