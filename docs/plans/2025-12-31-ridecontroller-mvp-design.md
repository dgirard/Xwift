# RideController MVP Design

Flutter Android application for controlling Zwift Ride and FTMS-compliant smart trainers via Bluetooth Low Energy.

## MVP Scope

| Aspect | Decision |
|--------|----------|
| **Goal** | MVP first, iterate later |
| **Core modes** | SIM Mode + ERG Mode |
| **Strava** | Manual .FIT/.TCX export (no OAuth) |
| **Workouts** | Manual target, simple intervals, import .ZWO/.ERG/.MRC |
| **Devices** | Any FTMS-compliant trainer |
| **UI** | Match mockups, dark theme, Google Font Flex |

---

## 1. Architecture Overview

### Tech Stack

- **Flutter 3.x** with Dart 3
- **flutter_blue_plus** for BLE communication
- **flutter_ftms** for FTMS protocol abstraction
- **Riverpod** for state management (reactive, testable, handles async well for BLE streams)
- **go_router** for navigation
- **google_fonts** package for Flex font
- **drift** for SQLite database
- **shared_preferences** for settings

### Project Structure

```
lib/
├── main.dart
├── app.dart                    # MaterialApp, theme, router
├── core/
│   ├── theme/                  # Dark theme, colors, typography
│   ├── constants/              # FTMS UUIDs, workout zones
│   └── utils/                  # Byte parsing, unit conversion
├── features/
│   ├── bluetooth/              # BLE scanning, connection management
│   ├── ftms/                   # FTMS service, control point, telemetry
│   ├── workout/                # ERG mode, intervals, file parsing
│   ├── ride/                   # SIM mode, session management
│   └── export/                 # .FIT/.TCX file generation
├── screens/                    # 6 main screens
├── widgets/                    # Reusable UI components
└── models/                     # Data classes
```

### Key Architecture Decisions

- Feature-first folder structure for scalability
- Riverpod providers wrap BLE streams for reactive UI updates
- Repository pattern isolates FTMS protocol details from UI
- Separate workout engine handles interval timing independent of UI

---

## 2. Bluetooth & FTMS Layer

### Connection Flow

```
Scan → Discover FTMS Service (0x1826) → Connect → Enable Notifications → Request Control → Ready
```

### BLE Service Architecture

```dart
// Core providers
bluetoothAdapterProvider    // Adapter state (on/off)
bleScannerProvider          // Scan results stream
bleConnectionProvider       // Connection state per device
ftmsDeviceProvider          // Connected FTMS device wrapper
```

### FTMS Characteristics

| Characteristic | UUID | Purpose |
|---------------|------|---------|
| Fitness Machine Feature | 0x2ACC | Read capabilities (supports ERG? SIM?) |
| Indoor Bike Data | 0x2AD2 | Telemetry stream (power, cadence, speed) |
| Training Status | 0x2AD3 | Workout state notifications |
| Supported Resistance Range | 0x2AD6 | Min/max/step for resistance |
| Supported Power Range | 0x2AD8 | Min/max/step for ERG mode |
| Control Point | 0x2AD9 | Send commands (resistance, target power, simulation) |
| Machine Status | 0x2ADA | State changes (started, stopped, paused) |

### Control Point Commands (OpCodes)

```dart
class FtmsControlPoint {
  static const requestControl = 0x00;
  static const reset = 0x01;
  static const setTargetPower = 0x05;        // ERG mode
  static const setTargetResistance = 0x04;   // Manual resistance
  static const startOrResume = 0x07;
  static const stopOrPause = 0x08;
  static const setSimulationParams = 0x11;   // SIM mode (grade, wind, etc.)
}
```

### Command Queue

Commands to Control Point must be serialized - wait for indication response before sending next:

```dart
class FtmsCommandQueue {
  Future<FtmsResponse> send(List<int> command);  // Queues and awaits indication
}
```

---

## 3. Data Models & Telemetry

### Core Data Classes

