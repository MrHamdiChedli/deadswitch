# DeadSwitch 💀🔒
> A personal safety cybersecurity mobile app built with Flutter

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)

---

## 🔍 Overview

DeadSwitch is a dead man's switch mobile application designed
to protect your data and alert your trusted contacts automatically
if something happens to you.

Set a timer → Check in daily → Miss a check-in → Everything triggers.

---

## 🎯 Problem Statement

Most people have no plan for what happens to their sensitive data
if they are detained, their phone is stolen, or they face an emergency.

DeadSwitch solves this by automating:
- Emergency alerts to trusted contacts
- Secure vault upload to cloud storage
- GPS location sharing
- Complete data wipe from device

---

## ✨ Features

### Security
| Feature | Description |
|---|---|
| PIN Lock | 4-digit PIN required to open app |
| Decoy PIN | Fake PIN shows empty app to attackers |
| Screenshot Prevention | Blocks screenshots inside app |
| Auto-lock | Locks after 1 minute of inactivity |
| Failed PIN Trigger | 5 wrong attempts = automatic trigger |

### Timer System
| Feature | Description |
|---|---|
| Custom intervals | 6h / 12h / 24h / 48h / 72h |
| Grace period | 30 min warning before trigger |
| Shake check-in | Shake phone secretly to check in |

### Trigger System
| Feature | Description |
|---|---|
| Auto trigger | Fires when timer expires |
| Panic button | Hold 3 seconds for instant trigger |
| Cloud upload | Vault files uploaded on trigger |
| Emergency email | Sent to all trusted contacts |
| GPS location | Google Maps link included |
| Personal message | Pre-written message delivered |
| Auto wipe | Full vault deletion after trigger |

### Vault
| Feature | Description |
|---|---|
| Notes | Encrypted text notes |
| Photos | Moved out of gallery to private storage |
| Documents | PDF, DOC, TXT support |

---

## 🏗️ Architecture
DeadSwitch/
├── lib/
│   ├── main.dart          # Main app + all screens
│   └── firebase_options.dart  # Firebase config
├── android/               # Android specific files
├── assets/                # App icon + images
└── pubspec.yaml           # Dependencies
---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform mobile framework |
| Dart | Programming language |
| Firebase | Backend & authentication |
| Cloud Storage | Vault file hosting |
| EmailJS | Automated email alerts |
| Geolocator | GPS location capture |
| SharedPreferences | Local data persistence |
| Crypto | Secure file signatures |
| Path Provider | Private encrypted storage |
| Shake | Motion detection for check-in |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.7+
- Android Studio
- Firebase account
- Cloud storage account
- EmailJS account

### Setup
1. Clone the repository
```bash
git clone https://github.com/YOURUSERNAME/deadswitch.git
```

2. Install dependencies
```bash
flutter pub get
```

3. Add your API keys in `lib/main.dart`:
```dart
const apiKey = 'YOUR_CLOUDINARY_API_KEY';
const apiSecret = 'YOUR_CLOUDINARY_SECRET';
const serviceId = 'YOUR_EMAILJS_SERVICE_ID';
const templateId = 'YOUR_EMAILJS_TEMPLATE_ID';
const publicKey = 'YOUR_EMAILJS_PUBLIC_KEY';
```

4. Add `google-services.json` to `android/app/`

5. Run the app
```bash
flutter run
```

---

## 📱 Screenshots

| PIN Lock | Home | Vault | Panic |
|---|---|---|---|
| coming soon | coming soon | coming soon | coming soon |

---

## 🔐 Security Considerations

- All vault files stored in private app directory
- Files removed from device gallery on vault entry
- Complete wipe after trigger confirmed
- Decoy mode prevents forced access
- Screenshot prevention active in app
- API keys stored locally, never in version control

---

## 🗺️ Roadmap

- [x] Core timer system
- [x] PIN lock with decoy mode
- [x] Secure vault
- [x] Emergency email system
- [x] GPS location sharing
- [x] Cloud storage integration
- [x] Panic button
- [x] Grace period
- [x] Shake to check-in
- [x] Activity log
- [ ] Play Store release
- [ ] iOS version
- [ ] Home screen widget
- [ ] Two-person vault rule
- [ ] Self-destructing notes
- [ ] Corporate version

---

## 👨‍💻 About

Built by **Hamdi Chedli** — passionate about cybersecurity and privacy.

This project was built from scratch with zero prior experience
as a demonstration of what curiosity and persistence can achieve.

Currently pursuing cybersecurity studies.

📧 [mrhamdi.chedli@outlook.com]
💼 [https://www.linkedin.com/in/hamdichedl/]

---

## 📄 License

This project is private. Contact for collaboration or licensing inquiries.

---

*"Privacy is not something that I'm merely entitled to,*
*it's an absolute prerequisite."* — Marlon Brando
