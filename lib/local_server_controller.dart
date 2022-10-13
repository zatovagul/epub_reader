import 'dart:convert';
import 'dart:io';

import 'logger.dart';

class LocalServerController{
  static final LocalServerController _controller = LocalServerController._internal();
  static LocalServerController get instance => _controller;
  HttpServer? _server;
  factory LocalServerController(){
    return _controller;
  }

  LocalServerController._internal();



  createServer()async{
    /// Создаем сервер
    _server = await HttpServer.bind("localhost", 8012);
    logger.i("SERVER CREATED ${_server?.address.address}");
    await for (var request in _server!) {
      try {
        logger.i(request.uri);
        /// выдаем файл, который запрашивается через js
        final uri = request.uri;
        final file = File(uri.toString());
        request.response
          ..headers.contentType = ContentType.html
          ..headers.add(HttpHeaders.accessControlAllowOriginHeader, "*")
          ..headers.add(HttpHeaders.accessControlAllowHeadersHeader,
              "origin, content-type, accept")
          ..headers.add(HttpHeaders.accessControlAllowMethodsHeader, "*")
          ..write(utf8.decode(await file.readAsBytes()))
          ..close();
      }
      catch(e){
        logger.e(e);
      }
    }
  }

  dispose(){
    _server?.close();
  }
}