```dart
// Device representation
class FtmsDevice {
  final String id;
  final String name;
  final int rssi;
  final FtmsFeatures features;  // What the device supports
  final ResistanceRange? resistanceRange;
  final PowerRange? powerRange;
}

// Real-time telemetry from Indoor Bike Data (0x2AD2)
class BikeTelemetry {
  final double? instantPower;      // Watts
  final double? averagePower;      // Watts
  final double? instantCadence;    // RPM
  final double? averageCadence;    // RPM
  final double? instantSpeed;      // km/h
  final int? heartRate;            // BPM (if broadcasting)
  final int? totalDistance;        // meters
  final int? totalEnergy;          // kcal
  final Duration elapsed;
  final DateTime timestamp;
}

// Current ride session
class RideSession {
  final DateTime startTime;
  final RideMode mode;             // sim or erg
  final List<TelemetrySample> samples;  // For export
  final WorkoutPlan? workout;      // If ERG with intervals
}

// Workout structures
class WorkoutPlan {
  final String name;
  final List<WorkoutInterval> intervals;
  final Duration totalDuration;
}

class WorkoutInterval {
  final Duration duration;
  final int targetPower;           // Watts (absolute or % FTP)
  final String? name;              // "Warmup", "Interval 1", etc.
}
```

### Telemetry Parsing

The Indoor Bike Data characteristic uses a flags bitmap (first 2 bytes) to indicate which fields are present. flutter_ftms handles this, but our provider wraps it:

```dart
final telemetryStreamProvider = StreamProvider<BikeTelemetry>((ref) {
  final device = ref.watch(connectedFtmsDeviceProvider);
  return device.indoorBikeDataStream
      .map((data) => BikeTelemetry.fromFtmsData(data))
      .throttleTime(Duration(milliseconds: 250));  // Cap UI updates
});
```

### Power Zones

```dart
enum PowerZone {
  recovery,   // < 55% FTP - Gray
  endurance,  // 55-75% FTP - Blue
  tempo,      // 76-90% FTP - Green
  threshold,  // 91-105% FTP - Yellow
  vo2max,     // 106-120% FTP - Orange
  anaerobic,  // > 120% FTP - Red
}
```

---

## 4. Ride Modes (SIM & ERG)

### SIM Mode - Simulation Parameters

User controls resistance via grade simulation. The app sends OpCode 0x11 with physics parameters:

```dart
class SimulationParams {
  final double windSpeed;        // m/s (-127 to +127, resolution 0.001)
  final double grade;            // % slope (-40 to +40, resolution 0.01)
  final double crr;              // Rolling resistance coefficient (0-1)
  final double cw;               // Wind resistance (kg/m)
}

// Default realistic values
SimulationParams.defaults({
  windSpeed: 0.0,
  grade: 0.0,
  crr: 0.004,      // Typical indoor trainer
  cw: 0.51,        // Average cyclist
});
```

### SIM Mode UI Controls

- Grade slider: -10% to +16% (matches KICKR max)
- Virtual shifting: Gear changes translate to grade adjustments
- Resistance slider: Direct resistance level (0-100%)

### ERG Mode - Target Power

Locks trainer to specific wattage regardless of cadence. Uses OpCode 0x05:

```dart
class ErgController {
  final FtmsCommandQueue _queue;

  Future<void> setTargetPower(int watts) async {
    // Clamp to device's supported range
    final clamped = watts.clamp(minPower, maxPower);
    await _queue.send([0x05, clamped & 0xFF, (clamped >> 8) & 0xFF]);
  }
}
```

### Workout Engine (for intervals)

```dart
class WorkoutEngine {
  final WorkoutPlan plan;
  int currentIntervalIndex = 0;
  Duration elapsed = Duration.zero;

  Stream<WorkoutState> get stateStream;  // Emits on interval changes

  int get currentTargetPower => plan.intervals[currentIntervalIndex].targetPower;
  Duration get intervalRemaining => /* calculated */;

  void tick(Duration delta);  // Called every second
  void skip();                // Jump to next interval
  void pause();
  void resume();
}
```

### Mode Switching

User can switch SIM <-> ERG mid-ride. The app:
1. Sends stop command
2. Switches mode
3. Sends new parameters
4. Resumes

---

## 5. Workout Files & Export

### Workout File Import

Support three common formats for ERG mode:

