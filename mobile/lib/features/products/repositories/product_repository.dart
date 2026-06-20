import '../../../core/supabase/api_client.dart';
import '../models/product.dart';

class ProductRepository {
  final _client = supabase;

  Future<List<Product>> getProducts(String branchId) async {
    final response = await _client
        .from('products')
        .select()
        .eq('branch_id', branchId)
        .order('name');
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> searchProducts(String branchId, String query) async {
    final response = await _client
        .from('products')
        .select()
        .eq('branch_id', branchId)
        .or('name.ilike.%$query%,sku.ilike.%$query%,brand.ilike.%$query%')
        .limit(10);
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }

  Future<Product> createProduct({
    required String branchId,
    required String name,
    String? brand,
    String? category,
    required String sku,
    required double sellingPrice,
    double? mrp,
    String? userId,
  }) async {
    final response = await _client.from('products').insert({
      'branch_id': branchId,
      'name': name,
      'brand': brand,
      'category': category,
      'sku': sku,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'gst_rate': 0,
      'created_by': userId,
      'updated_by': userId,
    }).select().single();
    return Product.fromJson(response);
  }

  Future<Product> updateProduct(
    String id, {
    required String name,
    String? brand,
    String? category,
    required String sku,
    required double sellingPrice,
    double? mrp,
    String? userId,
  }) async {
    final response = await _client.from('products').update({
      'name': name,
      'brand': brand,
      'category': category,
      'sku': sku,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'updated_by': userId,
    }).eq('id', id).select().single();
    return Product.fromJson(response);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }
}
