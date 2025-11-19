/// Modèle pour les en-têtes personnalisés des documents (reçus, PDF, rapports)
class DocumentHeaderModel {
  final int id;
  final String companyName;
  final String? companySlogan;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoPath; // Chemin vers le logo
  final String? taxNumber; // Numéro fiscal
  final String? registrationNumber; // Numéro d'enregistrement
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DocumentHeaderModel({
    required this.id,
    required this.companyName,
    this.companySlogan,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.logoPath,
    this.taxNumber,
    this.registrationNumber,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'company_slogan': companySlogan,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'logo_path': logoPath,
      'tax_number': taxNumber,
      'registration_number': registrationNumber,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory DocumentHeaderModel.fromJson(Map<String, dynamic> json) {
    return DocumentHeaderModel(
      id: json['id'] as int,
      companyName: json['company_name'] as String,
      companySlogan: json['company_slogan'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      logoPath: json['logo_path'] as String?,
      taxNumber: json['tax_number'] as String?,
      registrationNumber: json['registration_number'] as String?,
      isActive: (json['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  DocumentHeaderModel copyWith({
    int? id,
    String? companyName,
    String? companySlogan,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? logoPath,
    String? taxNumber,
    String? registrationNumber,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentHeaderModel(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      companySlogan: companySlogan ?? this.companySlogan,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      logoPath: logoPath ?? this.logoPath,
      taxNumber: taxNumber ?? this.taxNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
