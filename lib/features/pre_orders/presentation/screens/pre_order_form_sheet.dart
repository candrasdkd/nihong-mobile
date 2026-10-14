import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../customers/data/models/customer.dart';
import '../../../customers/presentation/providers/customers_view_model.dart';
import '../../../schedules/data/models/departure_schedule.dart';
import '../../../schedules/presentation/providers/schedules_view_model.dart';
import '../../data/models/pre_order.dart';
import '../providers/pre_orders_view_model.dart';

Future<bool?> showPreOrderFormSheet(
  BuildContext context,
  WidgetRef ref, {
  PreOrder? initial,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.background,
  builder: (_) => PreOrderFormSheet(initial: initial),
);

class PreOrderFormSheet extends ConsumerStatefulWidget {
  const PreOrderFormSheet({this.initial, super.key});

  final PreOrder? initial;

  @override
  ConsumerState<PreOrderFormSheet> createState() => _PreOrderFormSheetState();
}

class _PreOrderFormSheetState extends ConsumerState<PreOrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();
  final List<TextEditingController> _itemControllers = [];
  final List<PreOrderItem> _items = [];
  String? _scheduleId;
  String? _customerId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _scheduleId = initial?.idJadwal;
    _customerId = initial?.idPelanggan;
    _weightController.text = initial?.totalKg.toString() ?? '';
    _noteController.text = initial?.catatan ?? '';
    final initialItems = initial?.items.isNotEmpty == true
        ? initial!.items
        : const [PreOrderItem(namaBarang: '', checked: false)];
    for (final item in initialItems) {
      _items.add(item);
      _itemControllers.add(TextEditingController(text: item.namaBarang));
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasCheckedItems => _items.any((item) => item.checked);

  void _addItem() {
    setState(() {
      _items.add(const PreOrderItem(namaBarang: '', checked: false));
      _itemControllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (_items[index].checked) return;
    setState(() {
      _items.removeAt(index);
      _itemControllers.removeAt(index).dispose();
    });
  }

  Future<void> _save(
    List<DepartureSchedule> schedules,
    List<Customer> customers,
  ) async {
    if (_items.isEmpty || _items.length > 100) {
      setState(() => _error = 'Booking harus berisi 1 sampai 100 barang.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final schedule = schedules
        .where((item) => item.id == _scheduleId)
        .firstOrNull;
    final customer = customers
        .where((item) => item.id == _customerId)
        .firstOrNull;
    if (schedule == null || customer == null) {
      setState(() => _error = 'Pilih jadwal dan pelanggan yang valid.');
      return;
    }

    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    if (weight == null || !weight.isFinite || weight < 0) {
      setState(() => _error = 'Berat booking harus nol atau lebih.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final initial = widget.initial;
      final booking = PreOrder(
        id: initial?.id ?? '',
        idJadwal: schedule.id,
        namaJastiper: schedule.namaJastiper,
        rute: schedule.rute,
        tanggalBerangkat: schedule.tanggalBerangkat,
        idPelanggan: customer.id,
        namaPelanggan: customer.nama,
        noTelponPelanggan: customer.telpon,
        pic: initial?.pic,
        items: List.generate(
          _items.length,
          (index) => PreOrderItem(
            namaBarang: _items[index].checked
                ? _items[index].namaBarang
                : _itemControllers[index].text.trim(),
            kategori: _items[index].kategori,
            catatan: _items[index].catatan,
            checked: _items[index].checked,
          ),
        ),
        totalKg: weight,
        status: initial?.status ?? 'Pending',
        catatan: _noteController.text.trim(),
        nihongStoreOrderId: initial?.nihongStoreOrderId,
        nihongStoreOrderNo: initial?.nihongStoreOrderNo,
        convertedOrderId: initial?.convertedOrderId,
        deliveryAddressShareToken: initial?.deliveryAddressShareToken,
        deliveryAddressShareCreatedAt: initial?.deliveryAddressShareCreatedAt,
        productShareToken: initial?.productShareToken,
        createdAt: initial?.createdAt,
        updatedAt: initial?.updatedAt,
      );
      await ref
          .read(preOrdersViewModelProvider.notifier)
          .savePreOrder(booking, existingId: initial?.id);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(schedulesViewModelProvider);
    final customerState = ref.watch(customersViewModelProvider);
    final schedules = scheduleState.schedules;
    final customers = customerState.customers;
    final schedule = schedules
        .where((item) => item.id == _scheduleId)
        .firstOrNull;
    final customer = customers
        .where((item) => item.id == _customerId)
        .firstOrNull;
    final isEditing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.98,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit booking' : 'Booking baru',
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: 12),
                    ],
                    if (scheduleState.isLoadingSchedules ||
                        customerState.isLoading)
                      const LinearProgressIndicator(),
                    if (scheduleState.scheduleErrorMessage != null ||
                        customerState.errorMessage != null)
                      _ErrorBanner(
                        message:
                            scheduleState.scheduleErrorMessage ??
                            customerState.errorMessage!,
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: schedule == null ? null : _scheduleId,
                      decoration: const InputDecoration(
                        labelText: 'Jadwal keberangkatan *',
                        prefixIcon: Icon(Icons.flight_takeoff_outlined),
                      ),
                      items: schedules
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.rute} • ${SafeCalendarDate.formatFullIndonesian(item.tanggalBerangkat)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving || _hasCheckedItems
                          ? null
                          : (value) => setState(() => _scheduleId = value),
                      validator: (value) =>
                          value == null ? 'Pilih jadwal.' : null,
                    ),
                    const SizedBox(height: 12),
                    if (schedule != null)
                      _SelectionSummary(
                        icon: Icons.badge_outlined,
                        title: schedule.namaJastiper,
                        subtitle:
                            'Terisi ${_formatKg(schedule.beratTerpakai)} / ${_formatKg(schedule.slotBeratKg)} kg',
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: customer == null ? null : _customerId,
                      decoration: const InputDecoration(
                        labelText: 'Pelanggan *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: customers
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                item.nama,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _customerId = value),
                      validator: (value) =>
                          value == null ? 'Pilih pelanggan.' : null,
                    ),
                    if (customerState.status == CustomersStatus.data &&
                        customers.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Daftar pelanggan masih kosong. Tambahkan pelanggan terlebih dahulu.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Daftar barang',
                            style: TextStyle(
                              color: AppColors.navyDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _addItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah barang'),
                        ),
                      ],
                    ),
                    for (var index = 0; index < _items.length; index++) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _itemControllers[index],
                              readOnly: _items[index].checked,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: 'Barang ${index + 1} *',
                                prefixIcon: Icon(
                                  _items[index].checked
                                      ? Icons.check_circle_outline
                                      : Icons.shopping_bag_outlined,
                                  color: _items[index].checked
                                      ? AppColors.success
                                      : null,
                                ),
                                suffixText: _items[index].checked
                                    ? 'Sudah dibeli'
                                    : null,
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty == true
                                  ? 'Nama barang wajib diisi.'
                                  : (value?.trim().length ?? 0) > 200
                                  ? 'Nama barang maksimal 200 karakter.'
                                  : null,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus barang',
                            onPressed: _saving || _items[index].checked
                                ? null
                                : () => _removeItem(index),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total berat (kg) *',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                      validator: (value) {
                        final weight = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        if (weight == null || !weight.isFinite || weight < 0) {
                          return 'Masukkan berat nol atau lebih.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed:
                          _saving ||
                              scheduleState.isLoadingSchedules ||
                              customerState.isLoading
                          ? null
                          : () => _save(schedules, customers),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Menyimpan…' : 'Simpan booking'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.navy.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(icon, color: AppColors.navyLight),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.07),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(12),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.error, fontSize: 13),
    ),
  );
}

String _formatKg(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
