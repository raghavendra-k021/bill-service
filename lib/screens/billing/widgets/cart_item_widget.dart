import 'package:flutter/material.dart';
import '../../../services/billing_service.dart';
import '../../../utils/formatters.dart';

class CartItemWidget extends StatelessWidget {
  final CartItem item;
  final Function(double) onQuantityChanged;
  final VoidCallback onRemove;

  /// pcs = whole numbers only (+1 / -1); meters, kg, etc. = decimals (+0.25 / -0.25).
  static bool _isWholeUnit(String unit) {
    final u = unit.toLowerCase();
    return u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces';
  }

  static Future<void> _showQuantityDialog(
    BuildContext context,
    double currentQuantity,
    String unit,
    Function(double) onQuantityChanged,
  ) async {
    final isWhole = _isWholeUnit(unit);
    final controller = TextEditingController(
      text: isWhole ? currentQuantity.toInt().toString() : currentQuantity.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit quantity'),
        content: TextField(
          controller: controller,
          keyboardType: isWhole
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: isWhole ? 'e.g. 1, 2, 3' : 'e.g. 1.5, 2.25',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final q = double.tryParse(value.replaceAll(',', '.'));
            if (q != null && q > 0) {
              Navigator.pop(ctx, isWhole ? q.roundToDouble() : q);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final q = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (q != null && q > 0) {
                Navigator.pop(ctx, isWhole ? q.roundToDouble() : q);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      onQuantityChanged(isWhole ? result.roundToDouble() : result);
    }
  }

  const CartItemWidget({
    Key? key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lineAmount = item.unitPrice * item.quantity;
    final discount = lineAmount * (item.discountPercent / 100);
    final total = lineAmount - discount;
    final isWholeUnit = _isWholeUnit(item.unit);
    final step = isWholeUnit ? 1.0 : 0.25;
    final minQty = isWholeUnit ? 1.0 : 0.25;
    final qtyDisplay = isWholeUnit && item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product name and total price row
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  Formatters.formatCurrency(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Price × quantity (pcs: whole; meters/kg: decimals)
            Text(
              '₹${item.unitPrice.toStringAsFixed(2)} × $qtyDisplay ${item.unit}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (discount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discount (${item.discountPercent.toStringAsFixed(0)}%):',
                    style: TextStyle(fontSize: 13, color: Colors.green[700]),
                  ),
                  Text(
                    Formatters.formatCurrency(discount),
                    style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Quantity controls and delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 24,
                      onPressed: () => onQuantityChanged((item.quantity - step).clamp(minQty, double.infinity)),
                      color: Colors.blue,
                    ),
                    GestureDetector(
                      onTap: () => _showQuantityDialog(context, item.quantity, item.unit, onQuantityChanged),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          qtyDisplay,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 24,
                      onPressed: () => onQuantityChanged(item.quantity + step),
                      color: Colors.blue,
                    ),
                  ],
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 24,
                  onPressed: onRemove,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
