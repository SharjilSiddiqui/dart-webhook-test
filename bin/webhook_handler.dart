import 'dart:io';
import 'package:webhook_handler/handler.dart';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 9090);

  print('🚀 Server running on http://localhost:9090');

  await for (HttpRequest request in server) {
    if (request.method == 'POST') {
      await handler(request);
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Only POST allowed');
      await request.response.close();
    }
  }
}