| Format | Origin | Structure |
|--------|--------|-----------|
| .ZWO | Zwift | XML with warmup/intervals/cooldown |
| .ERG | TrainerRoad/Generic | Text with time+power pairs |
| .MRC | Generic | Text with time+percentage pairs |

### Parser Architecture

```dart
abstract class WorkoutParser {
  WorkoutPlan parse(String content);
}

class ZwoParser implements WorkoutParser {
  // <workout><SteadyState Duration="300" Power="0.65"/>...
  WorkoutPlan parse(String xml) { /* ... */ }
}

class ErgParser implements WorkoutParser {
  // [COURSE HEADER] then minutes watts pairs
  WorkoutPlan parse(String content) { /* ... */ }
}

class MrcParser implements WorkoutParser {
  // minutes percentage pairs (needs FTP to convert)
  WorkoutPlan parse(String content) { /* ... */ }
}

// Factory
WorkoutPlan parseWorkoutFile(File file) {
  final ext = path.extension(file.path).toLowerCase();
  final content = file.readAsStringSync();
  return switch (ext) {
    '.zwo' => ZwoParser().parse(content),
    '.erg' => ErgParser().parse(content),
    '.mrc' => MrcParser().parse(content),
    _ => throw UnsupportedWorkoutFormat(ext),
  };
}
```

### Ride Export (.FIT and .TCX)

After a ride, export for manual Strava upload:

```dart
class RideExporter {
  // FIT is binary, preferred by Strava
  Future<File> exportFit(RideSession session) async {
    final fit = FitFileBuilder()
      ..addFileId(type: FileType.activity)
      ..addRecords(session.samples.map((s) => Record(
          timestamp: s.timestamp,
          power: s.power,
          cadence: s.cadence,
          speed: s.speed,
          heartRate: s.heartRate,
          distance: s.distance,
        )))
      ..addLap(/* summary stats */)
      ..addSession(/* totals */);

    return fit.build().writeToFile(path);
  }

  // TCX is XML, wider compatibility
  Future<File> exportTcx(RideSession session) async {
    // XML structure: TrainingCenterDatabase > Activities > Activity > Lap > Track > Trackpoints
  }
}
```

### Export Flow

1. Ride ends -> prompt "Save ride?"
2. Generate both .FIT and .TCX to app documents folder
3. Show share sheet or "Open in..." for upload to Strava/other apps

### Dependencies

- `fit_tool` or custom FIT encoder for binary format
- `xml` package for TCX generation
- `share_plus` for native share sheet

---

## 6. UI Screens & Theme

### Theme Configuration

```dart
// Dark theme matching mockups
class AppTheme {
  static const background = Color(0xFF0D1117);      // Deep dark blue
  static const surface = Color(0xFF161B22);         // Card background
  static const surfaceLight = Color(0xFF21262D);    // Elevated elements
  static const primary = Color(0xFF3B82F6);         // Blue accent
  static const success = Color(0xFF22C55E);         // Green (connected, good)
  static const warning = Color(0xFFF59E0B);         // Orange (tempo zone)
  static const error = Color(0xFFEF4444);           // Red (disconnect, max effort)
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B949E);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.flexTextTheme(/* ... */),
    // ...
  );
}
```

### Screen Breakdown (6 screens)

| Screen | Route | Key Widgets |
|--------|-------|-------------|
| Welcome | `/` | Hero image, feature icons, "Connecter mon Ride" button |
| Device Connection | `/connect` | Scan animation, device list with RSSI, connect buttons |
| Dashboard | `/ride` | Mode toggle, power display, metrics row, gear/resistance, controls |
| ERG Mode | `/ride/erg` | Workout selector, interval graph, target power, timer |
| Strava Sync | `/settings/strava` | OAuth placeholder, export history, file list |
| Profile | `/profile` | User stats, activity history, settings |

### Key Reusable Widgets

