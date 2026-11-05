import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de localização: impede que vocabulário, moeda, telefone ou
/// geografia do Brasil voltem ao código visível do app (pt-AO / Luanda).
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('firebase_options.dart'))
      // nomes antigos de categorias são mantidos de propósito como alias
      .where((f) => !f.path.endsWith('category_colors.dart'))
      .toList();

  // Termos do Brasil (palavras inteiras) -> alternativa pt-AO.
  const words = <String, String>{
    'corrida': 'viagem',
    'corridas': 'viagens',
    'celular': 'telemóvel',
    'usuário': 'utilizador',
    'senha': 'palavra-passe',
    'Sair': 'Terminar sessão',
    'você': 'tratamento neutro',
    'Aguardando': 'A aguardar',
    'aguardando': 'a aguardar',
    'Buscando': 'À procura de',
    'Enviando': 'A enviar',
    'cadastro': 'registo',
    'Excluir': 'Eliminar',
    'equipe': 'equipa / Só Serviços',
    'Faturamento': 'Faturação',
    'Dinheiro': 'Numerário',
    'Placa': 'Matrícula',
    'Em andamento': 'Em curso',
    'PIX': 'IBAN / Transferência',
    'CPF': 'BI / NIF',
    'CNH': 'Carta de condução',
  };
  final patterns = <String, RegExp>{
    for (final e in words.entries)
      e.key: RegExp('(?<![A-Za-zÀ-ÿ])${RegExp.escape(e.key)}(?![A-Za-zÀ-ÿ])'),
    r'R$ (Real)': RegExp(r'R\?\$'),
    '+55 / (11) (telefone BR)': RegExp(r'\+55|\(\d{2}\)\s?\d{4,5}-\d{4}'),
    'São Paulo': RegExp('São Paulo|Sao Paulo'),
    'pt-BR': RegExp(r"pt-BR|pt_BR|Locale\('pt', 'BR'\)"),
  };

  test('nenhum texto visível usa vocabulário, moeda ou telefone do Brasil', () {
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue; // comentários
        if (line.contains('debugPrint')) continue; // logs
        for (final e in patterns.entries) {
          if (e.value.hasMatch(line)) {
            hits.add('${f.path}:${i + 1} [${e.key}] ${line.trim()}');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: 'Termos do Brasil:\n${hits.join('\n')}');
  });
}
