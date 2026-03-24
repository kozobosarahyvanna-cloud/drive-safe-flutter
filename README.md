# 🚗 DriveSafe — Dangerous Driving Detector

> Real-time driving behavior analysis using smartphone sensors

![Flutter](https://img.shields.io/badge/Flutter-3.41-blue)
![Dart](https://img.shields.io/badge/Dart-3.11-blue)
![Android](https://img.shields.io/badge/Android-13+-green)
![AdMob](https://img.shields.io/badge/AdMob-Integrated-orange)

---

## 📱 About

**DriveSafe** is a Flutter/Dart mobile application that analyzes driving behavior 
in real-time using the smartphone's built-in sensors. It detects dangerous events, 
computes a safety score, and provides a detailed trip report.

Developed as part of **SE 3242 — Android Application Development**  
**ICT University, Yaoundé, Cameroon** — *Engr. Daniel MOUNE*

---

## ✨ Features

- **Real-time Accelerometer** — Detects hard brakes and violent accelerations
- **Real-time Gyroscope** — Detects skids and sharp turns
- **Live Safety Score** — Animated score from 0 to 100
- **Oscilloscope Charts** — Real-time sensor data visualization
- **Haptic Feedback** — Phone vibrates on dangerous events
- **Trip Report** — Detailed breakdown of all detected events
- **Google AdMob** — Rewarded video ad to unlock full report
- **Premium UI** — Gold & black luxury design

---

## 🏗️ OOP Concepts Applied

| Concept | Week | Implementation |
|---------|------|----------------|
| `data class` | Week 1 | `DrivingEvent`, copyWith() |
| `null safety` | Week 1 | `StreamSubscription?`, nullable sensors |
| `when expression` | Week 1 | `_detectEvent()`, `getRating()` |
| `List<T>` | Week 1 | `List<DrivingEvent>`, `List<FlSpot>` |
| `abstract class` | Week 2 | `DriveAnalyzer`, `Scorable`, `Reportable` |
| `inheritance` | Week 2 | `SafetyAnalyzer extends DriveAnalyzer` |
| `interface` | Week 2 | `implements Scorable, Reportable` |
| `sealed class` | Week 2 | `DriveState`, `DriveIdle`, `DriveActive` |
| `Generics Box<T>` | Week 3 | `Box<double>` for sensor values |
| `maxOf()` | Week 3 | Generic function for max intensity |

---

## 🛠️ Tech Stack

- **Flutter** 3.41.2
- **Dart** 3.11.0
- **sensors_plus** — Accelerometer & Gyroscope
- **fl_chart** — Real-time charts
- **google_mobile_ads** — AdMob integration
- **vibration** — Haptic feedback
- **shared_preferences** — Local storage

---

## 🚀 Installation
```bash
# Clone the repository
git clone https://github.com/kozobosarahyvanna-cloud/drive-safe-flutter.git
cd drive-safe-flutter

# Install dependencies
flutter pub get

# Run on Android device
flutter run -d <device_id>

# Build APK
flutter build apk --release
```

---

## 👥 Team

| Name | Role | GitHub |
|------|------|--------|
| Kozobo Sarah Yvanna| Flutter/Dart Developer | [@kozobosarahyvanna-cloud](https://github.com/kozobosarahyvanna-cloud) |
| Memadji Larissa| Kotlin Developer | [@Missa6214](https://github.com/Missa6214) |

---

## 📚 Course

**SE 3242 — Android Application Development**  
Professor: **Engr. Daniel MOUNE**  
Institution: **ICT University, Yaoundé, Cameroon**  
Academic Year: **2025-2026**

## Dernière mise à jour
Export Excel, JSON et documentation ajoutés - Mars 2026
