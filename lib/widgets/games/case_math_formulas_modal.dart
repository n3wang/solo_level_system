import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/case_math/case_math_models.dart';
import 'package:solo_level_system/widgets/common/centered_app_modal.dart';

Future<void> showCaseMathFormulasModal(
  BuildContext context, {
  required CaseMathCaseDefinition definition,
}) {
  return showCenteredAppModal<void>(
    context: context,
    heightFraction: 0.72,
    builder: (ctx) => _CaseMathFormulasBody(definition: definition),
  );
}

class _CaseMathFormulasBody extends StatelessWidget {
  const _CaseMathFormulasBody({required this.definition});

  final CaseMathCaseDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Formulas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                definition.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColorPalette.textSecondary,
                ),
              ),
              const SizedBox(height: AppUiSizes.md),
              for (final entry in _uniqueQuestions) ...[
                Text(
                  _title(entry.id),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.formula,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: AppUiSizes.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<CaseMathQuestionDefinition> get _uniqueQuestions {
    final formulas = <String>{};
    return definition.questions
        .where((question) => formulas.add(question.formula))
        .toList();
  }

  String _title(String id) {
    return id
        .split('_')
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
