import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'local_server_controller.dart';
import 'logger.dart';

class EpubReaderView extends StatefulWidget {
  final Uint8List bytes;
  const EpubReaderView({
    Key? key,
    required this.bytes,
  }) : super(key: key);

  @override
  _EpubReaderViewState createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends State<EpubReaderView> {
  Future<Uint8List> _loadFromAssets(String assetName) async {
    final bytes = await rootBundle.load(assetName);
    return bytes.buffer.asUint8List();
  }

  EpubBookRef? _epubBookRef;

  @override
  void initState() {
    _getBook();
    super.initState();
    LocalServerController.instance.createServer();
    LocalServerController.instance.dispose();

    // final readBookState = context.findAncestorStateOfType<ReadBookScreenState>();
    // if(readBookState != null){
    //   /// Выставляем колбэк на изменение размера текста
    //   readBookState.onChangeSize = (increase){
    //     _webViewController.runJavascript("changeSize($increase, 1.2)");
    //   };
    //   /// Выставляем колбэк на изменение темы
    //   readBookState.onSwitchTheme = (){
    //     _webViewController.runJavascript("switchTheme()");
    //   };
    //   /// Выставляем колбэк на изменения Vertical/Horizontal
    //   readBookState.onSwitchView = (){
    //     _webViewController.runJavascript("switchView()");
    //   };
    // }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Открываем книгу
  _getBook() async {
    _epubBookRef = await EpubReader.openBook(widget.bytes);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_epubBookRef != null) {
      return Stack(
        children: [
          _getWebView(),
        ],
      );
    }

    return const SizedBox();
  }

  late WebViewController _webViewController;
  _onControllerCreated(WebViewController controller) async {
    _webViewController = controller;

    /// Получаем пути на все html файлы внутри архива
    var paths = await _extractFile();
    paths = paths.map((e) => "http://localhost:8012$e").toList();
    logger.i(paths);

    final pathsScript = "const paths = ${jsonEncode(paths)};";
    logger.i(pathsScript);

    /// Создаем html файл в котором будем управлять книгой
    final html = """
        <html>
          <head>
          <script>
            $pathsScript
          </script>
            ${await _getHeadString()}
          </head>
          <body>
            ${await _getJsString()}
          </body>
        </html>
        """;
    // logger.i(html);
    Directory directory = await getApplicationDocumentsDirectory();
    File file = File("${directory.path}/js/index.html");
    await file.writeAsString(html);
    logger.i(file.path);
    await _webViewController.loadFile(file.path);
  }

  Future<List<String>> _extractFile() async {
    final directoryPath =
        "${(await getApplicationDocumentsDirectory()).path}/AppBook";
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create();
    }

    List<String> paths = [];
    for (var key in _epubBookRef!.Content!.AllFiles!.keys) {
      final value = _epubBookRef!.Content!.AllFiles![key]!;
      logger.i("$key $value ${value.getContentFileEntry()}");

      final a = value.getContentFileEntry().content;
      final path = "$directoryPath/$key";
      logger.i(path);

      final splittedPath = path.substring(0, path.lastIndexOf("/"));
      if (kDebugMode) {
        logger.i(splittedPath);
      }
      final dir = Directory(splittedPath);
      if (!await dir.exists()) {
        await dir.create();
      }
      logger.i("CREATED");
      final file = File(path);
      if (path.endsWith("html")) {
        /// Добавляем в массив только html файлы
        paths.add(path);
        var sss = String.fromCharCodes(a);
        sss = sss.substring(sss.indexOf("<html"), sss.length);
        final dir = path.replaceFirst(path.split("/").last, "");

        /// Заменяем пути в коде, на реальные пути в устройстве
        sss = replaceFilePaths(sss, dir);

        await file.writeAsString(sss);
        // await file.writeAsBytes(a);
      } else {
        await file.writeAsBytes(a);
      }
    }

    return paths;
  }

