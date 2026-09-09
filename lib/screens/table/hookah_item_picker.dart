import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/mutations.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/hookah_template.dart';
import '../../core/models/tobacco.dart';
import '../../core/utils/logger.dart';

class HookahPickResult {
  final HookahItemInput input;
  final String displayName;
  final double unitPrice;

  const HookahPickResult({
    required this.input,
    required this.displayName,
    required this.unitPrice,
  });
}

// Выбор кальяна для заказа — шаблон / кальян по умолчанию / конструктор
// (hook.txt). Тот же паттерн, что и showMenuItemPicker: модальный bottom
// sheet, вызывающий код (new_order_screen / order_detail_screen) решает,
// класть результат в локальную корзину или сразу слать в addOrderItems.
Future<HookahPickResult?> showHookahItemPicker(
  BuildContext context, {
  required String loungeId,
}) {
  return showModalBottomSheet<HookahPickResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HookahPickerSheet(loungeId: loungeId),
  );
}

enum _Step { root, confirm, constructor }

class _HookahPickerSheet extends StatefulWidget {
  final String loungeId;

  const _HookahPickerSheet({required this.loungeId});

  @override
  State<_HookahPickerSheet> createState() => _HookahPickerSheetState();
}

class _TobaccoLineDraft {
  final HookahTobacco tobacco;
  final TextEditingController grammageCtrl = TextEditingController();
  final TextEditingController flavorCtrl = TextEditingController();

  _TobaccoLineDraft(this.tobacco);

  void dispose() {
    grammageCtrl.dispose();
    flavorCtrl.dispose();
  }
}

class _HookahPickerSheetState extends State<_HookahPickerSheet> {
  static const _tag = 'HookahPicker';

  bool _loading = true;
  String? _loadError;
  List<HookahTemplate> _templates = const [];
  HookahTemplate? _defaultTemplate;
  List<HookahPaidProperty> _paidProperties = const [];
  List<HookahTobacco> _tobaccos = const [];

  _Step _step = _Step.root;

  // --- confirm (шаблон / по умолчанию) ---
  HookahTemplate? _confirmTemplate;
  int _confirmStrength = 5;
  bool _confirmStrengthTouched = false;
  final _confirmCommentCtrl = TextEditingController();
  int _confirmQuantity = 1;

