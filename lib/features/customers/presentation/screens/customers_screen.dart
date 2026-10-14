import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/firestore/firestore_page_size.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/load_more_tile.dart';
import '../../data/models/customer.dart';
import '../providers/customers_view_model.dart';

bool _shouldLoadMoreOnScroll(ScrollNotification notification) {
  if (notification is! ScrollUpdateNotification ||
      notification.metrics.maxScrollExtent <= 0) {
    return false;
  }

  final maxExtent = notification.metrics.maxScrollExtent;
  final threshold = maxExtent < 240 ? maxExtent * 0.25 : 240.0;
  return notification.metrics.pixels >= maxExtent - threshold;
}

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customersViewModelProvider);
    final viewModel = ref.read(customersViewModelProvider.notifier);
    final customers = state.filteredCustomers;

    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: viewModel.setQuery,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Cari nama, telepon, atau alamat',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () => viewModel.setQuery(''),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            if (state.isSearchingNames)
              const LinearProgressIndicator(minHeight: 2),
            if (state.isFromCache) const _CacheNotice(),
            if (state.errorMessage != null && state.customers.isNotEmpty)
              _CustomersErrorNotice(
                message: state.errorMessage!,
                onRetry: viewModel.retry,
              ),
            if (state.isLoading && state.customers.isEmpty)
              const Expanded(
                child: AppLoadingView(message: 'Memuat pelanggan…'),
              )
            else if (state.errorMessage != null && state.customers.isEmpty)
              Expanded(
                child: _CustomersLoadError(
                  message: state.errorMessage!,
                  onRetry: viewModel.retry,
                ),
              )
            else if (state.status == CustomersStatus.data &&
                state.customers.isEmpty)
              const Expanded(child: _EmptyCustomers())
            else if (state.status == CustomersStatus.data && customers.isEmpty)
              Expanded(
                child: state.isSearchingNames
                    ? const Center(child: CircularProgressIndicator())
                    : state.hasMoreResults
                    ? NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_shouldLoadMoreOnScroll(notification)) {
                            viewModel.loadMore();
                          }
                          return false;
                        },
                        child: ListView(
                          children: [
                            SizedBox(
                              height: 220,
                              child: _NoSearchResults(query: state.query),
                            ),
                            LoadMoreTile(
                              onPressed: viewModel.loadMore,
                              isLoading: state.isLoadingMore,
                              errorMessage: state.errorMessage,
                              label: state.hasMoreNameSearchResults
                                  ? 'Muat hasil nama berikutnya'
                                  : 'Muat data lainnya',
                            ),
                          ],
                        ),
                      )
                    : _NoSearchResults(query: state.query),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.query.trim().isEmpty
                              ? '${customers.length} cocok • ${state.customers.length} data dimuat'
                              : '${customers.length} cocok • awalan nama dicari di semua data',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_shouldLoadMoreOnScroll(notification)) {
                            viewModel.loadMore();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount:
                              customers.length + (state.hasMoreResults ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index >= customers.length) {
                              return LoadMoreTile(
                                onPressed: viewModel.loadMore,
                                isLoading: state.isLoadingMore,
                                errorMessage: state.errorMessage,
                                label: state.query.trim().isEmpty
                                    ? 'Muat ${FirestorePageSize.value} pelanggan lainnya'
                                    : state.hasMoreNameSearchResults
                                    ? 'Muat hasil nama berikutnya'
                                    : 'Muat data lainnya',
                              );
                            }
                            return _CustomerCard(customer: customers[index]);
                          },
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final name = customer.nama.trim().isEmpty ? 'Tanpa nama' : customer.nama;
    final phone = _firstText([
      customer.telpon,
      customer.alamatPengirimanIndonesia?.noHp,
      customer.alamatPengirimanJepang?.noHpAktif,
    ]);
    final address = _firstText([
      customer.alamat,
      customer.alamatPengirimanIndonesia?.alamatPenerima,
      customer.alamatPengirimanJepang?.alamatPenerimaRomaji,
      customer.alamatPengirimanJepang?.alamatPenerima,
    ]);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _CustomerDetailSheet(customer: customer),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                foregroundColor: AppColors.navy,
                child: Text(_initials(name)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (phone != null) ...[
                      const SizedBox(height: 5),
                      _IconText(icon: Icons.phone_outlined, text: phone),
                    ],
                    if (address != null) ...[
                      const SizedBox(height: 4),
                      _IconText(
                        icon: Icons.location_on_outlined,
                        text: address,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 8),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetailSheet extends StatelessWidget {
  const _CustomerDetailSheet({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final indonesia = customer.alamatPengirimanIndonesia;
    final japan = customer.alamatPengirimanJepang;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Profil pelanggan',
                      style: TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _ProfileSection(
                    title: 'Informasi pelanggan',
                    rows: [
                      _ProfileRow('Nama', _display(customer.nama)),
                      _ProfileRow('Telepon', _display(customer.telpon)),
                      _ProfileRow('Alamat', _display(customer.alamat)),
                    ],
                  ),
                  if (indonesia != null) ...[
                    const SizedBox(height: 12),
                    _ProfileSection(
                      title: 'Alamat pengiriman Indonesia',
                      rows: [
                        _ProfileRow(
                          'Nama penerima',
                          _display(indonesia.namaPenerima),
                        ),
                        _ProfileRow(
                          'Alamat',
                          _display(indonesia.alamatPenerima),
                        ),
                        _ProfileRow('Kode pos', _display(indonesia.kodePos)),
                        _ProfileRow('No. HP', _display(indonesia.noHp)),
                      ],
                    ),
                  ],
                  if (japan != null) ...[
                    const SizedBox(height: 12),
                    _ProfileSection(
                      title: 'Alamat pengiriman Jepang',
                      rows: [
                        _ProfileRow(
                          'Nama penerima',
                          _display(
                            japan.namaPenerima ?? japan.namaPenerimaRomaji,
                          ),
                        ),
                        _ProfileRow(
                          'Alamat Romaji',
                          _display(
                            japan.alamatPenerimaRomaji ?? japan.alamatPenerima,
                          ),
                        ),
                        _ProfileRow(
                          'Alamat Kanji',
                          _display(japan.alamatPenerimaKanji),
                        ),
                        _ProfileRow('Kode pos', _display(japan.kodePos)),
                        _ProfileRow('No. HP aktif', _display(japan.noHpAktif)),
                        _ProfileRow(
                          'Waktu penerimaan',
                          _display(japan.jamPenerimaPaket),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ProfileSection(
                    title: 'ID dokumen',
                    rows: [_ProfileRow('Firestore ID', customer.id)],
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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.rows});

  final String title;
  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows) ...[
              if (row != rows.first) const Divider(height: 18),
              Text(
                row.label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                row.value,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileRow {
  const _ProfileRow(this.label, this.value);

  final String label;
  final String value;
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warning),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Menampilkan data cache; koneksi atau data terbaru belum dikonfirmasi.',
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _CustomersErrorNotice extends StatelessWidget {
  const _CustomersErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers();

  @override
  Widget build(BuildContext context) => const _EmptyMessage(
    icon: Icons.people_outline,
    title: 'Belum ada data pelanggan',
    message: 'Data pelanggan dari Firestore akan muncul di sini.',
  );
}

class _CustomersLoadError extends StatelessWidget {
  const _CustomersLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 14),
          const Text(
            'Pelanggan belum dapat dimuat',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navyDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => _EmptyMessage(
    icon: Icons.search_off,
    title: 'Pelanggan tidak ditemukan',
    message: 'Tidak ada hasil untuk “$query”.',
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navyDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.maxLines = 1});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: AppColors.textMuted),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    ],
  );
}

String? _firstText(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _display(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Belum diisi' : trimmed;
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words
      .take(2)
      .map((word) => word.characters.first)
      .join()
      .toUpperCase();
}
