import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'cart_screen.dart';

class OrderPendingScreen extends StatelessWidget {
  final String orderNumber;
  final String deliveryAddress;
  final String estimatedDelivery;
  final int total;

  const OrderPendingScreen({
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
                children: <Widget>[
                  Text('Order Pending', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: titleSize, height: 1.1, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                  const SizedBox(height: 50),
                  Container(width: iconSize, height: iconSize,
                    decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                    child: Icon(Icons.access_time, size: iconSize * 0.55, color: C.textPrimary(context))),
                  const SizedBox(height: 30),
                  Text('Your order is being processed', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  const SizedBox(height: AppSpacing.xl - 2),
                  Text('We have received your order and are currently processing your payment. Please do not close the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.7, color: C.textPrimary(context))),
                  const SizedBox(height: 45),
                  Row(children: <Widget>[
                    Expanded(child: Text('Order Number',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                    const SizedBox(width: 15),
                    Flexible(child: Text('#$orderNumber', textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                  ]),
                  const SizedBox(height: 30),
                  Align(alignment: Alignment.centerLeft, child: Text('Delivery to',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.textMuted(context)))),
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: Text(deliveryAddress,
                    style: TextStyle(fontSize: 14, height: 1.5, color: C.textPrimary(context)))),
                  const SizedBox(height: AppSpacing.xxl + 4),
                  Align(alignment: Alignment.centerLeft, child: Text('Estimated delivery',
                    style: TextStyle(fontSize: 14, color: C.textPrimary(context)))),
                  const SizedBox(height: 7),
                  Align(alignment: Alignment.centerLeft, child: Text(estimatedDelivery,
                    style: TextStyle(fontSize: 14, color: C.textPrimary(context)))),
                  const SizedBox(height: AppSpacing.xl - 2),
                  Align(alignment: Alignment.centerLeft, child: Text('Order Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context)))),
                  const SizedBox(height: AppSpacing.sm - 2),
                  Align(alignment: Alignment.centerLeft, child: Text('₦${formatPrice(total)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success, foregroundColor: AppColors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md))),
                      child: Text('BACK TO CHECKOUT',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)))),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false),
                    child: Text('Continue Shopping', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context)))),
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

class OrderFailedScreen extends StatelessWidget {
  final String orderNumber;
  final String deliveryAddress;
  final String estimatedDelivery;
  final int total;

  const OrderFailedScreen({
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
                children: <Widget>[
                  Text('Order Failed', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: titleSize, height: 1.1, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                  const SizedBox(height: 50),
                  Container(width: iconSize, height: iconSize,
                    decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                    child: Icon(Icons.close, size: iconSize * 0.57, color: AppColors.error)),
                  const SizedBox(height: 30),
                  Text("We couldn't complete your order", textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  const SizedBox(height: AppSpacing.xl - 2),
                  Text('Unfortunately, your payment could not be completed. Please try again or choose another payment method.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.7, color: C.textPrimary(context))),
                  const SizedBox(height: 45),
                  Row(children: <Widget>[
                    Expanded(child: Text('Order Number',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                    const SizedBox(width: 15),
                    Flexible(child: Text('#$orderNumber', textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                  ]),
                  const SizedBox(height: 30),
                  Align(alignment: Alignment.centerLeft, child: Text('Delivery to',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.textMuted(context)))),
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: Text(deliveryAddress,
                    style: TextStyle(fontSize: 14, height: 1.5, color: C.textPrimary(context)))),
                  const SizedBox(height: AppSpacing.xxl + 4),
                  Align(alignment: Alignment.centerLeft, child: Text('Estimated delivery',
                    style: TextStyle(fontSize: 14, color: C.textPrimary(context)))),
                  const SizedBox(height: 7),
                  Align(alignment: Alignment.centerLeft, child: Text(estimatedDelivery,
                    style: TextStyle(fontSize: 14, color: C.textPrimary(context)))),
                  const SizedBox(height: AppSpacing.xl - 2),
                  Align(alignment: Alignment.centerLeft, child: Text('Order Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context)))),
                  const SizedBox(height: AppSpacing.sm - 2),
                  Align(alignment: Alignment.centerLeft, child: Text('₦${formatPrice(total)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success, foregroundColor: AppColors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md))),
                      child: Text('TRY AGAIN',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)))),
                  const SizedBox(height: AppSpacing.xxl),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (context) => const CartScreen()), (route) => false),
                    child: Text('Back to Cart', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context)))),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false),
                    child: Text('Continue Shopping', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context)))),
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
