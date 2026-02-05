import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../src/colors/colors.dart';
import 'package:apptaxis/models/travel_history_index.dart';
import '../historial_viajes_controller/historial_viajes_controller.dart';

class HistorialViajesPage extends StatefulWidget {
  const HistorialViajesPage({Key? key}) : super(key: key);

  @override
  State<HistorialViajesPage> createState() => _HistorialViajesPageState();
}

class _HistorialViajesPageState extends State<HistorialViajesPage> {
  late HistorialViajesController _controller;

  // ✅ Paginación
  final ScrollController _scroll = ScrollController();
  List<TravelHistoryIndex> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // ✅ Filtro mes/año
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  String get _selectedYearMonth =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  //FILTRO POR DESTINO
  String _searchQuery = '';

  List<TravelHistoryIndex> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((x) => x.to.toLowerCase().contains(q)).toList();
  }

  bool _isWeek = false; // ✅ false = mes, true = semana





  @override
  void initState() {
    super.initState();
    _controller = HistorialViajesController();

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _controller.init(context, refresh);

      await _loadFirstPage();

      _scroll.addListener(() {
        final nearBottom =
            _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200;
        if (nearBottom) _loadMore();
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    final filtered = _filteredItems;
    final isFilterActive = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: blancoCards,
      key: _controller.key,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text(
          "Historial de viajes",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt, color: negro),
            onPressed: _openFiltersSheet,
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.insights, color: negro),
            onPressed: _openSummarySheet,
            tooltip: 'Resumen',
          ),
          const Image(
            height: 40.0,
            width: 100.0,
            image: AssetImage('assets/metax_logo.png'),
          ),
        ],

      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: gris))
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
        children: [
          _periodHeader(),
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                isFilterActive
                    ? 'No hay resultados para tu búsqueda'
                    : (_isWeek
                    ? 'No hay viajes en esta semana'
                    : 'No hay viajes en este mes')
              )

            )
                : RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.only(top: 10),
                itemCount: filtered.length + 1,
                itemBuilder: (_, index) {
                  // ✅ fila final (loader / fin)
                  if (index == filtered.length) {
                    // Si hay búsqueda activa, no mostramos loader
                    if (isFilterActive) {
                      return const SizedBox.shrink();
                    }

                    if (!_hasMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('No hay más resultados'),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loadingMore
                            ? const CircularProgressIndicator(
                          color: gris,
                        )
                            : const SizedBox.shrink(),
                      ),
                    );
                  }

                  final item = filtered[index];

                  final fechaFormateada =
                  DateFormat('dd/MM/yyyy hh:mm a')
                      .format(item.finalViaje.toDate());

                  return _historyCard(
                    destino: item.to,
                    fechaViaje: fechaFormateada,
                    tarifa: item.tarifa,
                    travelId: item.travelHistoryId,   // ✅ el real
                    numeroViaje: item.numeroViaje,    // ✅ número
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  //CA ES PARA LOS DISTINTOS FILTRADOS


  Widget _periodHeader() {
    final now = DateTime.now();

    // Semana: lunes a domingo
    final startWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final endWeekInclusive = startWeek.add(const Duration(days: 6));

    final monthName = DateFormat('MMMM', 'es_CO')
        .format(DateTime(_selectedYear, _selectedMonth, 1));
    final monthTitle =
        '${monthName[0].toUpperCase()}${monthName.substring(1)} $_selectedYear';

    final d1 = DateFormat("d 'de' MMMM 'de' y", 'es_CO').format(startWeek);
    final d2 = DateFormat("d 'de' MMMM 'de' y", 'es_CO').format(endWeekInclusive);

    final weekTitle = 'Esta semana: \nDel $d1 al $d2';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isWeek) ...[
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: negro,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              _isWeek ? weekTitle : monthTitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: negro,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _openFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 8),
                    const Text(
                      'Filtros',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Switch único: Esta semana
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Esta semana',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: _isWeek,
                          onChanged: (v) async {
                            // 1) actualiza estado
                            setModalState(() {});
                            setState(() {
                              _isWeek = v;
                              _searchQuery = '';
                            });

                            // 2) recarga de una vez
                            await _loadFirstPage();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ Mes/Año solo si NO es semana
                    if (!_isWeek) _monthYearSelectorSheet(setModalState),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              setState(() {
                                _isWeek = false;
                                _selectedYear = now.year;
                                _selectedMonth = now.month;
                                _searchQuery = '';
                              });
                              Navigator.pop(context);
                              await _loadFirstPage();
                            },
                            child: const Text('Restablecer'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ Botón especial resumen anual (abre el sheet)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Ver resumen del año'),
                        onPressed: () {
                          Navigator.pop(context);
                          _openYearSummarySheet();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _openYearSummarySheet() {
    final year = _selectedYear; // o DateTime.now().year si quieres siempre actual

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              const SizedBox(height: 10),
              Text(
                'Resumen $year',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _controller.getYearMonthlySummary(year),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: gris)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final data = snapshot.data ?? [];
                  if (data.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aún no hay datos para este año.'),
                    );
                  }

                  final money = NumberFormat.currency(
                    locale: 'es_CO',
                    symbol: '\$ ',
                    decimalDigits: 0,
                    name: '',
                    customPattern: '\u00A4#,##0',
                  );

                  return Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = data[i];
                        final yearMonth = m['yearMonth'] as String;
                        final month = m['month'] as int;
                        final totalTrips = (m['totalTrips'] ?? 0) as int;
                        final totalAmount = (m['totalAmount'] ?? 0) as num;

                        final monthName =
                        DateFormat('MMMM', 'es_CO').format(DateTime(year, month, 1));

                        return ListTile(
                          title: Text(
                            '${monthName[0].toUpperCase()}${monthName.substring(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Viajes: $totalTrips'),
                          trailing: Text(
                            money.format(totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onTap: () async {
                            // ✅ Paso B: aplicar filtro y recargar lista
                            final parts = yearMonth.split('-');
                            final y = int.parse(parts[0]);
                            final mo = int.parse(parts[1]);

                            setState(() {
                              _selectedYear = y;
                              _selectedMonth = mo;
                              _searchQuery = '';
                            });

                            Navigator.pop(context);
                            await _loadFirstPage();
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }


  void _openSummarySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 8),
              const Text(
                'Resumen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              _monthSummary(), // usa tu widget actual

              const SizedBox(height: 8),

              // Extra: un resumen más “pro”
              _summaryExtra(),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryExtra() {
    final totalViajes = _items.length;
    final total = _items.fold<double>(0.0, (sum, x) => sum + x.tarifa);
    final maxTarifa = _items.isEmpty ? 0.0 : _items.map((e) => e.tarifa).reduce((a, b) => a > b ? a : b);
    final minTarifa = _items.isEmpty ? 0.0 : _items.map((e) => e.tarifa).reduce((a, b) => a < b ? a : b);

    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
      name: '',
      customPattern: '\u00A4#,##0',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gris, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viajes cargados: $totalViajes', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Total: ${formatter.format(total)}'),
          Text('Mayor tarifa: ${formatter.format(maxTarifa)}'),
          Text('Menor tarifa: ${formatter.format(minTarifa)}'),
          const SizedBox(height: 6),
          const Text(
            'Nota: el resumen se calcula con los viajes cargados en pantalla. '
                'Si quieres el mes completo sin scrollear, lo hacemos con una consulta agregada.',
            style: TextStyle(fontSize: 10, color: gris),
          ),
        ],
      ),
    );
  }


  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }


  Widget _monthSummary() {
    if (_items.isEmpty) return const SizedBox.shrink();

    final totalViajes = _items.length;
    final total = _items.fold<double>(0.0, (sum, x) => sum + x.tarifa);
    final promedio = totalViajes == 0 ? 0.0 : total / totalViajes;

    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
      name: '',
      customPattern: '\u00A4#,##0',
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gris, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Viajes: $totalViajes', style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text('Total: ${formatter.format(total)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text('Prom: ${formatter.format(promedio)}', style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ✅ selector mes/año
  Widget _monthYearSelectorSheet(void Function(void Function()) setModalState) {
    final years = List.generate(6, (i) => DateTime.now().year - i);
    final months = List.generate(12, (i) => i + 1);

    String monthLabel(int m) =>
        DateFormat('MMMM', 'es_CO').format(DateTime(2026, m, 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          value: _selectedMonth,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Mes',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: months
              .map((m) => DropdownMenuItem(
            value: m,
            child: Text(
              monthLabel(m),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ))
              .toList(),
          onChanged: _isWeek
              ? null
              : (v) async {
            if (v == null) return;

            // ✅ refresca el sheet y el state
            setModalState(() {});
            setState(() {
              _selectedMonth = v;
              _searchQuery = '';
            });

            // ✅ recarga de una vez (sin Aplicar)
            await _loadFirstPage();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _selectedYear,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Año',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: years
              .map((y) => DropdownMenuItem(
            value: y,
            child: Text(y.toString()),
          ))
              .toList(),
          onChanged: _isWeek
              ? null
              : (v) async {
            if (v == null) return;

            setModalState(() {});
            setState(() {
              _selectedYear = v;
              _searchQuery = '';
            });

            await _loadFirstPage();
          },
        ),
      ],
    );
  }


  // ✅ carga primera página según el mes/año seleccionado
  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final res = _isWeek
          ? await _controller.getPaginatedThisWeek(lastDoc: null, limit: 20)
          : await _controller.getPaginated(
        yearMonth: _selectedYearMonth,
        lastDoc: null,
        limit: 20,
      );

      setState(() {
        _items = (res['items'] as List<TravelHistoryIndex>);
        _lastDoc = (res['lastDoc'] as DocumentSnapshot?);
        _hasMore = (res['hasMore'] as bool);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ✅ cargar más
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;

    setState(() => _loadingMore = true);

    try {
      final res = _isWeek
          ? await _controller.getPaginatedThisWeek(lastDoc: _lastDoc, limit: 20)
          : await _controller.getPaginated(
        yearMonth: _selectedYearMonth,
        lastDoc: _lastDoc,
        limit: 20,
      );

      setState(() {
        _items.addAll(res['items'] as List<TravelHistoryIndex>);
        _lastDoc = (res['lastDoc'] as DocumentSnapshot?);
        _hasMore = (res['hasMore'] as bool);
      });
    } catch (_) {
      // opcional
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  // ✅ card con borrar (ocultar)
  Widget _historyCard({
    required String destino,
    required String fechaViaje,
    required double tarifa,
    required String travelId,
    required int numeroViaje,
  }) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
      name: '',
      customPattern: '\u00A4#,##0',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gris, width: 0.5),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 2),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _controller.goToDetailHistory(travelId),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              // ❌ Botón borrar pegado a la esquina
              Positioned(
                top: -10,
                right: -15,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.black,
                    size: 22,
                  ),
                  onPressed: () => _confirmarEliminar(travelId),
                ),
              ),

              // 📄 Contenido
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiqueta
                  Row(
                    children: [
                      Image.asset(
                        'assets/marker_destino.png',
                        height: 10,
                        width: 10,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Destino',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Texto destino
                  Text(
                    destino,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                      height: 1.1,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: gris),
                  const SizedBox(height: 6),

                  Text(
                    'Hora finalización: $fechaViaje',
                    style: const TextStyle(
                      color: gris,
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    formatter.format(tarifa),
                    style: const TextStyle(
                      color: negro,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(String travelId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar viaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: const Text(
          'Este viaje se eliminará solo de tu historial.\n\n'
              'No afecta el registro general.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
            const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _controller.hideFromMyHistory(travelId);
      await _loadFirstPage();
    }
  }
}
