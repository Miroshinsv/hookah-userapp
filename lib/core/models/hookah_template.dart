import 'dart:convert';

class HookahTemplateTobaccoLine {
  final String? tobaccoId;
  final String name;
  final String? flavor;
  final double? grammage;
  final double price;

  const HookahTemplateTobaccoLine({
    this.tobaccoId,
    required this.name,
    this.flavor,
    this.grammage,
    required this.price,
  });

  factory HookahTemplateTobaccoLine.fromJson(Map<String, dynamic> json) =>
      HookahTemplateTobaccoLine(
        tobaccoId: json['tobaccoId'] as String?,
        name: json['name'] as String? ?? '',
        flavor: json['flavor'] as String?,
        grammage: (json['grammage'] as num?)?.toDouble(),
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );
}

class HookahPaidProperty {
  final String propertyId;
  final String name;
  final double price;
  final String kind; // "filling" | "addon"

  const HookahPaidProperty({
    required this.propertyId,
    required this.name,
    required this.price,
    required this.kind,
  });

  factory HookahPaidProperty.fromJson(Map<String, dynamic> json) => HookahPaidProperty(
        propertyId: json['propertyId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        kind: json['kind'] as String? ?? '',
      );
}

class HookahTemplatePricing {
  final double totalPrice;

  const HookahTemplatePricing({required this.totalPrice});

  factory HookahTemplatePricing.fromJson(Map<String, dynamic> json) =>
      HookahTemplatePricing(totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0);
}

// Ноль трактуется бэкендом как "не задано" наравне с null — особенность
// контракта fillingPropertyId (hook.txt, раздел 1).
bool _isUnsetPropertyId(String? id) => id == null || id == '0';

class HookahTemplate {
  final String templateId;
  final String name;
  final int? strength;
  final double basePrice;
  final String? fillingPropertyId;
  final List<HookahTemplateTobaccoLine> tobaccos;
  final HookahTemplatePricing? pricing;

  const HookahTemplate({
    required this.templateId,
    required this.name,
    this.strength,
    required this.basePrice,
    this.fillingPropertyId,
    this.tobaccos = const [],
    this.pricing,
  });

  bool get hasFilling => !_isUnsetPropertyId(fillingPropertyId);
  bool get hasTobaccos => tobaccos.isNotEmpty;

  // hookahTemplates(loungeId) — списочный запрос — не всегда резолвит
  // pricing (totalPrice может прийти 0 даже при ненулевом basePrice, см.
  // план), поэтому отображаемая цена всегда берётся с фолбэком на basePrice.
  double get displayPrice =>
      (pricing != null && pricing!.totalPrice > 0) ? pricing!.totalPrice : basePrice;

  factory HookahTemplate.fromJson(Map<String, dynamic> json) => HookahTemplate(
        templateId: json['templateId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        strength: (json['strength'] as num?)?.toInt(),
        basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
        fillingPropertyId: json['fillingPropertyId'] as String?,
        tobaccos: (json['tobaccos'] as List<dynamic>?)
                ?.map((e) => HookahTemplateTobaccoLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        pricing: json['pricing'] != null
            ? HookahTemplatePricing.fromJson(json['pricing'] as Map<String, dynamic>)
            : null,
      );
}

class TobaccoLineInput {
  final String tobaccoId;
  final String? flavor;
  final double? grammage;

  const TobaccoLineInput({required this.tobaccoId, this.flavor, this.grammage});

  String toGraphQL() {
    final fields = ['tobaccoId: ${jsonEncode(tobaccoId)}'];
    if (flavor != null && flavor!.isNotEmpty) fields.add('flavor: ${jsonEncode(flavor)}');
    if (grammage != null) fields.add('grammage: $grammage');
    return '{ ${fields.join(', ')} }';
  }
}

// Один элемент hookahItems — соответствует HookahItemOrderInput на бэкенде
// (hook.txt). Ровно один способ выбора кальяна на элемент: либо templateId
// (шаблон/по умолчанию), либо непустая комбинация fillingPropertyId/
// tobaccos/additionalPropertyIds (конструктор) — контролируется на стороне
// UI (HookahItemPicker), здесь не валидируется.
class HookahItemInput {
  final String? templateId;
  final String? fillingPropertyId;
  final List<TobaccoLineInput> tobaccos;
  final List<String> additionalPropertyIds;
  final int? strength;
  final String? comment;
  final int quantity;

  const HookahItemInput({
    this.templateId,
    this.fillingPropertyId,
    this.tobaccos = const [],
    this.additionalPropertyIds = const [],
    this.strength,
    this.comment,
    required this.quantity,
  });

  String toGraphQL() {
    final fields = <String>[];
    if (templateId != null) fields.add('templateId: ${jsonEncode(templateId)}');
    if (fillingPropertyId != null) {
      fields.add('fillingPropertyId: ${jsonEncode(fillingPropertyId)}');
    }
    if (tobaccos.isNotEmpty) {
      fields.add('tobaccos: [${tobaccos.map((t) => t.toGraphQL()).join(', ')}]');
    }
    if (additionalPropertyIds.isNotEmpty) {
      fields.add('additionalPropertyIds: [${additionalPropertyIds.map(jsonEncode).join(', ')}]');
    }
    if (strength != null) fields.add('strength: $strength');
    if (comment != null && comment!.isNotEmpty) fields.add('comment: ${jsonEncode(comment)}');
    fields.add('quantity: $quantity');
    return '{ ${fields.join(', ')} }';
  }
}
