@echo off
setlocal

echo [pre-run] slicing workout icons...
dart run scripts/slice_workout_sprites.dart
if %ERRORLEVEL% NEQ 0 (
  echo [pre-run] sprite slicing failed.
  exit /b %ERRORLEVEL%
)

echo [run] flutter run %*
flutter run %*

