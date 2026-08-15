import 'package:solo_level_system/utils/case_math/case_math_models.dart';

/// Case 1 is data only. Future cases can define different tables and questions
/// without adding generator or scoring branches.
const case1Definition = CaseMathCaseDefinition(
  id: 'case_1',
  title: 'Coffee Chain Performance',
  subtitle: 'Profitability and growth',
  highScoreKey: 'case_math_case_1_high_scores',
  tables: [
    CaseMathTableDefinition(
      id: 'companies',
      title: 'Companies',
      kind: CaseMathTableKind.companyYears,
      entityNamePool: [
        'Brewline',
        'Northbean',
        'Copper Cup',
        'Harbor Roast',
        'Steamwell',
        'Lumen Coffee',
        'Ash & Grind',
        'Parcel Espresso',
      ],
      entityCount: 2,
      yearCount: 4,
      metrics: [
        CaseMathValueDefinition(
          id: 'stores',
          name: 'Stores',
          caseId: 'case_1',
          range: CaseMathRange(80, 160),
          growthRange: CaseMathRange(1.04, 1.22),
        ),
        CaseMathValueDefinition(
          id: 'revenue',
          name: 'Revenue',
          caseId: 'case_1',
          range: CaseMathRange(18000000, 39000000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(1.06, 1.28),
        ),
        CaseMathValueDefinition(
          id: 'operatingCosts',
          name: 'Operating costs',
          caseId: 'case_1',
          range: CaseMathRange(11000000, 15000000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(1.03, 1.12),
        ),
        CaseMathValueDefinition(
          id: 'customers',
          name: 'Customers',
          caseId: 'case_1',
          range: CaseMathRange(2800000, 5200000),
          growthRange: CaseMathRange(1.05, 1.25),
        ),
        CaseMathValueDefinition(
          id: 'avgPrice',
          name: 'Avg price / transaction',
          caseId: 'case_1',
          range: CaseMathRange(5.20, 7.80),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.97, 1.08),
          decimalPlaces: 2,
        ),
        CaseMathValueDefinition(
          id: 'capitalGains',
          name: 'Capital gains',
          caseId: 'case_1',
          range: CaseMathRange(180000, 920000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.70, 1.45),
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'goodwillAmortization',
          name: 'Goodwill amortization',
          caseId: 'case_1',
          range: CaseMathRange(420000, 1800000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.85, 1.15),
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'deferredTaxLiability',
          name: 'Deferred tax liability',
          caseId: 'case_1',
          range: CaseMathRange(310000, 1400000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.88, 1.25),
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'unrealizedFxGain',
          name: 'Unrealized FX gain',
          caseId: 'case_1',
          range: CaseMathRange(90000, 680000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.55, 1.70),
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'accumulatedDepreciation',
          name: 'Accumulated depreciation',
          caseId: 'case_1',
          range: CaseMathRange(2200000, 7800000),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(1.03, 1.18),
          isDistractor: true,
        ),
      ],
    ),
  ],
  questions: [
    CaseMathQuestionDefinition(
      id: 'operating_profit',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText: 'What was {company} operating profit in {year}?',
      math: 'revenue - costs',
      formula: 'Operating profit = Revenue − Operating costs',
      answerType: CaseMathValueFormat.price,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'costs': CaseMathVariableBinding.value(
          'operatingCosts',
          tableId: 'companies',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'profit_margin',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText: 'What was {company} profit margin in {year}? (as %)',
      math: '(revenue - costs) / revenue * 100',
      formula: 'Profit margin = (Revenue − Operating costs) ÷ Revenue',
      answerType: CaseMathValueFormat.percentage,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'costs': CaseMathVariableBinding.value(
          'operatingCosts',
          tableId: 'companies',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'revenue_growth',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText:
          'By what percentage did {company} revenue change from {previousYear} to {year}? (as %)',
      math: '(revenue - oldRevenue) / oldRevenue * 100',
      formula: '% change = (New − Old) ÷ Old',
      answerType: CaseMathValueFormat.percentage,
      minimumPreviousYears: 1,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'oldRevenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
          yearOffset: -1,
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'profit_growth',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText:
          'By what percentage did {company} operating profit change from {previousYear} to {year}? (as %)',
      math:
          '((revenue - costs) - (oldRevenue - oldCosts)) / (oldRevenue - oldCosts) * 100',
      formula: '% change = (New profit − Old profit) ÷ Old profit',
      answerType: CaseMathValueFormat.percentage,
      minimumPreviousYears: 1,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'costs': CaseMathVariableBinding.value(
          'operatingCosts',
          tableId: 'companies',
        ),
        'oldRevenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
          yearOffset: -1,
        ),
        'oldCosts': CaseMathVariableBinding.value(
          'operatingCosts',
          tableId: 'companies',
          yearOffset: -1,
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'revenue_per_store_growth',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText:
          'What was the percentage change in {company} revenue per store from {previousYear} to {year}? (as %)',
      math:
          '((revenue / stores) - (oldRevenue / oldStores)) / (oldRevenue / oldStores) * 100',
      formula:
          'Revenue/store = Revenue ÷ Stores; then % change = (New − Old) ÷ Old',
      answerType: CaseMathValueFormat.percentage,
      minimumPreviousYears: 1,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'stores': CaseMathVariableBinding.value(
          'stores',
          tableId: 'companies',
        ),
        'oldRevenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
          yearOffset: -1,
        ),
        'oldStores': CaseMathVariableBinding.value(
          'stores',
          tableId: 'companies',
          yearOffset: -1,
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'revenue_per_customer',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText:
          'What was {company} average revenue per customer in {year}?',
      math: 'revenue / customers',
      formula: 'Revenue per customer = Revenue ÷ Customers',
      answerType: CaseMathValueFormat.price,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'customers': CaseMathVariableBinding.value(
          'customers',
          tableId: 'companies',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'max_costs',
      caseId: 'case_1',
      focusTableId: 'companies',
      questionText:
          'If {company} wants to increase {year} profit by {upliftPercent}%, while keeping revenue constant, what is the maximum operating cost?',
      math: 'revenue - ((revenue - costs) * (1 + upliftPercent / 100))',
      formula:
          'Target profit = Current profit × (1 + uplift); Max costs = Revenue − Target profit',
      answerType: CaseMathValueFormat.price,
      variables: {
        'revenue': CaseMathVariableBinding.value(
          'revenue',
          tableId: 'companies',
        ),
        'costs': CaseMathVariableBinding.value(
          'operatingCosts',
          tableId: 'companies',
        ),
        'upliftPercent': CaseMathVariableBinding.random(
          CaseMathRange(20, 30),
          format: CaseMathValueFormat.number,
        ),
      },
    ),
  ],
);
