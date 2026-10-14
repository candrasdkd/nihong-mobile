class DepartureScheduleDraft {
  const DepartureScheduleDraft({
    required this.idJastiper,
    required this.namaJastiper,
    required this.rute,
    required this.tanggalBerangkat,
    required this.tanggalLastDrop,
    required this.slotBeratKg,
    required this.status,
    required this.catatan,
    required this.hargaFeeJastiper,
  });

  final String idJastiper;
  final String namaJastiper;
  final String rute;
  final String tanggalBerangkat;
  final String tanggalLastDrop;
  final double slotBeratKg;
  final String status;
  final String catatan;
  final double hargaFeeJastiper;

  Map<String, Object?> toFirestore() => {
    'idJastiper': idJastiper,
    'namaJastiper': namaJastiper,
    'rute': rute,
    'tanggalBerangkat': tanggalBerangkat,
    'tanggalLastDrop': tanggalLastDrop,
    'slotBeratKg': slotBeratKg,
    'status': status,
    'catatan': catatan,
    'hargaFeeJastiper': hargaFeeJastiper,
  };
}
