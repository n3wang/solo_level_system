import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ValueNotifier;
import 'package:hive/hive.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/utils/timer_controller.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Which "shape" the single app window is currently in.
enum DesktopWindowMode { popover, fullApp }

/// Owns the macOS menu-bar tray icon and the window's popover/full-app
/// mode switching. The app is a single Flutter window that resizes and
/// repositions itself rather than a second engine/window, so [TimerController]
/// and every other singleton stay naturally shared between both modes.
///
/// No-op on every platform other than macOS.
class DesktopShellService with TrayListener, WindowListener {
  static final DesktopShellService _instance = DesktopShellService._internal();
  factory DesktopShellService() => _instance;
  DesktopShellService._internal();

  static const MethodChannel _nativeChannel = MethodChannel('desktop_shell');

  static const Size popoverSize = Size(360, 480);
  static const Size fullAppMinimumSize = Size(900, 620);
  static const Size fullAppDefaultSize = Size(1200, 800);

  final ValueNotifier<DesktopWindowMode> modeNotifier =
      ValueNotifier<DesktopWindowMode>(DesktopWindowMode.popover);

  DesktopWindowMode get mode => modeNotifier.value;

  bool get isSupported => !kIsWeb && Platform.isMacOS;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);

    const options = WindowOptions(
      size: popoverSize,
      minimumSize: popoverSize,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      skipTaskbar: true,
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.hide();
    });
    await windowManager.setPreventClose(true);

    await trayManager.setIcon(
      'assets/images/tray/tray_icon.png',
      isTemplate: true,
    );
    await trayManager.setToolTip('Solo Level System');
    await _rebuildTrayMenu();
    await registerHotkeys();

    TimerController().addListener(_updateTrayTitle);
    _updateTrayTitle();
  }

  /// Shows the live countdown as text next to the tray icon (e.g. "24:59"),
  /// matching the menu-bar clock's own text+icon look. Cleared when idle.
  void _updateTrayTitle() {
    final timer = TimerController();
    final showTime = timer.isRunning || timer.isMidSessionPaused;
    trayManager.setTitle(
      showTime ? timer.formatTime(timer.remainingSeconds) : '',
    );
  }

  Future<void> _rebuildTrayMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show_popover',
            label: 'Show Popover',
            onClick: (_) => showPopover(),
          ),
          MenuItem(
            key: 'open_full_app',
            label: 'Open Full App',
            onClick: (_) => openFullApp(),
          ),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit', onClick: (_) => quit()),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    if (mode == DesktopWindowMode.fullApp) {
      windowManager.show();
      windowManager.focus();
      return;
    }
    togglePopover();
  }

  Future<void> togglePopover() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
    } else {
      await showPopover();
    }
  }

  /// Shows the small popover window anchored near the tray icon.
  Future<void> showPopover() async {
    if (mode == DesktopWindowMode.fullApp) {
      await _applyPopoverGeometry();
    }
    final trayBounds = await trayManager.getBounds();
    if (trayBounds != null) {
      final x = trayBounds.left + trayBounds.width / 2 - popoverSize.width / 2;
      final y = trayBounds.bottom + 4;
      await windowManager.setBounds(
        Rect.fromLTWH(x, y, popoverSize.width, popoverSize.height),
      );
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _applyPopoverGeometry() async {
    modeNotifier.value = DesktopWindowMode.popover;
    await _setActivationPolicyRegular(false);
    await windowManager.setResizable(false);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMinimumSize(popoverSize);
    await windowManager.setSize(popoverSize);
  }

  /// Expands the window into a normal titled/resizable full-app window and
  /// brings the Dock icon back.
  Future<void> openFullApp() async {
    modeNotifier.value = DesktopWindowMode.fullApp;
    await _setActivationPolicyRegular(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    await windowManager.setMinimumSize(fullAppMinimumSize);
    await windowManager.setSize(fullAppDefaultSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await _nativeChannel.invokeMethod('quit');
  }

  @override
  void onWindowClose() {
    // Closing (red button) always hides rather than destroying the window;
    // full quit only happens via the tray menu's Quit item.
    windowManager.hide();
    if (mode == DesktopWindowMode.fullApp) {
      _applyPopoverGeometry();
    }
  }

  @override
  void onWindowBlur() {
    if (mode == DesktopWindowMode.popover) {
      windowManager.hide();
    }
  }

  Future<void> _setActivationPolicyRegular(bool regular) async {
    try {
      await _nativeChannel.invokeMethod('setActivationPolicy', {
        'regular': regular,
      });
    } catch (_) {
      // Non-macOS or channel not yet wired up; safe to ignore.
    }
  }

  // ---- Global shortcuts ----
  //
  // Bindings are stored on UserSettingsModel as JSON (HotKey.toJson()); an
  // empty string means "use the built-in default". Settings calls
  // [registerHotkeys] again after saving a new binding.

  static HotKey defaultStartPauseHotKey() => HotKey(
    key: PhysicalKeyboardKey.keyP,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  static HotKey defaultStopHotKey() => HotKey(
    key: PhysicalKeyboardKey.keyS,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  static HotKey defaultTogglePopoverHotKey() => HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  static String encodeHotKey(HotKey hotKey) => jsonEncode(hotKey.toJson());

  static HotKey? decodeHotKey(String stored) {
    if (stored.isEmpty) return null;
    try {
      return HotKey.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> registerHotkeys() async {
    if (!isSupported) return;
    await hotKeyManager.unregisterAll();
    final settings = _liveSettings();
    await _registerOne(
      settings.hotkeyStartPause,
      defaultStartPauseHotKey(),
      _onStartPauseHotkey,
    );
    await _registerOne(settings.hotkeyStop, defaultStopHotKey(), _onStopHotkey);
    await _registerOne(
      settings.hotkeyTogglePopover,
      defaultTogglePopoverHotKey(),
      _onTogglePopoverHotkey,
    );
  }

  /// Re-registers every shortcut. Public alias of [registerHotkeys] used by
  /// the Settings screen after saving a new binding, so intent reads clearly
  /// at the call site.
  Future<void> reloadHotkeys() => registerHotkeys();

  /// Stops all global shortcuts from firing while the Settings screen is
  /// capturing a new key combo, so the old binding doesn't interfere.
  Future<void> unregisterAllHotkeys() => hotKeyManager.unregisterAll();

  Future<void> _registerOne(
    String stored,
    HotKey fallback,
    VoidCallback handler,
  ) async {
    final hotKey = decodeHotKey(stored) ?? fallback;
    try {
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => handler());
    } catch (_) {
      // Binding may already be claimed by another app; leave it unregistered
      // rather than crash startup.
    }
  }

  void _onStartPauseHotkey() {
    final timer = TimerController();
    if (timer.isRunning) {
      timer.pauseTimer();
    } else {
      timer.startTimer();
    }
  }

  void _onStopHotkey() => TimerController().resetTimer();

  void _onTogglePopoverHotkey() => togglePopover();

  UserSettingsModel _liveSettings() {
    try {
      if (Hive.isBoxOpen('userSettings')) {
        final stored = Hive.box<UserSettingsModel>(
          'userSettings',
        ).get('settings');
        if (stored != null) return stored;
      }
    } catch (_) {}
    return UserSettingsModel();
  }

  void dispose() {
    TimerController().removeListener(_updateTrayTitle);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}
