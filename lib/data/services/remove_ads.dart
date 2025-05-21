import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../../core/premium_service.dart';

class RemoveAdsScreen extends StatefulWidget {
  const RemoveAdsScreen({Key? key}) : super(key: key);
  @override
  State<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends State<RemoveAdsScreen> {
  final _iap = InAppPurchase.instance;
  final _productId = 'remove_ads';
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  bool _isAvailable = false, _isPurchased = false;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _isPurchased = context.read<PremiumService>().isPremium;
    _initStore();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _initStore() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) return;
    final resp = await _iap.queryProductDetails({_productId});
    if (resp.productDetails.isEmpty) return;
    if (!mounted) return;
    setState(() => _products = resp.productDetails);
  }

  void _onPurchase(List<PurchaseDetails> purchases) {
    if (!mounted) return;
    for (var p in purchases) {
      if (p.status == PurchaseStatus.purchased && p.productID == _productId) {
        context.read<PremiumService>().setPremium(true);
        if (mounted) setState(() => _isPurchased = true);
      }
      if (p.pendingCompletePurchase) _iap.completePurchase(p);
    }
  }

  void _buy() {
    if (_products.isNotEmpty) {
      final product = _products.first;
      final param = PurchaseParam(productDetails: product);
      _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remove Ads')),
      body: Center(
        child: _isPurchased
            ? const Text('✅ Ads Removed', style: TextStyle(fontSize: 20))
            : !_isAvailable
                ? const Text('Store unavailable')
                : _products.isEmpty
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        key: const ValueKey('iap-remove-ads-btn'),
                        onPressed: _buy,
                        icon: const Icon(Icons.payment),
                        label: Text('Buy ${_products.first.price} to Remove Ads'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          side: const BorderSide(width: 1.5),
                        ),
                      ),
      ),
    );
  }
}