  // --- constructor ---
  String? _fillingPropertyId;
  final List<_TobaccoLineDraft> _selectedTobaccos = [];
  final Set<String> _selectedAddonIds = {};
  int _constructorStrength = 5;
  final _constructorCommentCtrl = TextEditingController();
  int _constructorQuantity = 1;
  double? _previewTotalPrice;
  bool _previewLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _confirmCommentCtrl.dispose();
    _constructorCommentCtrl.dispose();
    for (final line in _selectedTobaccos) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final results = await Future.wait([
      client.query(QueryOptions(
        document: gql(GQLQueries.hookahTemplates(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      client.query(QueryOptions(
        document: gql(GQLQueries.defaultHookahTemplate(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      client.query(QueryOptions(
        document: gql(GQLQueries.paidProperties(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      client.query(QueryOptions(
        document: gql(GQLQueries.tobaccos(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
    ]);

    if (!mounted) return;

    final templatesResult = results[0];
    if (templatesResult.hasException) {
      final message = templatesResult.exception?.graphqlErrors.firstOrNull?.message ??
          'Не удалось загрузить кальянное меню';
      AppLogger.w(_tag, 'load hookahTemplates failed loungeId=${widget.loungeId}: $message');
      setState(() {
        _loading = false;
        _loadError = message;
      });
      return;
    }
    final templatesData = (templatesResult.data?['hookahTemplates'] as List<Object?>?) ?? const [];
    final templates =
        templatesData.cast<Map<String, dynamic>>().map(HookahTemplate.fromJson).toList();

    // Кальян по умолчанию и доп. свойства — вспомогательные данные, сбой их
    // загрузки не блокирует шаблоны/конструктор (hook.txt: "по умолчанию"
    // просто не настроен для многих лаунджей — это ожидаемо, не ошибка).
    HookahTemplate? defaultTemplate;
    final defaultResult = results[1];
    if (defaultResult.hasException) {
      AppLogger.w(_tag, 'load defaultHookahTemplate failed loungeId=${widget.loungeId}',
          defaultResult.exception);
    } else {
      final data = defaultResult.data?['defaultHookahTemplate'] as Map<String, dynamic>?;
      if (data != null) defaultTemplate = HookahTemplate.fromJson(data);
    }

    var paidProperties = const <HookahPaidProperty>[];
    final propsResult = results[2];
    if (propsResult.hasException) {
      AppLogger.w(
          _tag, 'load paidProperties failed loungeId=${widget.loungeId}', propsResult.exception);
    } else {
      final data = (propsResult.data?['paidProperties'] as List<Object?>?) ?? const [];
      paidProperties = data.cast<Map<String, dynamic>>().map(HookahPaidProperty.fromJson).toList();
    }

    var tobaccos = const <HookahTobacco>[];
    final tobaccosResult = results[3];
    if (tobaccosResult.hasException) {
      AppLogger.w(_tag, 'load tobaccos failed loungeId=${widget.loungeId}', tobaccosResult.exception);
    } else {
      final data = (tobaccosResult.data?['tobaccos'] as List<Object?>?) ?? const [];
      tobaccos = data.cast<Map<String, dynamic>>().map(HookahTobacco.fromJson).toList();
    }

    AppLogger.d(
      _tag,
      'loaded loungeId=${widget.loungeId} templates=${templates.length} '
      'hasDefault=${defaultTemplate != null} paidProperties=${paidProperties.length} '
      'tobaccos=${tobaccos.length}',
    );

    setState(() {
      _loading = false;
      _templates = templates;
      _defaultTemplate = defaultTemplate;
      _paidProperties = paidProperties;
      _tobaccos = tobaccos;
    });
  }

  List<HookahPaidProperty> get _fillings =>
      _paidProperties.where((p) => p.kind == 'filling').toList();
  List<HookahPaidProperty> get _addons => _paidProperties.where((p) => p.kind == 'addon').toList();

  HookahPaidProperty? _propertyById(String? id) {
    if (id == null) return null;
    for (final p in _paidProperties) {
      if (p.propertyId == id) return p;
    }
    return null;
  }

  void _openConfirm(HookahTemplate template) {
    setState(() {
      _confirmTemplate = template;
      _confirmStrength = template.strength ?? 5;
      _confirmStrengthTouched = false;
      _confirmCommentCtrl.clear();
      _confirmQuantity = 1;
      _step = _Step.confirm;
    });
  }

  void _openConstructor() {
    setState(() {
      _fillingPropertyId = null;
      for (final line in _selectedTobaccos) {
        line.dispose();
      }
      _selectedTobaccos.clear();
      _selectedAddonIds.clear();
      _constructorStrength = 5;
      _constructorCommentCtrl.clear();
      _constructorQuantity = 1;
      _previewTotalPrice = null;
      _step = _Step.constructor;
    });
  }

  void _backToRoot() {
    _debounce?.cancel();
    setState(() {
      _confirmTemplate = null;
      _step = _Step.root;
    });
  }

  void _submitConfirm() {
    final template = _confirmTemplate!;
    final input = HookahItemInput(
      templateId: template.templateId,
      strength: _confirmStrengthTouched ? _confirmStrength : null,
      comment: _confirmCommentCtrl.text.trim().isEmpty ? null : _confirmCommentCtrl.text.trim(),
      quantity: _confirmQuantity,
    );
    Navigator.pop(
      context,
      HookahPickResult(
        input: input,
        displayName: template.name,
        unitPrice: template.displayPrice,
      ),
    );
  }

  bool get _constructorIsEmpty =>
      _fillingPropertyId == null && _selectedTobaccos.isEmpty && _selectedAddonIds.isEmpty;

  void _scheduleConstructorPreview() {
    _debounce?.cancel();
    if (_constructorIsEmpty) {
      setState(() => _previewTotalPrice = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _fetchConstructorPreview);
  }

  Future<void> _fetchConstructorPreview() async {
    if (!mounted || _constructorIsEmpty) return;
    setState(() => _previewLoading = true);

    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.priceCustomHookah(
        loungeId: widget.loungeId,
        strength: _constructorStrength,
        fillingPropertyId: _fillingPropertyId,
        tobaccos: _selectedTobaccos
            .map((l) => TobaccoLineInput(
                  tobaccoId: l.tobacco.tobaccoId,
                  flavor: l.flavorCtrl.text.trim().isEmpty ? null : l.flavorCtrl.text.trim(),
                  grammage: double.tryParse(l.grammageCtrl.text.trim()),
                ))
            .toList(),
        additionalPropertyIds: _selectedAddonIds.toList(),
      )),
    ));

    if (!mounted) return;
    setState(() => _previewLoading = false);

    if (result.hasException) {
      AppLogger.w(_tag, 'priceCustomHookah failed loungeId=${widget.loungeId}', result.exception);
      return;
    }
    final data = result.data?['priceCustomHookah'] as Map<String, dynamic>?;
    if (data == null) return;
    setState(() => _previewTotalPrice = (data['totalPrice'] as num?)?.toDouble());
  }

  void _submitConstructor() {
    final input = HookahItemInput(
      fillingPropertyId: _fillingPropertyId,
      tobaccos: _selectedTobaccos
          .map((l) => TobaccoLineInput(
                tobaccoId: l.tobacco.tobaccoId,
                flavor: l.flavorCtrl.text.trim().isEmpty ? null : l.flavorCtrl.text.trim(),
                grammage: double.tryParse(l.grammageCtrl.text.trim()),
              ))
          .toList(),
      additionalPropertyIds: _selectedAddonIds.toList(),
      strength: _constructorStrength,
      comment:
          _constructorCommentCtrl.text.trim().isEmpty ? null : _constructorCommentCtrl.text.trim(),
      quantity: _constructorQuantity,
    );
    Navigator.pop(
      context,
      HookahPickResult(
        input: input,
        displayName: 'Свой кальян',
        unitPrice: _previewTotalPrice ?? 0.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (_step) {
      case _Step.root:
        title = 'Добавить кальян';
        break;
      case _Step.confirm:
        title = _confirmTemplate?.name ?? 'Кальян';
        break;
      case _Step.constructor:
        title = 'Собрать самому';
        break;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          if (_step != _Step.root)
            IconButton(
              onPressed: _backToRoot,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!, textAlign: TextAlign.center));
    }
    switch (_step) {
      case _Step.root:
        return _buildRoot();
      case _Step.confirm:
        return _buildConfirm();
      case _Step.constructor:
        return _buildConstructor();
    }
  }

  Widget _buildRoot() {
    final children = <Widget>[];

    if (_defaultTemplate != null) {
      final tpl = _defaultTemplate!;
      children.add(Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: ListTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('Кальян по умолчанию'),
          subtitle: Text(tpl.name),
          trailing: Text('${tpl.displayPrice.toStringAsFixed(0)} ₽'),
          onTap: () => _openConfirm(tpl),
        ),
      ));
      children.add(const SizedBox(height: 16));
    }

    children.add(const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text('Выбрать из меню', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ));
    if (_templates.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('В этой кальянной пока нет шаблонов', style: TextStyle(color: Colors.grey)),
      ));
    } else {
      for (final tpl in _templates) {
        children.add(_buildTemplateTile(tpl));
      }
    }

    children.add(const SizedBox(height: 16));
    children.add(SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openConstructor,
        icon: const Icon(Icons.build_outlined),
        label: const Text('Собрать самому'),
      ),
    ));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: children,
    );
  }

  Widget _buildTemplateTile(HookahTemplate tpl) {
    final subtitleParts = <String>[];
    if (tpl.hasFilling) {
      final filling = _propertyById(tpl.fillingPropertyId);
      subtitleParts.add(filling != null ? filling.name : 'Наполнение');
    }
    if (tpl.hasTobaccos) {
      subtitleParts.add(tpl.tobaccos.map((t) => t.name).join(', '));
    }
    return Card(
      child: ListTile(
        title: Text(tpl.name),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
        trailing: Text('${tpl.displayPrice.toStringAsFixed(0)} ₽'),
        onTap: () => _openConfirm(tpl),
      ),
    );
  }

  Widget _buildConfirm() {
    final tpl = _confirmTemplate!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('${tpl.displayPrice.toStringAsFixed(0)} ₽',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Text(
          _confirmStrengthTouched
              ? 'Крепость: $_confirmStrength'
              : 'Крепость: $_confirmStrength (как в шаблоне)',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Slider(
          value: _confirmStrength.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$_confirmStrength',
          onChanged: (v) => setState(() {
            _confirmStrength = v.round();
            _confirmStrengthTouched = true;
          }),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCommentCtrl,
          decoration: const InputDecoration(
            labelText: 'Вкус',
            hintText: 'манго-маракуйя с мятой',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _QuantityStepper(
          quantity: _confirmQuantity,
          onChanged: (v) => setState(() => _confirmQuantity = v),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitConfirm,
            child: const Text('Добавить'),
          ),
        ),
      ],
    );
  }

  Widget _buildConstructor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text('Наполнение', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Без наполнения'),
              selected: _fillingPropertyId == null,
              onSelected: (_) {
                setState(() => _fillingPropertyId = null);
                _scheduleConstructorPreview();
              },
            ),
            for (final f in _fillings)
              ChoiceChip(
                label: Text('${f.name} · ${f.price.toStringAsFixed(0)} ₽'),
                selected: _fillingPropertyId == f.propertyId,
                onSelected: (_) {
                  setState(() => _fillingPropertyId = f.propertyId);
                  _scheduleConstructorPreview();
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Табаки', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        if (_tobaccos.isEmpty)
          const Text('В этой кальянной пока нет табаков в каталоге',
              style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in _tobaccos)
                FilterChip(
                  label: Text(t.name),
                  selected: _selectedTobaccos.any((l) => l.tobacco.tobaccoId == t.tobaccoId),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTobaccos.add(_TobaccoLineDraft(t));
                      } else {
                        final line = _selectedTobaccos
                            .firstWhere((l) => l.tobacco.tobaccoId == t.tobaccoId);
                        _selectedTobaccos.remove(line);
                        line.dispose();
                      }
                    });
                    _scheduleConstructorPreview();
                  },
                ),
            ],
          ),
        for (final line in _selectedTobaccos) _buildTobaccoLineRow(line),
        const SizedBox(height: 20),
        const Text('Дополнительно', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        if (_addons.isEmpty)
          const Text('Нет доступных доп. свойств', style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final a in _addons)
                FilterChip(
                  label: Text('${a.name} · ${a.price.toStringAsFixed(0)} ₽'),
                  selected: _selectedAddonIds.contains(a.propertyId),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAddonIds.add(a.propertyId);
                      } else {
                        _selectedAddonIds.remove(a.propertyId);
                      }
                    });
                    _scheduleConstructorPreview();
                  },
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text('Крепость: $_constructorStrength', style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(
          value: _constructorStrength.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$_constructorStrength',
          onChanged: (v) {
            setState(() => _constructorStrength = v.round());
            _scheduleConstructorPreview();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Цена: ', style: TextStyle(fontWeight: FontWeight.w600)),
            if (_previewLoading)
              const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text(
                _previewTotalPrice != null
                    ? '${_previewTotalPrice!.toStringAsFixed(0)} ₽'
                    : '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _constructorCommentCtrl,
          decoration: const InputDecoration(
            labelText: 'Вкус',
            hintText: 'манго-маракуйя с мятой',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _QuantityStepper(
          quantity: _constructorQuantity,
          onChanged: (v) => setState(() => _constructorQuantity = v),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _constructorIsEmpty ? null : _submitConstructor,
            child: const Text('Добавить'),
          ),
        ),
      ],
    );
  }

  Widget _buildTobaccoLineRow(_TobaccoLineDraft line) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(line.tobacco.name)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.flavorCtrl,
              decoration: const InputDecoration(hintText: 'Вкус', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: line.grammageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'г', isDense: true),
              onChanged: (_) => _scheduleConstructorPreview(),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedTobaccos.remove(line);
                line.dispose();
              });
              _scheduleConstructorPreview();
            },
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Количество', style: TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        IconButton(
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$quantity', style: const TextStyle(fontSize: 16)),
        IconButton(
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
