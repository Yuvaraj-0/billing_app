import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/services/mongo_service.dart';
import '../models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  static const String authBoxName = 'auth_box';
  static const String currentUserKey = 'current_user_json';
  static const String usersCacheKey = 'users_cache';
  static const String _salt = 'mk_star_studio_salt_2026';

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password + _salt);
    return sha256.convert(bytes).toString();
  }

  /// Initialize auth status from local cache on app launch
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = await Hive.openBox(authBoxName);
      final userJson = box.get(currentUserKey);

      if (userJson != null && userJson is String && userJson.isNotEmpty) {
        _currentUser = UserModel.fromJson(userJson);
        debugPrint('[AuthViewModel] Restored logged-in user: ${_currentUser!.email}');
      }
    } catch (e) {
      debugPrint('[AuthViewModel] Error reading cached auth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign up a new user
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String shopName,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    final cleanName = name.trim();
    final cleanShop = shopName.trim().isEmpty ? 'MK Star' : shopName.trim();

    if (cleanName.isEmpty) {
      _errorMessage = 'Please enter your name';
      notifyListeners();
      return false;
    }

    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      _errorMessage = 'Please enter a valid email address';
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final passwordHash = _hashPassword(password);
      final user = UserModel(
        id: const Uuid().v4(),
        email: cleanEmail,
        name: cleanName,
        shopName: cleanShop,
        passwordHash: passwordHash,
        createdAt: DateTime.now(),
      );

      final box = await Hive.openBox(authBoxName);

      // Check local cache for duplicate email
      final Map<dynamic, dynamic> cache =
          Map<dynamic, dynamic>.from(box.get(usersCacheKey, defaultValue: {}) as Map);
      if (cache.containsKey(cleanEmail)) {
        _errorMessage = 'An account with this email already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Try registering in MongoDB Atlas
      final registeredInMongo = await MongoService.instance.registerUser(user);
      if (!registeredInMongo && MongoService.instance.isConnected) {
        _errorMessage = MongoService.instance.lastError ?? 'Failed to register user in cloud';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Save user to local cache for offline authentication
      cache[cleanEmail] = user.toJson();
      await box.put(usersCacheKey, cache);

      // Set active session
      await box.put(currentUserKey, user.toJson());
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log in an existing user
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();

    if (cleanEmail.isEmpty) {
      _errorMessage = 'Please enter your email';
      notifyListeners();
      return false;
    }

    if (password.isEmpty) {
      _errorMessage = 'Please enter your password';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final expectedHash = _hashPassword(password);
      UserModel? user;

      // 1. Try finding in MongoDB Atlas
      if (MongoService.instance.isConnected) {
        user = await MongoService.instance.findUserByEmail(cleanEmail);
      }

      final box = await Hive.openBox(authBoxName);
      final Map<dynamic, dynamic> cache =
          Map<dynamic, dynamic>.from(box.get(usersCacheKey, defaultValue: {}) as Map);

      // 2. Fall back to local cache if offline or not found
      if (user == null && cache.containsKey(cleanEmail)) {
        user = UserModel.fromJson(cache[cleanEmail] as String);
      }

      if (user == null) {
        _errorMessage = 'No user found with this email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Verify password
      if (user.passwordHash != expectedHash) {
        _errorMessage = 'Incorrect password. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Update local cache
      cache[cleanEmail] = user.toJson();
      await box.put(usersCacheKey, cache);

      // Save active session
      await box.put(currentUserKey, user.toJson());
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log out current user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = await Hive.openBox(authBoxName);
      await box.delete(currentUserKey);
      _currentUser = null;
    } catch (e) {
      debugPrint('[AuthViewModel] Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

