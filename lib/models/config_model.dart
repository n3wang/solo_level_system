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
    this.playAudioOnRepeat = true,
    this.randomizeAudio = false,
    this.showPhotoButton = true,
    this.showAudioRecordButton = true,
  });

  static ConfigModel getDefault() {
    return ConfigModel(
      playAudioOnRepeat: true,
      randomizeAudio: false,
      showPhotoButton: true,
      showAudioRecordButton: true,
    );
  }
}
