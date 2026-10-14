import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/firestore/firestore_page_size.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../data/models/departure_schedule.dart';
import '../providers/schedules_view_model.dart';

const _scheduleRoutes = ['Indonesia → Jepang', 'Jepang → Indonesia'];
const _scheduleStatuses = ['Open', 'Closed'];
const _loadMoreJastipersValue = '__load_more_jastipers__';

Future<bool> showScheduleForm(
  BuildContext context, {
  DepartureSchedule? initial,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ScheduleFormSheet(initial: initial),
      ),
    ) ??
    false;

class ScheduleFormSheet extends ConsumerStatefulWidget {
  const ScheduleFormSheet({this.initial, super.key});

  final DepartureSchedule? initial;

  @override
  ConsumerState<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends ConsumerState<ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _capacityController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;
  late final TextEditingController _departureDateController;
  late final TextEditingController _lastDropDateController;

  String? _jastiperId;
  String? _route;
  String _status = 'Open';
  DateTime? _departureDate;
  DateTime? _lastDropDate;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final schedule = widget.initial;
    _jastiperId = schedule?.idJastiper;
    _route = schedule?.rute;
    _status = schedule?.status == 'Closed' ? 'Closed' : 'Open';
    _departureDate = SafeCalendarDate.parse(schedule?.tanggalBerangkat);
    _lastDropDate = SafeCalendarDate.parse(schedule?.tanggalLastDrop);
    _capacityController = TextEditingController(
      text: schedule == null ? '' : _formatNumber(schedule.slotBeratKg),
    );
    _feeController = TextEditingController(
      text: schedule == null ? '' : _formatNumber(schedule.hargaFeeJastiper),
    );
    _noteController = TextEditingController(text: schedule?.catatan ?? '');
    _departureDateController = TextEditingController(
      text: _formatDate(_departureDate),
    );
    _lastDropDateController = TextEditingController(
      text: _formatDate(_lastDropDate),
    );
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    _departureDateController.dispose();
    _lastDropDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) => date == null
      ? ''
      : SafeCalendarDate.formatFullIndonesian(SafeCalendarDate.serialize(date));

  Future<void> _pickDate({required bool departure}) async {
    final current = departure ? _departureDate : _lastDropDate;
    final today = DateTime.now();
    final initialDate = current ?? DateTime(today.year, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
      helpText: departure
          ? 'Pilih tanggal keberangkatan'
          : 'Pilih tanggal last drop',
    );
    if (selected == null || !mounted) return;

    setState(() {
      if (departure) {
        _departureDate = selected;
        _departureDateController.text = _formatDate(selected);
      } else {
        _lastDropDate = selected;
        _lastDropDateController.text = _formatDate(selected);
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_jastiperId == null ||
        _route == null ||
        _departureDate == null ||
        _lastDropDate == null) {
      return;
    }

    final capacity = _parseDecimal(_capacityController.text);
    final fee = _parseDecimal(_feeController.text);
    if (capacity == null || fee == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(schedulesViewModelProvider.notifier)
          .saveSchedule(
            id: widget.initial?.id,
            idJastiper: _jastiperId!,
            rute: _route!,
            tanggalBerangkat: SafeCalendarDate.serialize(_departureDate!),
            tanggalLastDrop: SafeCalendarDate.serialize(_lastDropDate!),
            slotBeratKg: capacity,
            status: _status,
            catatan: _noteController.text.trim(),
            hargaFeeJastiper: fee,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore Rules menolak penyimpanan jadwal. Periksa akses admin.',
        'unavailable' => 'Koneksi terputus. Jadwal belum tersimpan; coba lagi.',
        _ => 'Jadwal gagal disimpan. Periksa koneksi lalu coba lagi.',
      };
    }
    if (error is StateError) return error.message;
    return 'Jadwal gagal disimpan. Periksa isian lalu coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schedulesViewModelProvider);
    final validJastiperId =
        state.jastipers.any((jastiper) => jastiper.id == _jastiperId)
        ? _jastiperId
        : null;
    if (_jastiperId != null &&
        validJastiperId == null &&
        state.hasMoreJastipers &&
        !state.isLoadingMoreJastipers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(schedulesViewModelProvider.notifier).loadMoreJastipers();
        }
      });
    }

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial == null ? 'Jadwal baru' : 'Edit jadwal',
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    if (_errorMessage != null) ...[
                      _FormErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 14),
                    ],
                    if (state.jastiperErrorMessage != null) ...[
                      _FormErrorBanner(message: state.jastiperErrorMessage!),
                      const SizedBox(height: 14),
                    ],
                    DropdownButtonFormField<String>(
                      key: ValueKey('jastipers-${state.jastipers.length}'),
                      initialValue: validJastiperId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Jastiper'),
                      hint: const Text('Pilih jastiper'),
                      items: [
                        ...state.jastipers.map(
                          (jastiper) => DropdownMenuItem(
                            value: jastiper.id,
                            child: Text(jastiper.nama),
                          ),
                        ),
                        if (state.hasMoreJastipers)
                          DropdownMenuItem(
                            value: _loadMoreJastipersValue,
                            child: Text(
                              state.isLoadingMoreJastipers
                                  ? 'Memuat jastiper…'
                                  : 'Muat ${FirestorePageSize.value} jastiper lainnya…',
                            ),
                          ),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == _loadMoreJastipersValue) {
                                ref
                                    .read(schedulesViewModelProvider.notifier)
                                    .loadMoreJastipers();
                                return;
                              }
                              setState(() => _jastiperId = value);
                            },
                      validator: (value) => value == null
                          ? 'Pilih jastiper terlebih dahulu.'
                          : null,
                    ),
                    if (state.jastipers.isEmpty &&
                        !state.isLoadingJastipers) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Belum ada jastiper. Tambahkan jastiper sebelum membuat jadwal.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _scheduleRoutes.contains(_route)
                          ? _route
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Rute'),
                      hint: const Text('Pilih rute'),
                      items: _scheduleRoutes
                          .map(
                            (route) => DropdownMenuItem(
                              value: route,
                              child: Text(route),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _route = value),
                      validator: (value) =>
                          value == null ? 'Pilih rute pengiriman.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastDropDateController,
                      readOnly: true,
                      onTap: _isSaving
                          ? null
                          : () => _pickDate(departure: false),
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Tanggal last drop',
                        helperText: 'Batas akhir konsumen menitipkan barang',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (_) => _lastDropDate == null
                          ? 'Pilih tanggal last drop.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _departureDateController,
                      readOnly: true,
                      onTap: _isSaving
                          ? null
                          : () => _pickDate(departure: true),
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Tanggal keberangkatan',
                        suffixIcon: Icon(Icons.flight_takeoff_outlined),
                      ),
                      validator: (_) => _departureDate == null
                          ? 'Pilih tanggal keberangkatan.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _capacityController,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      ],
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Kapasitas bagasi (kg)',
                        hintText: 'Contoh: 50',
                      ),
                      validator: (value) {
                        final parsed = _parseDecimal(value ?? '');
                        if (parsed == null) return 'Masukkan kapasitas angka.';
                        if (parsed < 0) return 'Kapasitas tidak boleh negatif.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _feeController,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      ],
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Fee jastiper (Rp/kg)',
                        hintText: 'Opsional, kosongkan jika Rp 0',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return null;
                        final parsed = _parseDecimal(value!);
                        if (parsed == null) return 'Masukkan fee angka.';
                        if (parsed < 0) return 'Fee tidak boleh negatif.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _scheduleStatuses.contains(_status)
                          ? _status
                          : 'Open',
                      decoration: const InputDecoration(
                        labelText: 'Status jadwal',
                      ),
                      items: _scheduleStatuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noteController,
                      enabled: !_isSaving,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.initial == null ? Icons.add : Icons.check,
                            ),
                      label: Text(
                        _isSaving
                            ? 'Menyimpan…'
                            : widget.initial == null
                            ? 'Buat jadwal'
                            : 'Simpan perubahan',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.error, fontSize: 13),
    ),
  );
}

double? _parseDecimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
