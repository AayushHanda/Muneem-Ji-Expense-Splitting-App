# Muneem Ji — Smart Expense Tracker & Bill Splitter

<p align="center">
  <img src="assets/images/app_logo.png" width="100" alt="Muneem Ji Logo" />
</p>

<p align="center">
  <b>Your personal AI-powered financial assistant.</b><br/>
  Track daily expenses, split bills with friends, and get intelligent insights — all in one beautiful app.
</p>

---

## 📸 App Screenshots

<p align="center">
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/caf2de3f-e57f-4be8-b297-314fb2db37be" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/5acd3e87-dd53-44c0-ad1b-a1ccdbe60c82" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/5caddb62-5a47-4738-8283-171a7fc119e6" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/9caf1e10-9e71-4ea6-8fdd-7031c52e7bb9" />
</p>

<p align="center">
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/5e348209-449a-4a01-af43-3456426ade91" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/58432629-3add-4dd6-b6f3-59693d1575c4" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/3b4bc634-5b66-431d-a7f7-069f72c48d1a" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/d6aafd77-8d38-423a-af63-8912b50d778f" />
</p>

<p align="center">
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/f4ccf06a-d3f0-46d9-a61e-26cfece459d1" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/3820d890-90cb-43e9-8621-08720fd98c40" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/b38e7eb8-c5a1-4fed-a249-d25957dc3d18" />
  <img width="20%" alt="image" src="https://github.com/user-attachments/assets/f12c156f-3fc3-4899-9014-a22344edb26e" />
</p>

---

## 🚀 Key Features

### 💬 AI-Powered Chat Assistant *(New)*
- Talk to **Muneem Ji**, your personal financial AI built on **Gemini 2.5 Flash**.
- Ask natural language questions like *"How much do I owe total?"* or *"Summary for travel expenses 2025"*.
- The assistant has full context of your balances, groups, and spending history.
- Contextual suggestion chips on first launch for easy onboarding.

### 📒 Daily Expenditure Tracker *(New)*
- A dedicated **personal expense log** separate from group splitting.
- Filter by **Day / Month / Year / Custom Date Range**.
- **Category breakdown** with rich icons and color-coding (Food, Transport, Shopping, etc.).
- **Budget Limits**: Set a monthly budget and track progress with a live progress bar.
- **Biometric Lock**: Protect your personal log with fingerprint or face authentication.
- **Share Log**: Share your expenditure log with family or colleagues via email for collaborative tracking.

### 📊 Expenditure Analytics *(New)*
- **Spending Heatmap**: Calendar view showing intensity of spend per day using color gradients.
- **Category Pie Chart**: Visual breakdown of where your money goes each month.
- **Monthly Trend Chart**: 6-month line chart to visualize spending patterns over time.

### 📄 PDF Report Export *(New)*
- Generate a **professional PDF report** of your monthly expenditures with one tap.
- Shareable via any app (email, WhatsApp, Drive, etc.) using the system share sheet.

### 📊 Activity Feed
- Stay updated with a social-style log of all expense additions, edits, and settlements.
- Commenting system to discuss expenses directly within the app.

### 🔍 OCR Receipt Scanning
- Save time with on-device text recognition using **Google ML Kit**.
- Simply snap a photo of your receipt to auto-fill amounts.

### 🔒 Biometric Authentication
- Protect your daily expenditure data with **fingerprint / face unlock** (using `local_auth`).

### 📈 Deep Analytics
- Visualize your group spending with interactive charts and category-wise breakdowns.

### 👥 Group Management & Smart Settle Up
- Create groups for trips, households, or shared events.
- Intuitive settle-up UI to track who owes whom and settle debts quickly.

### ☁️ Firebase Backend
- **Real-time sync** across devices via Cloud Firestore.
- **Secure Authentication** via Firebase Auth.
- **Cloud Storage** for profile photos via Firebase Storage.

---

## 🏗️ Architecture & Folder Structure

The project follows a clean, modular structure using the **Provider** pattern for state management and **Service-based** architecture for external interactions:

```
lib/
├── main.dart                          # App entry point & route configuration
├── models/
│   ├── expense.dart                   # Group expense model
│   ├── group.dart                     # Group model
│   ├── activity.dart                  # Activity feed model
│   ├── chat_message.dart              # AI chat message model (New)
│   └── daily_expenditure.dart         # Personal expense model (New)
├── providers/
│   ├── expense_provider.dart          # Group expense state
│   ├── chat_provider.dart             # AI chat state (New)
│   └── daily_expenditure_provider.dart # Personal expense state (New)
├── screens/
│   ├── dashboard_screen.dart          # Main dashboard
│   ├── chat_screen.dart               # AI assistant chat UI (New)
│   ├── daily_expenditure_list_screen.dart # Personal expense list (New)
│   ├── daily_expense_screen.dart      # Daily expense overview (New)
│   ├── expenditure_analytics_screen.dart  # Heatmap + charts (New)
│   ├── add_daily_expenditure_screen.dart  # Add personal expense (New)
│   ├── analytics_screen.dart          # Group analytics
│   ├── add_expense_screen.dart        # Add group expense
│   ├── profile_screen.dart            # User profile
│   └── ...
├── services/
│   ├── ai_assistant_service.dart      # Gemini AI integration (New)
│   ├── daily_expenditure_service.dart # Personal expense Firestore ops (New)
│   ├── report_service.dart            # PDF generation (New)
│   ├── auth_service.dart              # Firebase authentication
│   ├── firestore_service.dart         # Group expense Firestore ops
│   └── user_service.dart              # User data management
└── utils/
    ├── theme.dart                     # Design system & color tokens
    └── formatters.dart                # Indian currency formatter
```

---

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| **Framework** | Flutter (Dart) |
| **Backend** | Firebase (Auth, Firestore, Storage, FCM) |
| **AI** | Google Gemini 2.5 Flash (`google_generative_ai`) |
| **OCR** | Google ML Kit Text Recognition |
| **Charts** | Fl Chart |
| **PDF** | `pdf` + `printing` packages |
| **Calendar** | `table_calendar` |
| **Biometrics** | `local_auth` |
| **State Management** | Provider |
| **Notifications** | Firebase Cloud Messaging |

---

## ⚙️ Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / VS Code with Flutter extension
- A Firebase project configured for Android & iOS

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AayushHanda/Muneem-Ji-Expense-Splitting-App.git
   cd Muneem-Ji-Expense-Splitting-App
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup:**
   - Add `google-services.json` to `android/app/`
   - Add `GoogleService-Info.plist` to `ios/Runner/`

4. **Run the app:**
   ```bash
   flutter run
   ```

### Environment Variables

The AI chat feature uses the Gemini API. The key is embedded at build time. To use your own key:
```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

---

## 🗺️ Future Roadmap

- **Debt Simplification**: Automatically minimize the number of payments required between group members.
- **Complex Splitting**: Support for unequal splits, percentages, and custom shares.
- **Recurring Expenses**: Automate monthly bills and subscriptions.
- **Multi-currency Support**: Manage expenses across different regions with live exchange rates.
- **Voice Input**: Ask the AI assistant using speech-to-text.
- **Shared Budgets**: Collaborative budget setting for groups.

---

## 📄 License

**Proprietary / All Rights Reserved.**

Copyright (c) 2026 Muneem Ji Project. This project is private property. Any unauthorized use, publication, or distribution (including publishing on app stores) is strictly prohibited as per the [LICENSE](LICENSE) file.
