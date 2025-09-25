@echo off
echo Starting lofi organization...
cd /d "%~dp0.."
dart scripts/lofi_organizer.dart
pause