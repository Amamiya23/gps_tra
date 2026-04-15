# GPX Photo Geotagger

Flutter Android app for adding GPS EXIF data to JPG photos by matching capture time against a GPX track.

## Implemented scope

- Import 1 GPX file
- Select multiple JPG/JPEG files
- Read `DateTimeOriginal` / fallback EXIF time from each photo
- Apply a manual time offset such as `-08:00:00`
- Match each photo against GPX points with linear interpolation
- Overwrite the original JPG GPS EXIF metadata
- Show preview and processing results

## Project notes

The Android scaffold has been generated locally and the project has been verified with:

```bash
/home/cat/flutter/bin/flutter pub get
/home/cat/flutter/bin/flutter analyze
/home/cat/flutter/bin/flutter test
```

To run from terminal:

```bash
/home/cat/flutter/bin/flutter run
```

If `flutter create` rewrites `android/app/src/main/kotlin/.../MainActivity.kt`, restore the version from this workspace because it contains the EXIF method channel implementation.

Android Studio instructions are in `docs/ANDROID_STUDIO_RUN.md`.

## Android setup detail

The Android app needs `androidx.exifinterface:exifinterface` in the app module dependencies if it is not already present in the generated Flutter project.

Gradle snippet:

```gradle
implementation "androidx.exifinterface:exifinterface:1.3.7"
```

## Time offset behavior

The offset is applied directly to the EXIF capture time before matching to GPX timestamps.

Example:

- Photo EXIF time: `2026:04:13 13:26:41`
- GPX time is UTC
- If the camera was set to China local time, try `-08:00:00`

## Storage behavior

- GPX is read from the file selected by the user
- JPG files are written back to the original selected document URI when Android provides one
- Processing is intended to happen in the same app session after selecting files
