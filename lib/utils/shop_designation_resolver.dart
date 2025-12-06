import '../models/shop_model.dart';
import '../services/shop_service.dart';

/// Utilitaire pour résoudre automatiquement les désignations de shops
/// à partir de leurs IDs partout dans l'application
/// 
/// UTILISATION RECOMMANDÉE:
/// - Dans les widgets avec Provider: `context.read<ShopService>().getShopDesignation(shopId)`
/// - Dans les services: `ShopService.instance.getShopDesignation(shopId)`
/// - Pour la compatibilité: `ShopDesignationResolver.resolve(shopId: id, designation: designation)`
class ShopDesignationResolver {
  /// Résout la désignation d'un shop à partir de son ID
  /// Cherche automatiquement dans ShopService.instance.shops si non fourni
  /// 
  /// Préférer l'utilisation de `ShopService.instance.getShopDesignation(shopId)` directement
  static String resolve({
    required int? shopId,
    String? designation,
    List<ShopModel>? shops,
  }) {
    // Si une désignation valide est fournie, l'utiliser
    if (designation != null && designation.isNotEmpty) {
      return designation;
    }
    
    // Utiliser ShopService.instance pour résoudre
    return ShopService.instance.getShopDesignation(
      shopId,
      existingDesignation: designation,
    );
  }
  
  /// Résout la désignation du shop source
  static String resolveSource({
    required int? shopSourceId,
    String? shopSourceDesignation,
    List<ShopModel>? shops,
  }) {
    return resolve(
      shopId: shopSourceId,
      designation: shopSourceDesignation,
      shops: shops,
    );
  }
  
  /// Résout la désignation du shop destination
  static String resolveDestination({
    required int? shopDestinationId,
    String? shopDestinationDesignation,
    List<ShopModel>? shops,
  }) {
    return resolve(
      shopId: shopDestinationId,
      designation: shopDestinationDesignation,
      shops: shops,
    );
  }
}

/// Extension sur int? pour résoudre directement un shop ID en désignation
extension ShopIdExtension on int? {
  /// Résout ce shop ID en désignation
  String toShopDesignation({List<ShopModel>? shops}) {
    return ShopDesignationResolver.resolve(
      shopId: this,
      designation: null,
      shops: shops,
    );
  }
}
