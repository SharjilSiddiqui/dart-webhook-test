import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

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

final processedDeliveries = <String>{};

Future<void> handleEvent(
  String? event,
  Map<String, dynamic> payload,
  String? deliveryId,
) async {
  if (deliveryId != null && processedDeliveries.contains(deliveryId)) {
    print('Duplicate delivery ignored: $deliveryId');
    return;
  }

  if (deliveryId != null) {
    processedDeliveries.add(deliveryId);
  }

  switch (event) {
    case 'push':
      print('Push to ${payload['repository']['full_name']}');
      break;

    case 'pull_request':
      final action = payload['action'];
      print('PR ${payload['number']} $action');
      break;

    default:
      print('Unhandled event: $event');
  }
}

