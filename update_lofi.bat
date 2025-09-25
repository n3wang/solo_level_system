@echo off
echo Updating lofi audio mapping...
dart scripts/lofi_organizer.dart
echo Done! Run 'flutter clean' and 'flutter pub get' if you added new files.
pause