```dart
// Large power display with zone coloring
class PowerDisplay extends StatelessWidget {
  final int watts;
  final PowerZone zone;
  // Renders: "245" large + "watts" label + zone indicator
}

// Metric card (RPM, km/h, BPM)
class MetricTile extends StatelessWidget {
  final String value;
  final String unit;
  final IconData icon;
}

// Virtual gear selector
class GearSelector extends StatelessWidget {
  final int currentGear;
  final int totalGears;  // 22 for Zwift virtual shifting
  final ValueChanged<int> onChanged;
}

// Interval visualization bar
class IntervalProgressBar extends StatelessWidget {
  final WorkoutPlan plan;
  final int currentInterval;
  final double progress;
}

// Device list item with signal strength
class DeviceListTile extends StatelessWidget {
  final FtmsDevice device;
  final VoidCallback onConnect;
}
```

### Navigation

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => WelcomeScreen()),
    GoRoute(path: '/connect', builder: (_, __) => DeviceConnectionScreen()),
    GoRoute(path: '/ride', builder: (_, __) => DashboardScreen()),
    GoRoute(path: '/ride/erg', builder: (_, __) => ErgModeScreen()),
    GoRoute(path: '/profile', builder: (_, __) => ProfileScreen()),
    GoRoute(path: '/settings/export', builder: (_, __) => ExportScreen()),
  ],
);
```

---

## 7. Error Handling & Reconnection

### Connection States

```dart
enum ConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  requestingControl,
  ready,           // Can send commands
  reconnecting,    // Lost connection, attempting recovery
  error,
}
```

### Auto-Reconnection Strategy

```dart
class ConnectionManager {
  static const maxReconnectAttempts = 5;
  static const reconnectDelays = [1, 2, 4, 8, 16]; // seconds, exponential backoff

  Future<void> onDisconnect(FtmsDevice device) async {
    if (_rideInProgress) {
      // Don't lose the ride - keep recording with gaps
      _telemetryBuffer.markDisconnection();

      for (var attempt = 0; attempt < maxReconnectAttempts; attempt++) {
        await Future.delayed(Duration(seconds: reconnectDelays[attempt]));
        try {
          await connect(device);
          await requestControl();
          _restoreRideState();  // Re-send last mode/target
          return;
        } catch (_) {
          continue;
        }
      }
      // All attempts failed - notify user
      _showReconnectionFailed();
    }
  }
}
```

### Ride Data Protection

```dart
class RideSession {
  // Persist samples to disk periodically (every 30s)
  Future<void> checkpoint() async {
    await _localStorage.write('current_ride', samples.toJson());
  }

  // On app restart, check for incomplete ride
  static Future<RideSession?> recoverIncomplete() async {
    final data = await _localStorage.read('current_ride');
    if (data != null) return RideSession.fromJson(data);
    return null;
  }
}
```

### Error UI Patterns

| Scenario | UI Response |
|----------|-------------|
| Bluetooth off | Full-screen prompt with "Enable Bluetooth" button |
| No devices found | "No trainers found" + troubleshooting tips + retry |
| Connection failed | Snackbar with retry action |
| Lost mid-ride | Overlay banner "Reconnecting..." + countdown |
| Reconnect failed | Dialog: "Save partial ride?" or "Keep trying?" |
| Control rejected | Toast: "Another app has control" |

### Permission Handling

```dart
Future<bool> ensurePermissions() async {
  if (Platform.isAndroid) {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // No location needed with neverForLocation flag
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }
  return true;
}
```

---

## 8. Local Storage & Persistence

### Storage Strategy

| Data Type | Storage | Package |
|-----------|---------|---------|
| User settings | Key-value | `shared_preferences` |
| User profile (FTP, weight) | Key-value | `shared_preferences` |
| Ride history | SQLite | `drift` (type-safe ORM) |
| Workout files | File system | `path_provider` |
| Exported rides | File system | `path_provider` |
| Current ride checkpoint | JSON file | `path_provider` |

### User Settings

```dart
class UserSettings {
  int ftp;                    // Functional Threshold Power
  double weight;              // kg, for power/weight calculations
  int totalGears;             // Virtual shifting (default 22)
  bool keepScreenOn;          // Prevent screen timeout during rides
  String defaultMode;         // 'sim' or 'erg'
  String? lastDeviceId;       // Auto-connect to last trainer
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier(ref.read(sharedPreferencesProvider));
});
```

### Ride History Database (Drift)

```dart
// Database tables
class Rides extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get durationSeconds => integer()();
  IntColumn get distanceMeters => integer()();
  IntColumn get avgPower => integer().nullable()();
  IntColumn get maxPower => integer().nullable()();
  IntColumn get avgCadence => integer().nullable()();
  IntColumn get avgHeartRate => integer().nullable()();
  IntColumn get totalCalories => integer().nullable()();
  TextColumn get mode => text()();  // 'sim' or 'erg'
  TextColumn get workoutName => text().nullable()();
  TextColumn get fitFilePath => text().nullable()();
  TextColumn get tcxFilePath => text().nullable()();
}

