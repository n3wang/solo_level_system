import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/services/desktop_shell_service.dart';

/// A settings row showing one global shortcut with a "Record" button.
///
/// While recording, the live global binding for every shortcut is
/// unregistered (via [DesktopShellService.unregisterAllHotkeys]) so the old
/// binding can't fire mid-capture; [DesktopShellService.reloadHotkeys] is
/// called again once a combo is captured (or capture is cancelled).
class HotkeyCaptureField extends StatefulWidget {
  final String title;
  final HotKey currentHotKey;
  final ValueChanged<HotKey> onChanged;

  const HotkeyCaptureField({
    super.key,
    required this.title,
    required this.currentHotKey,
    required this.onChanged,
  });

  @override
  State<HotkeyCaptureField> createState() => _HotkeyCaptureFieldState();
}

class _HotkeyCaptureFieldState extends State<HotkeyCaptureField> {
  bool _recording = false;

  Future<void> _startRecording() async {
    await DesktopShellService().unregisterAllHotkeys();
    setState(() => _recording = true);
  }

  Future<void> _finishRecording(HotKey hotKey) async {
    if (!mounted) return;
    setState(() => _recording = false);
    widget.onChanged(hotKey);
    await DesktopShellService().reloadHotkeys();
  }

  Future<void> _cancelRecording() async {
    setState(() => _recording = false);
    await DesktopShellService().reloadHotkeys();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      trailing: SizedBox(
        width: 160,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_recording)
              Expanded(
                child: _RecordingCapture(
                  initialHotKey: widget.currentHotKey,
                  onRecorded: _finishRecording,
                ),
              )
            else
              Flexible(child: HotKeyVirtualView(hotKey: widget.currentHotKey)),
            const SizedBox(width: 8),
            if (_recording)
              TextButton(
                onPressed: _cancelRecording,
                child: const Text('Cancel'),
              )
            else
              TextButton(
                onPressed: _startRecording,
                child: const Text('Record'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCapture extends StatelessWidget {
  final HotKey initialHotKey;
  final ValueChanged<HotKey> onRecorded;

  const _RecordingCapture({
    required this.initialHotKey,
    required this.onRecorded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Press keys…',
          style: TextStyle(fontSize: 11, color: AppColorPalette.textSecondary),
        ),
        HotKeyRecorder(
          initalHotKey: initialHotKey,
          onHotKeyRecorded: (hotKey) {
            // Require at least one modifier so this can't accidentally bind
            // a bare letter key as a *global* shortcut.
            if (hotKey.modifiers == null || hotKey.modifiers!.isEmpty) return;
            onRecorded(hotKey);
          },
        ),
      ],
    );
  }
}
