import 'package:solo_level_system/utils/case_math/case_math_models.dart';

/// Case 2 — beverage plant with named products + shared plant fixed costs.
const case2Definition = CaseMathCaseDefinition(
  id: 'case_2',
  title: 'Manufacturing Plant',
  subtitle: 'Product mix and shared fixed costs',
  highScoreKey: 'case_math_case_2_high_scores',
  tables: [
    CaseMathTableDefinition(
      id: 'products',
      title: 'Products',
      kind: CaseMathTableKind.entityMetric,
      entityCount: 3,
      sharedProductCount: 2,
      entityNamePool: [
        'Clear Spring Water',
        'Citrus Electrolyte Mix',
        'Sparkling Botanical Tonic',
        'Berry Recovery Gel',
        'Alpine Still Water',
        'Ginger Spark Mixer',
        'Lime Hydration Pack',
        'Herbal Fizz Concentrate',
      ],
      metrics: [
        CaseMathValueDefinition(
          id: 'units',
          name: 'Units produced',
          caseId: 'case_2',
          range: CaseMathRange(12000, 48000),
          growthRange: CaseMathRange(0.92, 1.18),
        ),
        CaseMathValueDefinition(
          id: 'price',
          name: 'Price / unit',
          caseId: 'case_2',
          range: CaseMathRange(28.40, 124.80),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.96, 1.12),
          decimalPlaces: 2,
        ),
        CaseMathValueDefinition(
          id: 'variableCost',
          name: 'Variable cost / unit',
          caseId: 'case_2',
          range: CaseMathRange(16.20, 79.40),
          format: CaseMathValueFormat.price,
          growthRange: CaseMathRange(0.95, 1.14),
          decimalPlaces: 2,
        ),
        CaseMathValueDefinition(
          id: 'scrapRate',
          name: 'Scrap rate',
          caseId: 'case_2',
          range: CaseMathRange(1.2, 6.8),
          format: CaseMathValueFormat.percentage,
          growthRange: CaseMathRange(0.85, 1.25),
          decimalPlaces: 2,
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'changeoverMinutes',
          name: 'Changeover minutes',
          caseId: 'case_2',
          range: CaseMathRange(18, 95),
          growthRange: CaseMathRange(0.90, 1.20),
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'shelfLifeDays',
          name: 'Shelf life (days)',
          caseId: 'case_2',
          range: CaseMathRange(45, 360),
          growthRange: CaseMathRange(0.98, 1.05),
          isDistractor: true,
        ),
      ],
    ),
    CaseMathTableDefinition(
      id: 'fixed',
      title: 'Plant fixed costs',
      kind: CaseMathTableKind.fixedCosts,
      metrics: [
        CaseMathValueDefinition(
          id: 'plantRent',
          name: 'Plant rent',
          caseId: 'case_2',
          range: CaseMathRange(380000, 620000),
          format: CaseMathValueFormat.price,
          sharedAcrossProducts: false,
        ),
        CaseMathValueDefinition(
          id: 'sharedLineSetup',
          name: 'Shared line setup',
          caseId: 'case_2',
          range: CaseMathRange(210000, 390000),
          format: CaseMathValueFormat.price,
          sharedAcrossProducts: true,
        ),
        CaseMathValueDefinition(
          id: 'sharedQualityLab',
          name: 'Shared quality lab',
          caseId: 'case_2',
          range: CaseMathRange(140000, 275000),
          format: CaseMathValueFormat.price,
          sharedAcrossProducts: true,
        ),
        CaseMathValueDefinition(
          id: 'utilities',
          name: 'Utilities',
          caseId: 'case_2',
          range: CaseMathRange(96000, 180000),
          format: CaseMathValueFormat.price,
        ),
        CaseMathValueDefinition(
          id: 'warehouseLease',
          name: 'Warehouse lease',
          caseId: 'case_2',
          range: CaseMathRange(155000, 290000),
          format: CaseMathValueFormat.price,
          isDistractor: true,
        ),
        CaseMathValueDefinition(
          id: 'brandCampaign',
          name: 'Brand campaign',
          caseId: 'case_2',
          range: CaseMathRange(72000, 160000),
          format: CaseMathValueFormat.price,
          isDistractor: true,
        ),
      ],
    ),
  ],
  questions: [
    CaseMathQuestionDefinition(
      id: 'product_revenue',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText: 'What revenue does {product} generate?',
      math: 'units * price',
      formula: 'Revenue = Units × Price',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units': CaseMathVariableBinding.value('units', tableId: 'products'),
        'price': CaseMathVariableBinding.value('price', tableId: 'products'),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'unit_cm',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText: 'What is the contribution margin per unit for {product}?',
      math: 'price - variableCost',
      formula: 'CM / unit = Price − Variable cost',
      answerType: CaseMathValueFormat.price,
      variables: {
        'price': CaseMathVariableBinding.value('price', tableId: 'products'),
        'variableCost':
            CaseMathVariableBinding.value('variableCost', tableId: 'products'),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'total_cm_product',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText: 'What total contribution margin does {product} generate?',
      math: 'units * (price - variableCost)',
      formula: 'Total CM = Units × (Price − Variable cost)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units': CaseMathVariableBinding.value('units', tableId: 'products'),
        'price': CaseMathVariableBinding.value('price', tableId: 'products'),
        'variableCost':
            CaseMathVariableBinding.value('variableCost', tableId: 'products'),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'plant_total_revenue',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText: 'What is total plant revenue across all three products?',
      math:
          'units0 * price0 + units1 * price1 + units2 * price2',
      formula: 'Total revenue = Σ (Units × Price)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units0': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'price0': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'units1': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'price1': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'units2': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot2',
        ),
        'price2': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot2',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'plant_total_vc',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText: 'What is total variable cost across all three products?',
      math:
          'units0 * vc0 + units1 * vc1 + units2 * vc2',
      formula: 'Total VC = Σ (Units × Variable cost)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units0': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'vc0': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'units1': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'vc1': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'units2': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot2',
        ),
        'vc2': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'slot2',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'plant_profit_after_fixed',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'What is total plant profit after all listed fixed costs?',
      math:
          '(units0 * price0 + units1 * price1 + units2 * price2) - (units0 * vc0 + units1 * vc1 + units2 * vc2) - (rent + setup + lab + utilities + warehouse + brand)',
      formula:
          'Profit = Total revenue − Total VC − Σ Fixed costs',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units0': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'price0': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'vc0': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'units1': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'price1': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'vc1': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'units2': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot2',
        ),
        'price2': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot2',
        ),
        'vc2': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'slot2',
        ),
        'rent': CaseMathVariableBinding.value('plantRent', tableId: 'fixed'),
        'setup':
            CaseMathVariableBinding.value('sharedLineSetup', tableId: 'fixed'),
        'lab':
            CaseMathVariableBinding.value('sharedQualityLab', tableId: 'fixed'),
        'utilities':
            CaseMathVariableBinding.value('utilities', tableId: 'fixed'),
        'warehouse':
            CaseMathVariableBinding.value('warehouseLease', tableId: 'fixed'),
        'brand':
            CaseMathVariableBinding.value('brandCampaign', tableId: 'fixed'),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'revenue_share',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'What percentage of total plant revenue comes from {product}? (as %)',
      math:
          '(units * price) / (units0 * price0 + units1 * price1 + units2 * price2) * 100',
      formula: 'Share = Product revenue ÷ Total revenue',
      answerType: CaseMathValueFormat.percentage,
      variables: {
        'units': CaseMathVariableBinding.value('units', tableId: 'products'),
        'price': CaseMathVariableBinding.value('price', tableId: 'products'),
        'units0': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'price0': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot0',
        ),
        'units1': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'price1': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot1',
        ),
        'units2': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'slot2',
        ),
        'price2': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'slot2',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'shared_setup_allocation',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'Shared line setup is split between {sharedProduct0} and {sharedProduct1} by units produced. How much setup cost is allocated to {sharedProduct0}?',
      math: 'setup * unitsA / (unitsA + unitsB)',
      formula:
          'Allocated fixed = Shared cost × (Product units ÷ Shared units)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'setup':
            CaseMathVariableBinding.value('sharedLineSetup', tableId: 'fixed'),
        'unitsA': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'shared0',
        ),
        'unitsB': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'shared1',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'shared_lab_allocation',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'Shared quality lab is split between {sharedProduct0} and {sharedProduct1} by units. How much lab cost is allocated to {sharedProduct1}?',
      math: 'lab * unitsB / (unitsA + unitsB)',
      formula:
          'Allocated fixed = Shared cost × (Product units ÷ Shared units)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'lab':
            CaseMathVariableBinding.value('sharedQualityLab', tableId: 'fixed'),
        'unitsA': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'shared0',
        ),
        'unitsB': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'shared1',
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'post_allocation_profit_shared0',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'After allocating shared line setup and quality lab by units to {sharedProduct0} and {sharedProduct1}, what is {sharedProduct0} product profit (CM − its allocated shared fixed costs)?',
      math:
          'unitsA * (priceA - vcA) - setup * unitsA / (unitsA + unitsB) - lab * unitsA / (unitsA + unitsB)',
      formula:
          'Product profit = Total CM − Allocated shared fixed costs',
      answerType: CaseMathValueFormat.price,
      variables: {
        'unitsA': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'shared0',
        ),
        'priceA': CaseMathVariableBinding.value(
          'price',
          tableId: 'products',
          entityRef: 'shared0',
        ),
        'vcA': CaseMathVariableBinding.value(
          'variableCost',
          tableId: 'products',
          entityRef: 'shared0',
        ),
        'unitsB': CaseMathVariableBinding.value(
          'units',
          tableId: 'products',
          entityRef: 'shared1',
        ),
        'setup':
            CaseMathVariableBinding.value('sharedLineSetup', tableId: 'fixed'),
        'lab':
            CaseMathVariableBinding.value('sharedQualityLab', tableId: 'fixed'),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'price_volume_shock',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'If {product} raises price by {priceUplift}% but volume falls by {volumeDrop}%, what is its new revenue?',
      math: 'units * (1 - volumeDrop / 100) * price * (1 + priceUplift / 100)',
      formula: 'New revenue = Units × (1 − volume drop) × Price × (1 + price uplift)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units': CaseMathVariableBinding.value('units', tableId: 'products'),
        'price': CaseMathVariableBinding.value('price', tableId: 'products'),
        'priceUplift': CaseMathVariableBinding.random(
          CaseMathRange(8, 15),
          format: CaseMathValueFormat.number,
        ),
        'volumeDrop': CaseMathVariableBinding.random(
          CaseMathRange(4, 12),
          format: CaseMathValueFormat.number,
        ),
      },
    ),
    CaseMathQuestionDefinition(
      id: 'vc_increase_hit',
      caseId: 'case_2',
      focusTableId: 'products',
      questionText:
          'If {product} variable cost rises by {vcUplift}% with volumes unchanged, how much does total plant profit fall?',
      math: 'units * variableCost * (vcUplift / 100)',
      formula: 'Profit decrease = Units × (Variable cost × uplift)',
      answerType: CaseMathValueFormat.price,
      variables: {
        'units': CaseMathVariableBinding.value('units', tableId: 'products'),
        'variableCost':
            CaseMathVariableBinding.value('variableCost', tableId: 'products'),
        'vcUplift': CaseMathVariableBinding.random(
          CaseMathRange(10, 25),
          format: CaseMathValueFormat.number,
        ),
      },
    ),
  ],
);