// Repository
class RideRepository {
  Future<void> saveRide(RideSession session);
  Future<List<Ride>> getRecentRides({int limit = 20});
  Future<RideStats> getLifetimeStats();  // Total distance, time, etc.
  Future<void> deleteRide(int id);
}
```

### File Organization

```
/app_documents/
├── workouts/           # Imported .ZWO/.ERG/.MRC files
│   ├── ftp_builder.zwo
│   └── custom_intervals.erg
├── exports/            # Generated .FIT/.TCX files
│   ├── 2025-01-15_ride.fit
│   └── 2025-01-15_ride.tcx
└── recovery/           # Checkpoint for crash recovery
    └── current_ride.json
```

### Profile Stats for UI

```dart
class ProfileStats {
  final int totalRides;
  final int totalDistanceKm;
  final int totalElevationM;
  final Duration totalTime;
  final int averagePower;

  // Computed from ride history
  static Future<ProfileStats> compute(RideRepository repo);
}
```

---

## 9. Android Configuration

### AndroidManifest.xml Permissions

```xml
<!-- Bluetooth permissions for Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Legacy permissions for Android 11 and below -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- Keep screen on during rides -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.4.0

  # Navigation
  go_router: ^13.0.0

  # Bluetooth
  flutter_blue_plus: ^1.31.0
  flutter_ftms: ^0.6.2

  # Storage
  shared_preferences: ^2.2.0
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0

  # UI
  google_fonts: ^6.1.0

  # Permissions
  permission_handler: ^11.1.0

  # Export
  share_plus: ^7.2.0
  xml: ^6.5.0

  # Utilities
  wakelock_plus: ^1.1.0
  intl: ^0.18.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.14.0
  build_runner: ^2.4.0
```

---

## 10. MVP Screens Summary

### Welcome Screen (`/`)
- App logo "RideController"
- Zwift Ride hero image
- Three feature icons: Virtual Shifting, Telemetry Live, Sync Strava
- Primary button: "Connecter mon Ride"
- Skip link for returning users

### Device Connection (`/connect`)
- Bluetooth scan animation
- List of discovered FTMS devices with:
  - Device name
  - Signal strength indicator (Excellent/Good/Fair)
  - Connect button
- "Scanner a nouveau" button
- Troubleshooting link

### Dashboard (`/ride`)
- SIM Mode / ERG Mode toggle
- Large power display (245 watts) with zone color
- Metrics row: RPM, km/h, BPM
- Virtual Shifting: gear selector (14/22)
- Resistance slider (0-100%)
- Pause / End Ride buttons

### ERG Mode (`/ride/erg`)
- Workout selector with "Changer" button
- Interval visualization bar
- Target power display (250W)
- Current metrics: RPM, BPM, time remaining
- BIAS adjustment (+/- percentage)
- Arreter / Demarrer buttons

### Export Screen (`/settings/export`)
- Export history list
- Each ride shows: date, duration, avg power
- Share buttons for .FIT and .TCX
- "Last sync" timestamp

### Profile (`/profile`)
- User avatar and name
- Stats grid: Distance, Elevation, Time, Avg Power
- Activity history list
- Settings access

---

## References

- [FTMS Specification v1.0](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/)
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)
- [flutter_ftms](https://pub.dev/packages/flutter_ftms)
- [Zwift Ride Specs](https://us.zwift.com/products/zwift-ride-smart-frame)
- [DC Rainmaker Review](https://www.dcrainmaker.com/2024/06/zwift-ride-indoor-bike-review-future.html)
