# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This project uses XcodeGen to generate the Xcode project from `project.yml`:

```bash
xcodegen generate    # Regenerate Xcode project after modifying project.yml
```

Build and run via Xcode or:
```bash
xcodebuild -scheme Trakt -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

**Trakt** is an iOS app for tracking TV shows using the Trakt.tv API, with a WidgetKit extension for home screen widgets.

### Targets
- **Trakt** - Main iOS app
- **TraktWidgetExtension** - Widget showing upcoming episodes with poster images

### Data Flow
**Main App:**
1. `TraktAPI` fetches episodes from Trakt's calendar API
2. `ImageService` (actor) fetches poster URLs from TMDB API with in-memory caching
3. Stores API keys in shared UserDefaults on launch for widget access

**Widget (independent updates):**
1. `WidgetDataService` fetches data directly from Trakt/TMDB APIs using shared credentials
2. Updates every hour via timeline refresh, no need to open the app
3. Caches results in shared UserDefaults (App Group: `group.com.ivanmz.Trakt`)

### Key Services
- `AuthManager` - Device OAuth flow for Trakt authentication, stores tokens in UserDefaults
- `TraktAPI` - Trakt API client for calendar/episodes
- `ImageService` - TMDB poster fetching with actor-based thread safety

### Shared Code
The `Shared/` directory contains `WidgetEpisodeData` model used by both app and widget for App Group communication.

## Configuration

Copy `Trakt/Config/Secrets.example.swift` to `Trakt/Config/Secrets.swift` and fill in:
- `tmdbAPIKey` - TMDB API key for poster images
- `traktClientId` / `traktClientSecret` - Trakt API credentials

## Language

UI strings are in Spanish.
