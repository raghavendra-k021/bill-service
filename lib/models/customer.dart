class CustomerModel {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? gstin;
  final double totalPurchases;

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.gstin,
    required this.totalPurchases,
  });
}
