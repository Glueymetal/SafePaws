# SafePaws

**Smart Campus Dog Safety & Feeding Management System**

A Flutter-based mobile application providing real-time dog tracking, AI-powered safety assistance, and community-driven feeding coordination. Built with Firebase and Google's Gemini AI.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini-2.5%20Flash-4285F4?logo=google)](https://ai.google.dev)

---

## Features

- **Real-Time Campus Mapping** - Interactive satellite map with live dog location tracking and status indicators
- **Smart Reporting** - Quick dog sighting reports with location, count, and behavioral assessment
- **Feeding Management** - Community coordination system with time-based feeding status and alerts
- **Paws AI Assistant** - Gemini-powered chatbot for location-specific safety advice and dog behavior guidance
- **Analytics Dashboard** - Usage tracking, peak hours analysis, and feeding statistics

---

## Tech Stack

**Frontend:** Flutter 3.0+, Dart, flutter_map, Material Design 3  
**Backend:** Firebase (Firestore, Analytics, Cloud Functions)  
**AI:** Google Gemini 2.5 Flash API  
**State Management:** StatefulWidgets with StreamBuilder

---

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK 2.19+
- Firebase account
- Gemini API key

### Installation

```bash
# Clone repository
git clone https://github.com/Glueymetal/SafePaws.git
cd SafePaws

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure
```

### Setup API Keys

Create `lib/config/secrets.dart`:

```dart
class Secrets {
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
}
```

Get your API key: [Google AI Studio](https://makersuite.google.com/app/apikey)

### Run

```bash
flutter run
```

---

## Project Structure

```
lib/
├── config/
│   └── secrets.dart              # API keys (gitignored)
├── models/                       # Data models
├── screens/                      # UI screens
│   ├── home_screen.dart          # Main dashboard
│   ├── add_report_screen.dart    # Report submission
│   └── paws_chat_screen.dart     # AI chat
├── services/                     # Business logic
│   ├── firestore_service.dart    # Firebase operations
│   ├── paws_ai_service.dart      # Gemini AI integration
│   └── feeding_service.dart      # Feeding management
├── widgets/                      # Reusable components
└── utils/                        # Helper functions
```

---

## Security

### API Key Management

**Critical:** Never commit API keys to version control.

- API keys stored in `lib/config/secrets.dart`
- File excluded via `.gitignore`
- Each developer creates own local secrets file

### Firebase Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reports/{reportId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /feeding_status/{locationId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

---

## Key Components

### Campus Locations

- Clock Tower
- Main Canteen
- Sports Complex
- Academic Block 1, 2, 3

### Report Status Levels

- **Safe** - Low presence, calm behavior
- **High Presence** - Multiple dogs, monitor recommended
- **Danger** - Aggressive behavior, avoid area

### Feeding Status

- **Not Fed** - No feeding recorded today
- **Needs Feeding Soon** - 4-8 hours since last feeding
- **Needs Feeding** - Over 8 hours, urgent
- **Recently Fed** - Fed within last 4 hours

### AI Capabilities

- Location-specific safety information
- Real-time report context integration
- Dog behavior tips and guidance
- Comprehensive fallback system (10+ patterns)
- Intelligent caching to reduce API calls

---

## Analytics

Tracked events via Firebase Analytics:

- `home_viewed` - Dashboard visits
- `paws_chat_opened` - AI assistant usage
- `add_report_button_tapped` - Report submissions
- `location_marked_fed` - Feeding actions
- `view_reports_selected` / `view_feeding_selected` - Tab navigation

---


**Guidelines:**
- Follow Flutter best practices
- Never commit API keys or secrets
- Test on both Android and iOS
- Update documentation for new features

---

## License

All rights reserved. This project is not currently licensed for public use or distribution.

---

## Support

- **Issues:** [GitHub Issues](https://github.com/Glueymetal/SafePaws/issues)
- **Documentation:** [Wiki](https://github.com/Glueymetal/SafePaws/wiki)

---

<div align="center">

**Made for Campus Safety**

Star us on GitHub if SafePaws helps your community

</div>
