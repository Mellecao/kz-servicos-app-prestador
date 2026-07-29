import 'package:flutter/material.dart';

class PriceOfferDialog extends StatefulWidget {
  const PriceOfferDialog({super.key});

  @override
  State<PriceOfferDialog> createState() => _PriceOfferDialogState();
}

class _PriceOfferDialogState extends State<PriceOfferDialog> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final raw = _controller.text.replaceAll(',', '.').trim();
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0 || parsed > 10000) {
      setState(() => _error = 'Valor deve ser entre R\$ 0,01 e R\$ 10.000');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proponha o valor da corrida'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              errorText: _error,
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enviar proposta'),
        ),
      ],
    );
  }
}
