import 'package:hive/hive.dart';

part 'config_model.g.dart';

@HiveType(typeId: 9)
class ConfigModel extends HiveObject {
  @HiveField(0)
  bool playAudioOnRepeat;

  @HiveField(1)
  bool randomizeAudio;

  @HiveField(2)
  bool showPhotoButton;

  @HiveField(3)
  bool showAudioRecordButton;

  ConfigModel({
    this.playAudioOnRepeat = false,
    this.randomizeAudio = false,
    this.showPhotoButton = true,
    this.showAudioRecordButton = true,
  });

  static ConfigModel getDefault() {
    return ConfigModel(
      playAudioOnRepeat: false,
      randomizeAudio: false,
      showPhotoButton: true,
      showAudioRecordButton: true,
    );
  }
}
