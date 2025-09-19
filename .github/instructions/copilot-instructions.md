#### Structure code
- This is a flutter project. main code is in lib using lib/main.dart as entry point.
  - models: data classes
  - screens: different screens
  - utils: utility functions
  - widgets: reusable widgets


#### Best practices:
  - Create reusable widgets or adapt existing ones if proper.
  - Attempt not using external packages unless necessary.
  - For logic heavy modules/features. create its proper logic unit on the tests folder.


#### Work Pipeline
- With every feature request, also return a commiting message suggestion to use by the end.
- Since I am learning flutter, if you find an interesting topic or flutter feature add the information in `docs\learnings.md`
- To validate, run the tests `flutter test`. Fix the code or the tests (remove deprecated). the test shouldnt be too strict and open for future changes, the tests should run very quickly, just either core tests on logic heavy modules or basic integration tests to ensure that clicking through each screen or button doesnt break.



#### Application description:
  - a pomodoro application tool
    - Sets music on the background
    - After a session allows for user to enter a voice audio and image to describe their pomodoro results.



