@echo off
REM Batch script to slice workout sprite sheet
REM This should be run on desktop before building for mobile

echo Slicing workout sprite sheet...
dart run scripts/slice_workout_sprites.dart

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Sprite slicing completed successfully!
    echo Remember to run: flutter pub get
) else (
    echo.
    echo Sprite slicing failed. Check the error messages above.
    exit /b %ERRORLEVEL%
)
