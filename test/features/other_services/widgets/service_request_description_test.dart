import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_flow.dart';
import 'package:kz_servicos_prestador/features/other_services/presentation/widgets/service_request_description.dart';

const _text =
    'Instalar um candeeiro na sala e trocar duas tomadas. '
    'Pedido de teste: será cancelado.';

/// Quantas linhas o texto realmente desenha (altura / altura de 1 linha).
Future<int> _renderedLines(
  WidgetTester tester,
  String text,
  ProviderServiceAction action,
) async {
  Future<double> heightOf(String value) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: ServiceRequestDescription(text: value, action: action),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.text(value)).size.height;
  }

  final oneLine = await heightOf('A');
  final total = await heightOf(text);
  return (total / oneLine).round();
}

void main() {
  testWidgets('convite por responder desenha o texto do cliente completo', (
    tester,
  ) async {
    final lines = await _renderedLines(
      tester,
      _text,
      ProviderServiceAction.proposePrice,
    );
    expect(lines, greaterThan(2));
    expect(find.textContaining('cancelado'), findsOneWidget);
  });

  testWidgets('proposta já enviada resume o texto em 2 linhas', (tester) async {
    final lines = await _renderedLines(
      tester,
      _text,
      ProviderServiceAction.awaitingAdmin,
    );
    expect(lines, 2);
  });
}
