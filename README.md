# Vocalin (窝聚)

Vocalin is a shared space application for loved ones, designed to provide a private, 1-on-1 or small group environment for sharing moments, messages, and wishes.

## Features

### 1. Home (首页)

- **Companion Timer**: Shows how long you have been together.
- **Real-time Status**: Set and view current status (e.g., "Working", "Miss you").
- **Blackboard**: A pinned message board for important notes.
- **Recent Activity**: Quick view of the latest shared content.

### 2. Records (记录)

- **Album**: Shared photo gallery.
- **Notes**: Sticky notes and messages.
- **Wishlist**: Shared to-do list for couple goals.

### 3. Profile (我的)

- **Space Management**: View invite code to invite your partner.
- **Settings**: Customize background, export content, etc.

## Project Structure

```
lib/
├── main.dart           # Entry point
├── src/
│   ├── app.dart        # App configuration (Theme, Routes)
│   ├── models/         # Data models (User, Group, Post, Wish)
│   ├── screens/        # UI Screens
│   │   ├── home/       # Home screen widgets
│   │   ├── records/    # Records screen and tabs
│   │   ├── profile/    # Profile screen
│   │   └── main_screen.dart # Bottom navigation scaffold
│   ├── services/       # Data services (Mock backend)
│   └── widgets/        # Reusable widgets
└── test/               # Unit tests
```

## Getting Started

1.  **Prerequisites**: Ensure you have Flutter installed.
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Configure Backend Base URL**:
    Edit `.env` and set `VOCALIN_API_BASE_URL` to the backend you want.

    Example for local Go service:

    ```bash
    VOCALIN_API_BASE_URL=http://localhost:8080/api
    ```

    Example for online service:

    ```bash
    VOCALIN_API_BASE_URL=https://api.vocalin.top/api
    ```

4.  **Run the App**:
    ```bash
    flutter run
    ```

## Backend Integration

Currently, the app uses `DataService` (`lib/src/services/data_service.dart`) with mock data. To connect to a real Golang backend:

1.  Replace the mock data logic in `DataService` with HTTP calls (using `http` or `dio` package).
2.  Update models to parse JSON from the API.

## Testing

Run unit tests with:

```bash
flutter test
```
