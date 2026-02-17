import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

final processedDeliveries = <String>{};

Future<void> handler(HttpRequest req) async {
  final signature = req.headers.value('x-hub-signature-256');
  final secret = Platform.environment['GITHUB_WEBHOOK_SECRET'];

  if (signature == null || secret == null) {
    req.response
      ..statusCode = HttpStatus.unauthorized
      ..write('Missing signature or secret');
    await req.response.close();
    return;
  }

  final bodyBytes = await req.fold<List<int>>([], (b, d) => b..addAll(d));

  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = 'sha256=${hmac.convert(bodyBytes)}';

  if (digest != signature) {
    req.response
      ..statusCode = HttpStatus.unauthorized
      ..write('Invalid signature');
    await req.response.close();
    return;
  }

  final payload = jsonDecode(utf8.decode(bodyBytes));
  final event = req.headers.value('x-github-event');
  final deliveryId = req.headers.value('x-github-delivery');

  await handleEvent(event, payload, deliveryId);

  req.response.statusCode = 200;
  await req.response.close();
}


Future<void> handleEvent(
  String? event,
  Map<String, dynamic> payload,
  String? deliveryId,
) async {

  // 🔁 Idempotency check — ADD THIS AT THE VERY TOP
  if (deliveryId != null && processedDeliveries.contains(deliveryId)) {
    print(jsonEncode({
      'event': event,
      'delivery': deliveryId,
      'status': 'duplicate_ignored'
    }));
    return;
  }

  if (deliveryId != null) {
    processedDeliveries.add(deliveryId);
  }

  // 🔄 Normal event handling
  switch (event) {
    case 'push':
      print('Push to ${payload['repository']['full_name']}');
      break;

    case 'pull_request':
      final action = payload['action'];
      print('PR ${payload['number']} $action');
      break;

    case 'ping':
      print('Webhook verified');
      break;

    default:
      print('Unhandled event: $event');
  }
}