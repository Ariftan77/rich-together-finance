# RichTogether

An offline-first personal finance application built with Flutter for comprehensive expense tracking, budgeting, and portfolio management.

## Features

- **Expense Tracking**: Record and categorize transactions with detailed metadata
- **Budget Management**: Set and monitor budgets across multiple categories
- **Portfolio Tracking**: Track investments and asset allocations
- **Offline-First Architecture**: Full functionality without internet connectivity
- **Secure Authentication**: Biometric authentication with local_auth
- **Data Visualization**: Interactive charts and graphs powered by fl_chart
- **Modern UI**: Clean, responsive interface with Google Fonts

## Tech Stack

- **Framework**: Flutter 3.10.8+
- **State Management**: Riverpod 2.4+
- **Database**: Drift (SQLite) for local data persistence
- **Networking**: Dio for HTTP requests
- **Security**: Flutter Secure Storage & Local Authentication
- **UI**: Material Design with custom theming

## Architecture

This app follows clean architecture principles with:
- **Data Layer**: Drift database with type-safe queries
- **Domain Layer**: Business logic and use cases
- **Presentation Layer**: Riverpod providers and Flutter widgets
- **Offline-First**: All data stored locally with optional sync capabilities

## Getting Started

### Prerequisites

- Flutter SDK 3.10.8 or higher
- Dart SDK (included with Flutter)
- Android Studio / Xcode for mobile development
- An Android emulator or iOS simulator

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/RichTogether.git
cd RichTogether
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate code (Drift & Riverpod):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running the App

1. Start an emulator:
```bash
flutter emulators --launch <emulator_id>
```

2. Run the application:
```bash
flutter run
```

### Development Commands

- **Hot Reload**: Press `r` in terminal to instantly reload changes
- **Hot Restart**: Press `R` to perform a full restart
- **DevTools**: Press `v` to open Flutter DevTools in browser
- **Quit**: Press `q` to stop the app

### Building for Production

**Android:**
```bash
flutter build apk --debug (this one for debug mode, specially ad test)
flutter build apk --release
flutter build apk --release --split-per-abi
(Note: This might take a few minutes)

Once finished, navigate to: build\app\outputs\flutter-apk\

Copy the file named app-arm64-v8a-release.apk to your Samsung device. (Most modern Samsung phones use arm64-v8a architecture).
```

**iOS:**
```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── core/          # Core utilities, constants, and configurations
├── data/          # Data models, database, and repositories
├── domain/        # Business logic and use cases
├── presentation/  # UI screens and widgets
└── main.dart      # Application entry point
```

## Code Generation

This project uses code generation for:
- **Drift**: Database tables and queries
- **Riverpod**: State management providers

Run generation after modifying annotated files:
```bash
flutter pub run build_runner watch
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions or support, please open an issue on GitHub.