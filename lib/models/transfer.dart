class Transfer {
  final String no;
  final String code;
  final String descr;
  final String from;
  final String to;
  final int qty;

  final String serialNo;
  final String batchNo;

  Transfer({
    required this.no,
    required this.code,
    required this.descr,
    required this.from,
    required this.to,
    required this.qty,
    required this.serialNo,
    required this.batchNo,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      no: json['no']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      descr: json['descr']?.toString() ?? '',
      from: json['lFrom']?.toString() ?? '',
      to: json['lTo']?.toString() ?? '',
      qty: (json['qty'] ?? 0) is int
          ? json['qty']
          : int.tryParse(json['qty'].toString()) ?? 0,

      serialNo: json['serialNo']?.toString() ?? '',
      batchNo: json['batchNo']?.toString() ?? '',
    );
  }
}