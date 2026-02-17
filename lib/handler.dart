import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

final processedDeliveries = <String>{};

Future<void> handler(HttpRequest req) async {
  final startTime = DateTime.now();

  final method = req.method;
  final signature = req.headers.value('x-hub-signature-256');
  final secret = Platform.environment['GITHUB_WEBHOOK_SECRET'];
  final deliveryId = req.headers.value('x-github-delivery');
  final event = req.headers.value('x-github-event');

  try {
    final bodyBytes =
        await req.fold<List<int>>([], (b, d) => b..addAll(d));

    final hmac = Hmac(sha256, utf8.encode(secret ?? ''));
    final digest = 'sha256=${hmac.convert(bodyBytes)}';

    // 🔐 Signature Validation
    if (secret == null || signature == null || digest != signature) {
      final latency =
          DateTime.now().difference(startTime).inMilliseconds;

      print(jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'event': event,
        'delivery': deliveryId,
        'method': method,
        'status': 'invalid_signature',
        'latency_ms': latency
      }));

      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }

    final payload = jsonDecode(utf8.decode(bodyBytes));

    await handleEvent(event, payload, deliveryId);

    final latency =
        DateTime.now().difference(startTime).inMilliseconds;

    print(jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      'delivery': deliveryId,
      'method': method,
      'status': 'processed',
      'latency_ms': latency
    }));

    req.response.statusCode = 200;
    await req.response.close();
  } catch (e) {
    final latency =
        DateTime.now().difference(startTime).inMilliseconds;

    print(jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      'delivery': deliveryId,
      'method': method,
      'status': 'error',
      'error': e.toString(),
      'latency_ms': latency
    }));

    req.response.statusCode = 500;
    await req.response.close();
  }
}



Future<void> handleEvent(
  String? event,
  Map<String, dynamic> payload,
  String? deliveryId,
) async {

  // 🔁 Idempotency
  if (deliveryId != null && processedDeliveries.contains(deliveryId)) {
    print(jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      'delivery': deliveryId,
      'status': 'duplicate_ignored'
    }));
    return;
  }

  if (deliveryId != null) {
    processedDeliveries.add(deliveryId);
  }

  switch (event) {
    case 'push':
      break;

    case 'pull_request':
      break;

    case 'ping':
      break;

    default:
      break;
  }
} // End of handler.dart