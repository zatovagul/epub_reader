import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:epub_reader/epub_reader.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_files.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Future<Uint8List> _loadFromAssets(String assetName) async {
    final bytes = await rootBundle.load(assetName);
    return bytes.buffer.asUint8List();
  }

  File? file;

  @override
  void initState() {
    super.initState();

    _getBook();
  }

  void _getBook() async {
    final bytes = await _loadFromAssets(AppFiles.testBook);
    final buffer = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.length);

    final fileName = AppFiles.test2.split('/').last;
    final file = File('${(await getTemporaryDirectory()).path}/$fileName');

    await file.writeAsBytes(buffer);

    this.file = file;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (file == null) return const SizedBox();
    return Scaffold(
      body: SafeArea(
        child: EpubReaderView(
          file: file!,
        ),
      ),
    );
  }
}
