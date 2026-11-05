import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/category_colors.dart';
import 'package:kz_servicos_prestador/core/constants/feature_flags.dart';
import 'package:kz_servicos_prestador/core/models/service_request_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/service_request_service.dart';
import 'package:kz_servicos_prestador/core/widgets/service_provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/features/benefits/presentation/widgets/benefits_banner.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_flow.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_realtime_reload_policy.dart';

class ServiceRequestsPage extends StatefulWidget {
  final ValueChanged<int> onNavTap;

  const ServiceRequestsPage({super.key, required this.onNavTap});

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  final _service = ServiceRequestService();
  String _filter = 'Todos';
  bool _loading = true;
  String? _error;
  List<ServiceRequestData> _requests = [];
  final Set<String> _busyIds = {};
  Set<String> _providerCategoryIds = {};
  RealtimeChannel? _serviceRequestsChannel;
  RealtimeChannel? _candidatesChannel;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (mounted) _subscribeToServiceRequests();
    });
  }

  @override
  void dispose() {
    _serviceRequestsChannel?.unsubscribe();
    _candidatesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final providerId = AuthState.providerProfileId ?? '';
    try {
      final result = await _service.getProviderRequests(providerId);
      final categoryIds = await _service.getProviderCategoryIds(providerId);
      if (!mounted) return;
      setState(() {
        _requests = result;
        _providerCategoryIds = categoryIds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os serviços.';
        _loading = false;
      });
    }
  }

  void _subscribeToServiceRequests() {
    final providerId = AuthState.providerProfileId;
    if (providerId == null || providerId.isEmpty) return;
    final client = Supabase.instance.client;
    _serviceRequestsChannel?.unsubscribe();
    _serviceRequestsChannel = client
        .channel('provider-service-requests-$providerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) {
            if (ServiceRequestRealtimeReloadPolicy.changeTargetsProvider(
              providerProfileId: providerId,
              providerCategoryIds: _providerCategoryIds,
              newRecord: payload.newRecord,
              oldRecord: payload.oldRecord,
            )) {
              _load();
            }
          },
        )
        .subscribe();

    // Novos convites e decisões do administrador chegam por aqui.
    _candidatesChannel?.unsubscribe();
    _candidatesChannel = client
        .channel('provider-service-candidates-$providerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_request_provider_candidates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'provider_profile_id',
            value: providerId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  List<ServiceRequestData> get _filteredRequests {
    if (_filter == 'Convites') {
      return _requests.where((r) => r.providerProfileId == null).toList();
    }
    if (_filter == 'Meus serviços') {
      return _requests.where((r) => r.providerProfileId != null).toList();
    }
    return _requests;
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  /// Executa uma ação sobre um pedido: bloqueia cliques repetidos, mostra
  /// erros (incluindo UPDATE que afetou 0 linhas) e recarrega a lista.
  Future<void> _run(
    ServiceRequestData request,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busyIds.contains(request.id)) return;
    setState(() => _busyIds.add(request.id));
    try {
      await action();
      _showMessage(successMessage);
    } on ServiceActionException catch (e) {
      _showMessage(e.message, error: true);
    } catch (_) {
      _showMessage('Ocorreu um erro. Tente novamente.', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
    await _load();
  }

  Future<void> _onPropose(ServiceRequestData request) async {
    final price = await showDialog<double>(
      context: context,
      builder: (_) => _PriceProposalDialog(initial: request.estimatedPrice),
    );
    if (price == null) return;
    final providerId = AuthState.providerProfileId ?? '';
    await _run(
      request,
      () => _service.proposePrice(
        requestId: request.id,
        providerProfileId: providerId,
        price: price,
      ),
      'Proposta enviada. A aguardar o administrador.',
    );
  }

  Future<void> _onDecline(ServiceRequestData request) async {
    final confirmed = await _confirm(
      title: 'Recusar convite?',
      message: 'O convite deixará de estar disponível para si.',
      confirmLabel: 'Recusar',
    );
    if (confirmed != true) return;
    final providerId = AuthState.providerProfileId ?? '';
    await _run(
      request,
      () => _service.declineInvite(
        requestId: request.id,
        providerProfileId: providerId,
      ),
      'Convite recusado.',
    );
  }

  Future<void> _onAdvance(
    ServiceRequestData request,
    ProviderServiceAction action,
  ) async {
    if (action == ProviderServiceAction.finish) {
      final confirmed = await _confirm(
        title: 'Concluir serviço?',
        message: 'Confirme apenas quando o serviço estiver terminado.',
        confirmLabel: 'Concluir',
      );
      if (confirmed != true) return;
    }
    final providerId = AuthState.providerProfileId ?? '';
    final message = switch (action) {
      ProviderServiceAction.confirm => 'Serviço confirmado.',
      ProviderServiceAction.start => 'Serviço iniciado.',
      _ => 'Serviço concluído.',
    };
    await _run(
      request,
      () => _service.advance(
        requestId: request.id,
        providerProfileId: providerId,
        action: action,
      ),
      message,
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: ServiceProviderBottomNav(
          selectedIndex: 0,
          onItemSelected: widget.onNavTap,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solicitações de Serviço',
                    style: TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Clube de benefícios desativado (ver FeatureFlags).
                  if (FeatureFlags.benefitsClubEnabled) ...[
                    _buildHomeBanner(context),
                    const SizedBox(height: 16),
                  ],
                  _buildFilterChips(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _filteredRequests.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: _buildEmptyState(),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              itemCount: _filteredRequests.length,
                              itemBuilder: (_, i) {
                                final request = _filteredRequests[i];
                                final providerId =
                                    AuthState.providerProfileId ?? '';
                                return _RequestCard(
                                  request: request,
                                  action: providerActionFor(
                                    request,
                                    providerId,
                                  ),
                                  statusLabel: serviceStatusLabel(
                                    request,
                                    providerId,
                                  ),
                                  busy: _busyIds.contains(request.id),
                                  onPropose: () => _onPropose(request),
                                  onDecline: () => _onDecline(request),
                                  onAdvance: (a) => _onAdvance(request, a),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['Todos', 'Convites', 'Meus serviços'];
    return Row(
      children: filters.map((f) {
        final isActive = f == _filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.highlight : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isActive
                    ? null
                    : Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontFamily: 'QuasimodoSemiBold',
                  fontSize: 13,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHomeBanner(BuildContext context) {
    return BenefitsBanner(onTap: () => context.push('/benefits'));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'QuasimodoSemiBold',
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'Nenhuma solicitação encontrada',
            style: TextStyle(
              fontFamily: 'QuasimodoSemiBold',
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequestData request;
  final ProviderServiceAction action;
  final String statusLabel;
  final bool busy;
  final VoidCallback onPropose;
  final VoidCallback onDecline;
  final ValueChanged<ProviderServiceAction> onAdvance;

  const _RequestCard({
    required this.request,
    required this.action,
    required this.statusLabel,
    required this.busy,
    required this.onPropose,
    required this.onDecline,
    required this.onAdvance,
  });

  String? get _advanceLabel => switch (action) {
    ProviderServiceAction.confirm => 'Confirmar serviço',
    ProviderServiceAction.start => 'Iniciar serviço',
    ProviderServiceAction.finish => 'Concluir serviço',
    _ => null,
  };

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.highlight,
        foregroundColor: AppColors.onHighlight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontFamily: 'OutfitBlack', fontSize: 13),
      ),
    );
  }

  String get _formattedDate {
    final d = request.serviceDate;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} às '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isFreeform = request.freeformProfession?.isNotEmpty == true;
    final badgeLabel = isFreeform
        ? '👤 ${request.freeformProfession}'
        : request.categoryName;
    final categoryColor = isFreeform
        ? const Color(0xFF8B5CF6)
        : categoryColorFor(request.categoryName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.clientName,
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 12,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.description,
            maxLines: requestDescriptionMaxLines(action),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'QuasimodoSemiBold',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (request.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: request.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    request.photoUrls[index],
                    width: 72,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 72,
                      height: 64,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.address,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                servicePriceLabel(request),
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 15,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: const TextStyle(
                fontFamily: 'OutfitBlack',
                fontSize: 12,
                color: Color(0xFF2ECC71),
              ),
            ),
          ),
          if (action == ProviderServiceAction.proposePrice) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Recusar',
                      style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _primaryButton(
                    'Propor preço',
                    busy ? null : onPropose,
                  ),
                ),
              ],
            ),
          ] else if (_advanceLabel != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _primaryButton(
                _advanceLabel!,
                busy ? null : () => onAdvance(action),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pede o preço da proposta em Kz e devolve o valor validado.
class _PriceProposalDialog extends StatefulWidget {
  final double? initial;

  const _PriceProposalDialog({this.initial});

  @override
  State<_PriceProposalDialog> createState() => _PriceProposalDialogState();
}

class _PriceProposalDialogState extends State<_PriceProposalDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controller = TextEditingController(
      text: initial != null && initial > 0 ? initial.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseKzAmount(_controller.text);
    if (value == null) {
      setState(() => _error = 'Indique um valor válido em Kz.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Propor preço'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Indique o valor do serviço. O administrador analisa a sua proposta.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Valor',
              suffixText: 'Kz',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _submit, child: const Text('Enviar proposta')),
      ],
    );
  }
}
