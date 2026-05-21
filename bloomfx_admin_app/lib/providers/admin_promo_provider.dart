import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../models/admin_models.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminPromoProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<PromoCode> _promos = [];
  List<PromoRedemption> _redemptions = [];
  bool _isLoading = false;
  String? _errorMessage;

  AdminPromoProvider({required String baseUrl})
      : _apiService = ApiService(baseUrl: baseUrl);

  List<PromoCode> get promos => _promos;
  List<PromoRedemption> get redemptions => _redemptions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get _useLocalOnly => _apiService.baseUrl.contains('your-backend-api.com') || _apiService.baseUrl.contains('10.0.2.2') || _apiService.baseUrl.contains('127.0.0.1') || _apiService.baseUrl.contains('localhost');

  Future<void> loadPromos() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.getAdminPromos().timeout(const Duration(seconds: 15));
      if (res.success && res.data != null) {
        final Map<String, dynamic> d = res.data!;
        final List<Map<String, dynamic>> promosList = [];
        final List<Map<String, dynamic>> redsList = [];
        if (d['promos'] is List) {
          for (final e in (d['promos'] as List)) {
            promosList.add(Map<String, dynamic>.from(e as Map));
          }
        }
        if (d['redemptions'] is List) {
          for (final e in (d['redemptions'] as List)) {
            redsList.add(Map<String, dynamic>.from(e as Map));
          }
        }
        _promos = promosList.map((p) => PromoCode.fromJson(p)).toList();
        _redemptions = redsList.map((r) => PromoRedemption.fromJson(r)).toList();
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (!_useLocalOnly) {
        _errorMessage = res.message.isNotEmpty ? res.message : 'Cannot reach server';
      }
    } catch (e) {
      if (_useLocalOnly) {
        _promos = _createMockPromos();
        _redemptions = _createMockRedemptions();
      } else {
        _errorMessage = 'Failed to load promos: $e';
      }
    }

    if (_useLocalOnly) {
      await Future.delayed(const Duration(milliseconds: 300));
      _promos = _createMockPromos();
      _redemptions = _createMockRedemptions();
    }

    _isLoading = false;
    notifyListeners();
  }

  List<PromoCode> _createMockPromos() {
    final now = DateTime.now();
    return [
      PromoCode(id: 'p1', code: 'WELCOME50', minDeposit: 100, maxBonus: 50, expiresAt: now.add(const Duration(days: 30)), usageLimit: 100, usedCount: 23, isActive: true, createdAt: now.subtract(const Duration(days: 10))),
      PromoCode(id: 'p2', code: 'BLOOM100', minDeposit: 200, maxBonus: 100, expiresAt: now.add(const Duration(days: 60)), usageLimit: 50, usedCount: 12, isActive: true, createdAt: now.subtract(const Duration(days: 5))),
      PromoCode(id: 'p3', code: 'EXPIRED20', minDeposit: 50, maxBonus: 20, expiresAt: now.subtract(const Duration(days: 5)), usageLimit: 200, usedCount: 45, isActive: false, createdAt: now.subtract(const Duration(days: 90))),
      PromoCode(id: 'p4', code: 'VIP500', minDeposit: 1000, maxBonus: 500, usageLimit: 10, usedCount: 3, isActive: true, createdAt: now.subtract(const Duration(days: 2))),
    ];
  }

  List<PromoRedemption> _createMockRedemptions() {
    final now = DateTime.now();
    return [
      PromoRedemption(id: 'r1', userId: '1', userName: 'John Doe', promoCode: 'WELCOME50', bonusAmount: 50, createdAt: now.subtract(const Duration(days: 8))),
      PromoRedemption(id: 'r2', userId: '2', userName: 'Jane Smith', promoCode: 'BLOOM100', bonusAmount: 100, createdAt: now.subtract(const Duration(days: 3))),
      PromoRedemption(id: 'r3', userId: '4', userName: 'Alice Brown', promoCode: 'WELCOME50', bonusAmount: 50, createdAt: now.subtract(const Duration(days: 1))),
    ];
  }

  Future<bool> createPromo(String code, double minDeposit, double maxBonus, int usageLimit, DateTime? expiresAt) async {
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.createPromo({
        'code': code.toUpperCase(),
        'bonusMin': minDeposit,
        'bonusMax': maxBonus,
        'usageLimit': usageLimit,
        if (expiresAt != null) 'expiration': expiresAt.toIso8601String(),
      }).timeout(const Duration(seconds: 15));
      if (res.success) {
        await loadPromos();
        _showToast('Promo code created', Colors.green);
        return true;
      }
      _showToast(res.message, Colors.red);
      return false;
    } catch (e) {
      _showToast('Failed to create promo', Colors.red);
      return false;
    }
  }

  Future<void> togglePromo(String promoId, bool isActive) async {
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.togglePromo(promoId, isActive: isActive).timeout(const Duration(seconds: 15));
      if (res.success) {
        await loadPromos();
        _showToast(isActive ? 'Promo enabled' : 'Promo disabled', Colors.green);
      } else {
        _showToast(res.message, Colors.red);
      }
    } catch (e) {
      _showToast('Failed to toggle promo', Colors.red);
    }
    notifyListeners();
  }

  void _showToast(String msg, Color bg) {
    Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, backgroundColor: bg, textColor: Colors.white);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
