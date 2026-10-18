import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A response that came back with an error status code.
class HttpStatusError implements Exception {
  const HttpStatusError(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'HTTP $statusCode';
}

final http.Client _client = http.Client();

/// GET with one automatic retry for the hiccups food databases often have:
/// timeouts, dropped connections, "too many requests" (429) and server
/// errors (5xx). Returns the response for 2xx and 404; throws otherwise.
Future<http.Response> getWithRetry(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 10),
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < 2; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    try {
      final res = await _client.get(uri, headers: headers).timeout(timeout);
      if (res.statusCode == 429 || res.statusCode >= 500) {
        lastError = HttpStatusError(res.statusCode);
        continue;
      }
      if (res.statusCode >= 200 && res.statusCode < 300 ||
          res.statusCode == 404) {
        return res;
      }
      throw HttpStatusError(res.statusCode);
    } on HttpStatusError {
      rethrow;
    } on TimeoutException catch (e) {
      lastError = e;
    } on SocketException catch (e) {
      lastError = e;
    } on http.ClientException catch (e) {
      lastError = e;
    } on HandshakeException catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('Request failed');
}

/// True when the phone itself seems to be offline (not just a slow server).
bool looksOffline(Object error) {
  final text = error.toString().toLowerCase();
  return error is SocketException &&
          (text.contains('failed host lookup') ||
              text.contains('network is unreachable') ||
              text.contains('no address associated')) ||
      text.contains('failed host lookup');
}

/// A short, honest explanation of what went wrong with one database.
String describeError(Object error, {required String source}) {
  if (looksOffline(error)) return 'No internet connection.';
  if (error is TimeoutException) {
    return '$source is slow right now and didn\'t answer in time.';
  }
  if (error is HttpStatusError) {
    if (error.statusCode == 429) {
      return '$source is limiting searches right now (too many in a row).';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '$source rejected the request (check the API key).';
    }
    if (error.statusCode >= 500) return '$source is having trouble right now.';
  }
  return '$source couldn\'t be reached.';
}
