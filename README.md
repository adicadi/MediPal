# MediPal

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Provider-blue?style=for-the-badge" alt="Provider">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</div>

MediPal is an intelligent Flutter-based personal health assistant app that provides AI-powered health insights, symptom assessment, medication management, and real-time health consultations. Designed with safety and accessibility in mind, MediPal helps users monitor their health, analyze symptoms, manage medications, and get personalized health recommendations through an intuitive and secure interface.

---

## 📱 Features

### 🔍 **Intelligent Symptom Checker**
- Guided symptom analysis with AI-generated personalized assessments
- Interactive questionnaire system for accurate health evaluation
- Save and review past symptom assessments
- Age-appropriate content and recommendations

### 💊 **Smart Medication Management**
- Comprehensive medication tracking with dosage and frequency
- Intelligent reminder system with notification support
- Low stock and refill alerts
- Medication interaction checker with smart caching

### 🤖 **AI-Powered Health Assistant**
- 24/7 AI chat for health questions and guidance
- Context-aware responses based on user profile
- Age-appropriate safety modes for minors
- Quick action buttons for common health topics

### 🏠 **Personalized Dashboard**
- Customized health insights and tips
- Quick access to all features
- Pull-to-refresh health data
- Emergency information and contacts

### 🔒 **Safety & Privacy**
- Age-appropriate content filtering
- Local data storage for privacy
- Emergency support with location-based information
- Parental guidance prompts for minors

### 📊 **Health History & Analytics**
- Comprehensive medication and symptom history
- Exportable health reports
- Interaction analysis caching
- Progress tracking and insights

---

## 📋 Supported Platforms

- ✅ **Android** (API 21+)
- ✅ **iOS** (12.0+)
- ✅ **Web** (Progressive Web App)
- ⚠️ **Desktop** (Limited support)

---

## 🚀 Installation

### Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.0.0 or higher)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) for mobile development
- Git

### Clone the Repository

```bash
git clone https://github.com/your-username/medipal.git
cd medipal
```

### Install Dependencies

```bash
flutter pub get
```

### Environment Configuration

1. Create a `.env` file in the root directory:

```env
# Add your API keys and configuration here
DEEPSEEK_API_KEY=your_api_key_here
```

2. Configure notification permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

### Build and Run

#### For Android:
```bash
flutter run
```

#### For iOS:
```bash
flutter run --debug
```

#### For Web:
```bash
flutter run -d chrome
```

---

## 📱 Usage

### Getting Started

1. **Launch the App**: Open MediPal and complete the personalized onboarding process
2. **Profile Setup**: Enter your basic information (name, age, gender) for customized recommendations
3. **Explore Features**: Navigate through the intuitive interface to access all health management tools

### Core Functionalities

#### Symptom Assessment
1. Tap "Symptom Checker" from the home screen
2. Describe your primary symptom
3. Answer guided questions for accurate assessment
4. Review your personalized health report
5. Save for future reference

#### Medication Management
1. Navigate to "Medications" tab
2. Add medications with dosage and frequency
3. Set up reminders and refill alerts
4. Check for drug interactions
5. Track medication history

#### AI Health Chat
1. Access the chat interface
2. Ask health-related questions
3. Get instant AI-powered responses
4. Save important conversations
5. Export chat history

#### Emergency Support
1. Quick access to emergency information
2. Location-based emergency contacts
3. Safety guidelines for different situations

---

## 🛠️ Technical Architecture

### Core Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.0.5
  shared_preferences: ^2.2.2
  flutter_dotenv: ^5.1.0
  timezone: ^0.9.2
  flutter_timezone: ^1.0.8
  gpt_markdown: ^0.1.2
  share_plus: ^7.2.1
  flutter_local_notifications: ^16.3.0
```

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── screens/                     # UI screens
│   ├── home_screen.dart
│   ├── onboarding_screen.dart
│   ├── chat_screen.dart
│   ├── symptom_checker_screen.dart
│   ├── medication_screen.dart
│   └── medication_warning_screen.dart
├── services/                    # Business logic
│   ├── deepseek_service.dart
│   ├── notification_service.dart
│   ├── chat_history_service.dart
│   └── emergency_service.dart
├── models/                      # Data models
├── utils/                       # Utilities
│   └── app_state.dart
└── widgets/                     # Reusable widgets
```

### Key Features Implementation

- **State Management**: Provider pattern for reactive state management
- **Local Storage**: SharedPreferences for user data persistence
- **Notifications**: Flutter Local Notifications for medication reminders
- **AI Integration**: Custom DeepSeek service for health consultations
- **Caching**: Smart caching system for medication interactions
- **Responsive Design**: Adaptive UI for different screen sizes

---

## 🧪 Testing

### Run Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=test_driver/app.dart
```

### Testing Structure

- **Unit Tests**: Core business logic and utilities
- **Widget Tests**: UI component testing
- **Integration Tests**: End-to-end user flow testing

---

## 🔧 Configuration

### Notification Setup

Enable exact alarm permissions for accurate medication reminders:

1. The app will prompt for permissions on first medication reminder setup
2. Grant "Alarms & reminders" permission in system settings
3. Test notifications using the built-in test feature

### Age-Appropriate Content

The app automatically adjusts content based on user age:

- **Minors (<18)**: Safe mode with parental guidance prompts
- **Young Adults (18-25)**: Focus on building healthy habits
- **Adults (25+)**: Full feature access with comprehensive health insights

---

## 🤝 Contributing

We welcome contributions to MediPal! Please follow these guidelines:

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines

- Follow Flutter and Dart style conventions
- Write tests for new features
- Update documentation as needed
- Ensure age-appropriate content guidelines are maintained
- Test across multiple platforms

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Prioritize user safety and privacy
- Maintain high code quality standards

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 MediPal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 📞 Support

### Get Help

- 📧 **Email**: adicadi158+medipal@gmail.com
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/adicadi/medipal/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/adicadi/medipal/discussions)

### Medical Disclaimer

⚠️ **Important**: MediPal is designed for informational purposes only and should not replace professional medical advice, diagnosis, or treatment. Always consult qualified healthcare professionals for medical decisions.

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- DeepSeek for AI capabilities
- The open-source community for valuable packages
- Healthcare professionals who provided guidance on content safety

---

## 🗺️ Roadmap

### Upcoming Features

- [ ] Wearable device integration
- [ ] Telemedicine consultation booking
- [ ] Advanced health analytics
- [ ] Multi-language support
- [ ] Family health management
- [ ] Doctor appointment scheduling

---

<div align="center">
  <p>Made with ❤️ for better health management</p>
  <p>Star ⭐ this repository if you find it helpful!</p>
</div>
