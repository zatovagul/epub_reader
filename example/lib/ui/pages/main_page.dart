import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:epub_reader/epub_reader.dart';

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

  Uint8List? bytes;

  @override
  void initState() {
    super.initState();

    _getBook();
  }

  void _getBook() async {
    bytes = await _loadFromAssets(AppFiles.test2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (bytes == null) return const SizedBox();
    return Scaffold(
      body: SafeArea(
        child: EpubReaderView(
          bytes: bytes!,
        ),
      ),
    );
  }
}
