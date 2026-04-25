# 📄 PDify - Your Smart AI Workspace

PDify is an intelligent, AI-powered document management and study assistant built with Flutter. It allows users to upload documents (PDFs/Images), automatically generate comprehensive summaries, create structured exam notes, and chat directly with their files using the power of Google's Gemini AI.

## ✨ Key Features

*   **🧠 AI Summarizer & Exam Notes**: Instantly transform lengthy PDFs and study materials into concise summaries, chapter breakdowns, and structured exam notes (Key Definitions, Core Concepts, Quick Revision).
*   **💬 Chat with your Documents**: An interactive AI chat interface that lets you ask questions and extract precise insights directly from your uploaded documents.
*   **🔍 Advanced OCR**: Extract text seamlessly from images using highly accurate Optical Character Recognition powered by Gemini.
*   **🔄 Document Conversion**: Powerful conversion tools to easily transform files between various formats (e.g., Image to PDF, Text to PDF) directly within the app.
*   **🎙️ Voice Interaction**: Features Speech-to-Text for hands-free querying and Text-to-Speech (TTS) to read your generated notes out loud.
*   **📂 Smart Organization**: Manage your files with custom folders, bookmark your most important notes, and use real-time search filtering to find what you need instantly.
*   **🖍️ PDF Viewing & Highlighting**: Native PDF viewing experience with the ability to highlight important sections for quick reference.
*   **☁️ Cloud Sync**: Fully integrated with Firebase (Auth, Firestore, Storage) to keep your documents and notes securely synced across devices.
*   **🔐 Secure Authentication**: Supports traditional Email/Password login as well as Google Sign-In.

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **AI Engine**: [Google Generative AI](https://pub.dev/packages/google_generative_ai) (Gemini 2.5 Flash)
*   **Backend & Database**: Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Functions)
*   **State Management**: Provider
*   **Monetization**: Google Mobile Ads (AdMob)
*   **Key Packages**: `pdfx`, `flutter_tts`, `speech_to_text`, `flutter_dotenv`

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (^3.10.8)
*   Android Studio / Xcode for emulators and building
*   A Firebase Project
*   A Google Gemini API Key

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/yourusername/pdify.git
    cd pdify
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Variables Setup**
    This project uses `flutter_dotenv` to manage sensitive API keys. 
    Create a `.env` file in the root directory of the project and add your Gemini API Key:
    ```env
    GEMINI_API_KEY=your_gemini_api_key_here
    ```

4.  **Firebase Configuration**
    Ensure you have your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) configured in their respective directories via the Firebase CLI (`flutterfire configure`).

5.  **Run the App**
    ```bash
    flutter run
    ```

## 📱 Screenshots & UI

*(Add screenshots of your Dashboard, AI Chat, PDF Viewer, and Exam Notes here)*

## 🛡️ License

This project is proprietary and confidential.
