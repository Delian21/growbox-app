import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/animated_entrance.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
    const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String selectedFilter = 'All';

  // Order history is sourced from the persisted store: mock seeds on first
  // launch (resolved from the canonical catalog by name) + real orders
  // recorded at checkout.
  List<Map<String, dynamic>> get orderHistory =>
      storedOrders.map(_orderToCard).toList();

  static Map<String, dynamic> _orderToCard(StoredOrder o) => {
        'orderNumber': '#${o.orderNumber}',
        'amount': '₦${formatPrice(o.total)}',
        'items': '${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
        'date': _formatDate(o.placedAt),
        'status': o.status,
        'statusColor': _statusColor(o.status),
        'category': o.category,
        'paymentStatus': o.paymentStatus,
        'products': o.items
            .map((i) => VendorProduct(
                  image: i.image,
                  name: i.name,
                  description: i.name,
                  price: i.price,
                  category: i.category,
                  vendorName: i.vendorName,
                ))
            .toList(),
        'quantities': o.items.map((i) => i.quantity).toList(),
        'stored': o,
      };

  static Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.error;
      case 'Pending':
        return AppColors.warning;
      default: // 'Order placed'
        return AppColors.success;
    }
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  void _reorderItems(List<VendorProduct> products, List<int> quantities) {
    int added = 0;
    int skipped = 0;
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final qty = quantities[i];
      for (int j = 0; j < qty; j++) {
        if (StockTracker.isAvailable(product.vendorName, product.name)) {
          StockTracker.decrement(product.vendorName, product.name);
          context.read<CartNotifier>().add(product);
          added++;
        } else {
          skipped++;
        }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (skipped == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$added item${added == 1 ? '' : 's'} added to your box'),
          backgroundColor: AppColors.primaryDark,
          duration:   Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm))));
    } else if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:   Text('All items are out of stock'),
          backgroundColor: AppColors.error,
          duration:   Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$added added, $skipped out of stock'),
          backgroundColor: AppColors.warning,
          duration:   Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm))));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);
    final filteredOrders = selectedFilter == 'All'
        ? orderHistory
        : orderHistory
            .where((order) => order['category'] == selectedFilter)
            .toList();

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:   Icon(Icons.arrow_back,
                        size: 24, color: C.textPrimary(context)),
                  ),
                    Expanded(
                    child: Center(
                      child: Text(
                        'Order History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                    SizedBox(width: 24),
                ],
              ),
            ),

              SizedBox(height: AppSpacing.lg),

            // ── Filter Tabs ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hp),
              child: Container(
                padding:   EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: C.surfaceLight(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _FilterTab(
                        title: 'All',
                        selected: selectedFilter == 'All',
                        onTap: () =>
                            setState(() => selectedFilter = 'All')),
                    _FilterTab(
                        title: 'Active',
                        selected: selectedFilter == 'Active',
                        onTap: () =>
                            setState(() => selectedFilter = 'Active')),
                    _FilterTab(
                        title: 'Completed',
                        selected: selectedFilter == 'Completed',
                        onTap: () =>
                            setState(() => selectedFilter = 'Completed')),
                    _FilterTab(
                        title: 'Cancelled',
                        selected: selectedFilter == 'Cancelled',
                        onTap: () =>
                            setState(() => selectedFilter = 'Cancelled')),
                  ],
                ),
              ),
            ),

              SizedBox(height: AppSpacing.lg),

            // ── Orders List ─────────────────────────────────────
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: AppColors.grey400),
                            SizedBox(height: AppSpacing.md),
                          Text(
                            'No orders found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: C.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics:   BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 30),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return AnimatedEntrance(index: index, child: _OrderCard(
                          orderNumber: order['orderNumber'],
                          amount: order['amount'],
                          items: order['items'],
                          date: order['date'],
                          status: order['status'],
                          statusColor: order['statusColor'],
                          onViewOrder: () {
                            final stored =
                                order['stored'] as StoredOrder;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => OrderDetailsScreen(
                                        orderNumber:
                                            order['orderNumber'] as String,
                                        date: order['date'] as String,
                                        status: order['status'] as String,
                                        statusColor:
                                            order['statusColor'] as Color,
                                        paymentStatus: order['paymentStatus']
                                            as String,
                                        deliveryAddress:
                                            stored.deliveryAddress.isEmpty
                                                ? 'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria'
                                                : stored.deliveryAddress,
                                        subtotal: stored.subtotal,
                                        deliveryFee: stored.deliveryFee,
                                        total: stored.total,
                                        products: stored.items,
                                      )),
                            );
                          },
                          onReorder: order['status'] != 'Cancelled'
                              ? () => _reorderItems(
                                  List<VendorProduct>.from(
                                      order['products']),
                                  List<int>.from(order['quantities']))
                              : null,
                        ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FILTER TAB
// ═══════════════════════════════════════════════════════════════════════

class _FilterTab extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

    const _FilterTab(
      {required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration:   Duration(milliseconds: 200),
          padding:   EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? C.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset:   Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? C.textPrimary(context) : AppColors.grey600,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ORDER CARD
// ═══════════════════════════════════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  final String orderNumber;
  final String amount;
  final String items;
  final String date;
  final String status;
  final Color statusColor;
  final VoidCallback onViewOrder;
  final VoidCallback? onReorder;

    const _OrderCard({
    required this.orderNumber,
    required this.amount,
    required this.items,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.onViewOrder,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:   EdgeInsets.only(bottom: AppSpacing.md),
      padding:   EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset:   Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  orderNumber,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
            SizedBox(height: 10),
          // Details row
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 14, color: C.textMuted(context)),
                SizedBox(width: 6),
              Text(
                items,
                style:
                    TextStyle(fontSize: 13, color: C.textMuted(context)),
              ),
                SizedBox(width: 12),
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: C.textMuted(context)),
                SizedBox(width: 6),
              Text(
                date,
                style:
                    TextStyle(fontSize: 13, color: C.textMuted(context)),
              ),
                Spacer(),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
            ],
          ),
            SizedBox(height: 12),
          // Actions
          Row(
            children: [
              GestureDetector(
                onTap: onViewOrder,
                child: Container(
                  padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:   Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
              if (onReorder != null) ...[
                  SizedBox(width: 8),
                GestureDetector(
                  onTap: onReorder,
                  child: Container(
                    padding:   EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: C.surfaceLight(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.replay,
                            size: 14, color: AppColors.primaryDark),
                          SizedBox(width: 4),
                        Text(
                          'Reorder',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
