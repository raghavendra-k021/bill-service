import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'price_utils.dart';

/// Shop code resolution and net price helpers for product labels.
/// Signed QR build/parse retained for legacy; labels and billing use CODE128 barcode.
class LabelQrData {
  final String shopCode;
  final String barcode;
  final double mrp;
  final double discPercent;
  final double netPrice;

  const LabelQrData({
    required this.shopCode,
    required this.barcode,
    required this.mrp,
    required this.discPercent,
    required this.netPrice,
  });
}

class LabelQrCodec {
  LabelQrCodec._();

  static const defaultShopCode = 'SRT';
  static const _prefShopCode = 'label_shop_code';
  static const _signSecretSuffix = '|label-v1';

  static Future<String> resolveShopCode(AppDatabase? database) async {
    try {
      if (database != null) {
        final settings =
            await database.select(database.shopSettings).getSingleOrNull();
        final code = settings?.shopCode?.trim();
        if (code != null && code.isNotEmpty) {
          return code.toUpperCase();
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_prefShopCode)?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      return legacy.toUpperCase();
    }
    return defaultShopCode;
  }

  static Future<void> clearLegacyShopCodePref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefShopCode);
  }

  static double netPriceFrom(double mrp, double discPercent) =>
      PriceUtils.netAfterDiscount(mrp, discPercent);

  static String buildPayload({
    required String shopCode,
    required String barcode,
    required double mrp,
    required double discPercent,
    required double netPrice,
  }) {
    final code = shopCode.trim().toUpperCase();
    final bc = barcode.trim();
    if (code.isEmpty) {
      throw ArgumentError('Shop code is required');
    }
    if (bc.isEmpty) {
      throw ArgumentError('Barcode is required');
    }

    final core = [
      'SC:$code',
      'BC:$bc',
      'MRP:${PriceUtils.roundRupee(mrp).toStringAsFixed(2)}',
      'DIS:${discPercent.toStringAsFixed(1)}',
      'NET:${PriceUtils.roundRupee(netPrice).toStringAsFixed(2)}',
    ].join('|');

    final sig = _sign(core, code);
    return '$core|SIG:$sig';
  }

  static LabelQrData? parse(String raw, {String? expectedShopCode}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.contains('|')) {
      return null;
    }

    final fields = <String, String>{};
    for (final part in trimmed.split('|')) {
      final idx = part.indexOf(':');
      if (idx <= 0) continue;
      fields[part.substring(0, idx).toUpperCase()] = part.substring(idx + 1);
    }

    final shopCode = fields['SC']?.trim().toUpperCase();
    final barcode = fields['BC']?.trim();
    final sig = fields['SIG']?.trim().toUpperCase();
    if (shopCode == null ||
        shopCode.isEmpty ||
        barcode == null ||
        barcode.isEmpty ||
        sig == null ||
        sig.isEmpty) {
      return null;
    }

    if (expectedShopCode != null &&
        shopCode != expectedShopCode.trim().toUpperCase()) {
      return null;
    }

    final mrp = double.tryParse(fields['MRP'] ?? '');
    final disc = double.tryParse(fields['DIS'] ?? '');
    final net = double.tryParse(fields['NET'] ?? '');
    if (mrp == null || disc == null || net == null) {
      return null;
    }

    final core = [
      'SC:$shopCode',
      'BC:$barcode',
      'MRP:${PriceUtils.roundRupee(mrp).toStringAsFixed(2)}',
      'DIS:${disc.toStringAsFixed(1)}',
      'NET:${PriceUtils.roundRupee(net).toStringAsFixed(2)}',
    ].join('|');

    if (_sign(core, shopCode) != sig) {
      return null;
    }

    return LabelQrData(
      shopCode: shopCode,
      barcode: barcode,
      mrp: mrp,
      discPercent: disc,
      netPrice: net,
    );
  }

  static bool looksLikeLabelQr(String raw) {
    final upper = raw.trim().toUpperCase();
    return upper.startsWith('SC:') &&
        upper.contains('|BC:') &&
        upper.contains('|SIG:');
  }

  static String _sign(String core, String shopCode) {
    final key = utf8.encode(
      'BillService|${shopCode.toUpperCase()}$_signSecretSuffix',
    );
    final digest = Hmac(sha256, key).convert(utf8.encode(core));
    return digest.toString().substring(0, 8).toUpperCase();
  }
}
