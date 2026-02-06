# MediPal

MediPal is a Flutter-based personal health assistant that combines AI chat, symptom guidance, medication tracking, and wearable insights with a safety-first, privacy-aware design.

## Highlights
- AI health chat with age-appropriate safety modes.
- Symptom guidance and medication safety tools.
- Wearable insights via Health Connect (Android).
- Smart reminders and refill alerts.
- Privacy-first: aggregates only by default for wearables.

## Screens
Screenshots are in `Screenshots/`.

## Features
### AI Chat
- Context-aware, health-only assistant.
- Private chat mode (no autosave).
- Streaming responses with stop control.
- Quick topic chips for new chats.

### Wearables
- Health Connect integration (steps, HR, sleep).
- Aggregated summaries, trends, and AI insights.
- Cached AI insights to reduce API usage.

### Medications
- Track meds, dosages, schedules.
- Reminder notifications.
- Refill alerts.
- Interaction checks (with caching).

### Safety & Privacy
- Age-aware responses (minor mode).
- Local data storage using SharedPreferences.
- No raw wearable time-series by default.

## Tech Stack
- Flutter + Dart
- Provider state management
- DeepSeek API for AI
- Health Connect (Android)
- SharedPreferences for local caching

## Project Structure
```
lib/
  app/            # App shell & routing
  screens/        # UI screens
  services/       # API + business logic
  models/         # Data models
  utils/          # App state & helpers
  widgets/        # Reusable widgets
```

## Setup
### Requirements
- Flutter SDK (3.x)
- Android Studio or Xcode

### Install
```bash
flutter pub get
```

### Environment
Create `.env` (see `.env.example`):
```
DEEPSEEK_API_KEY=your_key_here
```

### Run
```bash
flutter run
```

### Release
```bash
flutter run --release
```

## Wearables (Android)
1. Install **Health Connect**.
2. Grant permissions in the app.
3. Insights will use aggregate summaries only.

## Notes on AI Insights Caching
AI health insights are cached by wearable data payload. If only the timestamp changes, cached insights are reused to avoid extra API calls.

## License
MIT. See `LICENSE` if present.

## Disclaimer
MediPal provides informational guidance only and is not a substitute for professional medical care.
