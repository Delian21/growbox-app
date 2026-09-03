import 'package:flutter/material.dart';
import '../theme.dart';
import 'order_history_screen.dart';
import 'delivery_tracking_screen.dart';
import 'home_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderNumber;
  final String deliveryAddress;
  final String estimatedDelivery;
  final int total;

  const OrderSuccessScreen({
    super.key,
    this.orderNumber = 'GBX-10482',
    this.deliveryAddress = 'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria',
    this.estimatedDelivery = 'Today, 2:00 PM – 4:00 PM',
    this.total = 26000,
  });


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : screenWidth < 600 ? 22.0 : 40.0;
    final titleSize = screenWidth < 360 ? 28.0 : screenWidth < 600 ? 32.0 : 36.0;
    final iconSize = screenWidth < 360 ? 74.0 : 84.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 35),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Text('Order Confirmed', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: titleSize, height: 1.1, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                  const SizedBox(height: 50),
                  Container(
                    width: iconSize, height: iconSize,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: iconSize * 0.57, color: C.textPrimary(context))),
                  const SizedBox(height: 30),
                  Text('Order placed successfully!', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  const SizedBox(height: AppSpacing.huge),
                  Text("Thank you for your order. We've received it and will begin processing it shortly.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.7, color: C.textPrimary(context))),
                  const SizedBox(height: 40),
                  // Order Number card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Number',
                          style: TextStyle(fontSize: 14, color: C.textMuted(context))),
                        Text('#$orderNumber',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Delivery info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivery to',
                          style: TextStyle(fontSize: 12, color: C.textMuted(context))),
                        const SizedBox(height: 4),
                        Text(deliveryAddress,
                          style: TextStyle(fontSize: 14, height: 1.4, color: C.textPrimary(context))),
                        const SizedBox(height: 16),
                        Text('Estimated delivery',
                          style: TextStyle(fontSize: 12, color: C.textMuted(context))),
                        const SizedBox(height: 4),
                        Text(estimatedDelivery,
                          style: TextStyle(fontSize: 14, color: C.textPrimary(context))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Order Total card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Total',
                          style: TextStyle(fontSize: 14, color: C.textMuted(context))),
                        Text('₦${formatPrice(total)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Track Delivery button
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => DeliveryTrackingScreen(
                          orderNumber: '10482',
                          estimatedDelivery: estimatedDelivery))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark, foregroundColor: AppColors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.local_shipping_outlined, size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Text('TRACK DELIVERY',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Box History button
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => OrderHistoryScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success, foregroundColor: AppColors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md))),
                      child: Text('BOX HISTORY',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false),
                    child: Text('Continue Shopping', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
