# Paper Lock

Paper Lock is a secure, offline-first document wallet built with Flutter. It helps users store personal documents and images on-device, protect access with biometric or device authentication, organize records by category, and share or back up files safely without cloud dependency.

## Overview

Paper Lock is designed for privacy-focused document management. Instead of uploading files to a remote server, all data is handled locally on the device. Users can add files from camera, gallery, and file picker, then edit metadata and attachments later.

## Core Features

- Offline-first local document storage
- Add documents using camera, gallery, or file upload
- Multiple attachments per document
- Edit documents with add/remove attachment support
- Category-based organization
- App lock with biometric or device passcode authentication
- Settings toggle to enable or disable app lock
- Export and import full backup as ZIP
- Share files directly through system share sheet
- Convert image-based document sets to PDF for sharing
- Light and dark theme support

## Privacy and Security

- No backend server integration
- No cloud sync requirement
- No account login required
- Data stored locally in SQLite and app-managed file storage
- Security preference stored in secure local storage
- Biometric and device authentication supported via OS APIs

## Technology Stack

- Flutter
- sqflite (SQLite local database)
- local_auth (biometric and device authentication)
- flutter_secure_storage (secure local settings)
- image_picker and file_picker (import files/images)
- pdf (generate PDF for image-based sharing)
- share_plus (native sharing)
- path_provider and path (local file management)

## How It Works

1. User adds one or more files (images or documents).
2. App copies selected files into app-local storage.
3. Metadata and file paths are stored in SQLite.
4. User can edit title, description, category, and attachments.
5. User can share document files directly or as a generated PDF.
6. User can export and restore complete backups using ZIP.
7. If app lock is enabled, authentication is required at app launch.

## Project Structure

- `lib/main.dart`: App entry and theme setup
- `lib/screens/`: UI screens (home, add, edit, detail, settings, auth)
- `lib/db/database_helper.dart`: SQLite operations
- `lib/models/document.dart`: Document data model
- `lib/utils/`: Categories, theme provider, backup helper, string extensions

## Build and Run

### Prerequisites

- Flutter SDK (stable)
- Android Studio / VS Code with Flutter plugins
- Android device or emulator

### Local Run

```bash
flutter pub get
flutter run
```

### Production APK

```bash
flutter build apk --release
```

Generated file:

- `build/app/outputs/flutter-apk/app-release.apk`

## Use Cases

- Store ID proofs, receipts, certificates, and personal records
- Keep scanned copies of important documents
- Carry critical files securely while traveling
- Maintain private records without cloud services

## Current Status

- Android production APK build completed
- GitHub repository initialized and pushed on `main`
- App branding updated to **Paper Lock**

## Future Improvements

- Search by title/description/category
- Attachment reordering for custom page sequence
- In-app PDF preview before sharing
- Optional encrypted file-at-rest layer
- Multi-language support

