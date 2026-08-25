# MediClick iOS

App nativa iOS para médicos clínicos — gestión de pacientes, turnos, recetas y chat.

## Requisitos

- Xcode 16+
- iOS 17+ (SwiftData) con fallback iOS 15+ (Core Data)
- Swift 5.9+

## Stack

- **UI:** SwiftUI
- **DB local:** SwiftData (SQLite)
- **Auth:** JWT + Keychain
- **Sync:** Motor offline-first custom
- **Arquitectura:** MVVM + Clean Architecture

## Funcionalidades

- Login con matrícula médica
- Selector de consultorio/centro médico
- Agenda de turnos con detección de conflictos cross-consultorio
- Fichas de pacientes con historia clínica
- Recetas digitales con firma
- Chat médico-paciente
- Sincronización offline-first (funciona sin internet)

## Estructura

```
MediClick/
├── Models/          → SwiftData models (SQLite local)
├── Services/        → SyncEngine, APIClient, KeychainHelper
├── ViewModels/      → MVVM view models
├── Views/           → SwiftUI views
└── Resources/       → Assets, localización
```

## Repos relacionados

- [mediclick-api](https://github.com/TU_USUARIO/mediclick-api) — Backend REST API
- [mediclick-android](https://github.com/TU_USUARIO/mediclick-android) — App Android

## Licencia

Privado — Todos los derechos reservados.