  String replaceFilePaths(String sss, String dir) {
    int i = 0;
    while (i < sss.length) {
      var text = sss.substring(i, sss.length);
      var srcIndex = text.indexOf("src");
      var hrefIndex = text.indexOf("href");
      bool? isSrc;
      if (srcIndex >= 0 && (srcIndex < hrefIndex || hrefIndex < 0)) {
        isSrc = true;
      }
      if (hrefIndex >= 0 && (hrefIndex < srcIndex || srcIndex < 0)) {
        isSrc = false;
      }

      if (isSrc ?? false) {
        if (!text.substring(srcIndex, srcIndex + 10).contains("http")) {
          sss = sss.substring(0, i) +
              text.substring(0, srcIndex + 5) +
              dir +
              text.substring(srcIndex + 5, text.length);
        }
      }
      if (!(isSrc ?? true)) {
        if (!text.substring(hrefIndex, hrefIndex + 11).contains("http")) {
          sss = sss.substring(0, i) +
              text.substring(0, hrefIndex + 6) +
              dir +
              text.substring(hrefIndex + 6, text.length);
        }
      }
      if (isSrc != null && isSrc) {
        i = sss.substring(0, i).length + srcIndex + 1;
      } else if (isSrc != null && !isSrc) {
        i = sss.substring(0, i).length + hrefIndex + 1;
      } else {
        break;
      }
    }
    return sss;
  }

  Widget _getWebView() {
    return SafeArea(
      bottom: true,
      top: false,
      child: WebView(
        backgroundColor: Colors.transparent,
        initialUrl: "about:blank",
        onWebViewCreated: (c) {
          _onControllerCreated(c);
        },
        javascriptMode: JavascriptMode.unrestricted,
        javascriptChannels: {
          /// Слушаем метод Print.postMessage(...) внутри js
          JavascriptChannel(
              name: "Print",
              onMessageReceived: (message) {
                logger.i("Message console ${message.message}");
              })
        },
      ),
    );
  }

  /// Выдаем скрипт
  Future<String> _getJsString() async {
    final jsPath = await _getJsPath();
    logger.i("PATH $jsPath");

    final script = "<script src=\"$jsPath\"></script>";
    logger.i(script);
    return script;
  }

  /// Выдаем путь на Js
  Future<String> _getJsPath() async {
    final file = await _loadFromAssets("packages/epub_reader/js/slide.js");

    Directory directory = await getApplicationDocumentsDirectory();
    final dir = Directory("${directory.path}/js");
    if (!await dir.exists()) {
      await dir.create();
    }
    final bytes = file.buffer.asUint8List(file.offsetInBytes, file.length);

    final path = p.join(dir.path, "slide.js");
    await File(path).writeAsBytes(bytes);

    return path;
  }

  /// Выдаем Элементы для <head>
  Future<String> _getHeadString() async {
    return """
    <!-- <meta charset="UTF-8" /> 
    <meta http-equiv="X-UA-Compatible" content="IE=edge" /> -->
    <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1"/>
    
    <script defer src="https://unpkg.com/smoothscroll-polyfill@0.4.4/dist/smoothscroll.min.js"></script>
    
    <link rel="stylesheet" href="${(await _getCssPath())}"/>
    """;
  }

  /// Выдаем путь на css
  Future<String> _getCssPath() async {
    // final file = File("packages/epub_reader/js/styles.css");
    final file = await _loadFromAssets("packages/epub_reader/js/styles.css");

    Directory directory = await getApplicationDocumentsDirectory();
    final dir = Directory("${directory.path}/css");
    if (!await dir.exists()) {
      await dir.create();
    }
    // final bytes = await file.readAsBytes();
    final bytes = file.buffer.asUint8List(file.offsetInBytes, file.length);

    final path = p.join(dir.path, "styles.css");
    await File(path).writeAsBytes(bytes);

    return path;
  }
}
