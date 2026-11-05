import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de marca: impede que o amarelo antigo ou texto branco sobre o
/// laranja primário voltem ao código. Varre `lib/` como texto.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('firebase_options.dart'))
      .toList();

  Map<String, String> sources() => {
    for (final f in dartFiles) f.path: f.readAsStringSync(),
  };

  test('não restam amarelos antigos nem Colors.amber/yellow em lib/', () {
    final forbidden = RegExp(
      r'0xFF(FEBF22|E5AB1E|FFD700|FFA000|F5B800|E8B931|FFE08A|F59E0B|8A6500|FFF7E0)'
      r'|Colors\.(amber|yellow)|hueYellow',
      caseSensitive: false,
    );
    final hits = <String>[];
    sources().forEach((path, text) {
      final lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (forbidden.hasMatch(lines[i])) {
          hits.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    });
    expect(
      hits,
      isEmpty,
      reason: 'Amarelos antigos encontrados:\n${hits.join('\n')}',
    );
  });

  test('nenhum botão usa texto branco sobre AppColors.highlight', () {
    final whiteOnHighlight = RegExp(
      r'backgroundColor:\s*AppColors\.highlight,\s*foregroundColor:\s*(Colors\.white|AppColors\.white)'
      r'|foregroundColor:\s*(Colors\.white|AppColors\.white),\s*backgroundColor:\s*AppColors\.highlight',
    );
    final hits = <String>[];
    sources().forEach((path, text) {
      if (whiteOnHighlight.hasMatch(text)) hits.add(path);
    });
    expect(
      hits,
      isEmpty,
      reason: 'Branco sobre laranja em:\n${hits.join('\n')}',
    );
  });

  test('nenhum texto visível menciona a marca antiga "KZ"', () {
    // Ignora logs (debugPrint/'[KZ…]') e imports do pacote kz_servicos_prestador.
    final kz = RegExp(r'\bKZ\b');
    final hits = <String>[];
    sources().forEach((path, text) {
      final lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!kz.hasMatch(line)) continue;
        if (line.contains('debugPrint') || line.contains('[KZ')) continue;
        hits.add('$path:${i + 1}: ${line.trim()}');
      }
    });
    expect(hits, isEmpty, reason: 'Texto com "KZ":\n${hits.join('\n')}');
  });

  test('raster antigos (logo KZ, amarelo, pessoas) foram removidos', () {
    const removed = [
      'assets/images/bg_login_prestador.png',
      'assets/images/banner.png',
      'assets/images/app_icon_placeholder.png',
    ];
    final stillThere = removed.where((p) => File(p).existsSync()).toList();
    expect(
      stillThere,
      isEmpty,
      reason: 'Ficheiros ainda presentes: $stillThere',
    );

    final referencing = <String>[];
    sources().forEach((path, text) {
      if (removed.any((asset) => text.contains(asset))) referencing.add(path);
    });
    expect(
      referencing,
      isEmpty,
      reason: 'Referências em:\n${referencing.join('\n')}',
    );
  });
}
