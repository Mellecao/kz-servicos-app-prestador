import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_flow.dart';

/// Texto do cliente no cartão do pedido: completo num convite por responder,
/// resumido nos restantes estados (ver `requestDescriptionMaxLines`).
class ServiceRequestDescription extends StatelessWidget {
  final String text;
  final ProviderServiceAction action;

  const ServiceRequestDescription({
    super.key,
    required this.text,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final maxLines = requestDescriptionMaxLines(action);
    return Text(
      text,
      maxLines: maxLines,
      // Com `maxLines: null`, `ellipsis` faz o motor desenhar só 1 linha.
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'QuasimodoSemiBold',
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    );
  }
}
