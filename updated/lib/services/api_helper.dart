import 'dart:convert';
import 'package:http/http.dart' as http;
import 'navigation_service.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  
  ApiException(this.message, {this.statusCode});
  
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message, {super.statusCode});
}

class ApiHelper {
  static final NavigationService _navigationService = NavigationService();
  static final AuthService _authService = AuthService();

  /// Handle API response and check for errors
  static Future<dynamic> handleResponse(http.Response response, {bool retry = true}) async {
    switch (response.statusCode) {
      case 200:
      case 201:
        return jsonDecode(response.body);
        
      case 401:
      case 403:
        // Unauthorized - try to refresh token
        if (retry) {
          final refreshed = await _authService.refreshAccessToken();
          if (refreshed) {
            // Token refreshed successfully, caller should retry
            return null;
          }
        }
        
        // Refresh failed or retry disabled - logout and redirect
        await _authService.logout();
        _navigationService.navigateToAndRemoveUntil('/login');
        throw UnauthorizedException(
          'Session expired. Please login again.',
          statusCode: response.statusCode,
        );
        
      case 400:
        final error = jsonDecode(response.body);
        throw ApiException(error['error'] ?? 'Bad request', statusCode: 400);
        
      case 404:
        throw ApiException('Resource not found', statusCode: 404);
        
      case 500:
        throw ApiException('Server error. Please try again later.', statusCode: 500);
        
      default:
        throw ApiException(
          'Unexpected error occurred (${response.statusCode})',
          statusCode: response.statusCode,
        );
    }
  }

  /// Make a GET request with automatic error handling
  static Future<dynamic> get(String url, {required Map<String, String> headers}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      final result = await handleResponse(response);
      
      // If null returned, token was refreshed - caller should retry
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Make a POST request with automatic error handling
  static Future<dynamic> post(
    String url, {
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      return await handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Make a PUT request with automatic error handling
  static Future<dynamic> put(
    String url, {
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      return await handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Make a DELETE request with automatic error handling
  static Future<dynamic> delete(
    String url, {
    required Map<String, String> headers,
  }) async {
    try {
      final response = await http.delete(Uri.parse(url), headers: headers);
      return await handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }
}
