# Sweetmelon Angular Template

A production-ready Angular + Sweetmelon Native Bridge template.

## Structure

```
sweetmelon-angular-template/
├── android/                    # Android native
├── ios/                        # iOS (future)
├── assets/
│   └── www/                    # Angular build output (built automatically)
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── di/service_locator.dart
│   └── screens/home_screen.dart
├── sweetmelon.yaml             # Plugin config
├── angular-app/                # Angular source
│   ├── src/
│   │   ├── app/
│   │   │   ├── core/
│   │   │   │   └── native-bridge.service.ts
│   │   │   ├── app.component.ts
│   │   │   └── app.module.ts
│   │   └── assets/
│   │       └── js/
│   │           └── native-sdk.js
│   ├── angular.json
│   └── package.json
└── scripts/
    ├── build.sh
    └── dev.sh
```

## Quick Start

```bash
# Clone template
git clone https://github.com/your-org/sweetmelon-angular-template

# Install Flutter deps
flutter pub get

# Install Angular deps
cd angular-app && npm install

# Build Angular and run Flutter
./scripts/build.sh && flutter run
```

## Development Workflow

```bash
# Terminal 1: Watch Angular changes
cd angular-app && ng build --watch --output-path ../assets/www --base-href ./

# Terminal 2: Hot reload Flutter
flutter run
```
