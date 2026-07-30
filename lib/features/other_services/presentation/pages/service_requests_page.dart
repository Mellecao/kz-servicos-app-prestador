import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/category_colors.dart';
import 'package:kz_servicos_prestador/core/models/service_request_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/service_request_service.dart';
import 'package:kz_servicos_prestador/core/widgets/service_provider_bottom_nav.dart';
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
  List<ServiceRequestData> _requests = [];
  final Set<String> _hiddenIds = {};
  Set<String> _providerCategoryIds = {};
  RealtimeChannel? _serviceRequestsChannel;

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final providerId = AuthState.providerProfileId ?? '';
    final result = await _service.getProviderRequests(providerId);
    final categoryIds = await _service.getProviderCategoryIds(providerId);
    if (!mounted) return;
    setState(() {
      _requests = result;
      _providerCategoryIds = categoryIds;
      _loading = false;
    });
  }

  void _subscribeToServiceRequests() {
    final providerId = AuthState.providerProfileId;
    if (providerId == null || providerId.isEmpty) return;
    _serviceRequestsChannel?.unsubscribe();
    _serviceRequestsChannel = Supabase.instance.client
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
  }

  List<ServiceRequestData> get _filteredRequests {
    final providerId = AuthState.providerProfileId;
    final visible = _requests.where((r) => !_hiddenIds.contains(r.id)).toList();
    if (_filter == 'Pendentes') {
      return visible.where((r) => r.providerProfileId == null).toList();
    }
    if (_filter == 'Aceitos') {
      return visible.where((r) => r.providerProfileId == providerId).toList();
    }
    return visible;
  }

  Future<void> _onAccept(ServiceRequestData request) async {
    final providerId = AuthState.providerProfileId ?? '';
    final ok = await _service.acceptRequest(request.id, providerId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Solicitação aceita' : 'Não foi possível aceitar'),
      ),
    );
    if (ok) await _load();
  }

  void _onReject(ServiceRequestData request) {
    setState(() => _hiddenIds.add(request.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Solicitação recusada')));
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
                  _buildHomeBanner(context),
                  const SizedBox(height: 16),
                  _buildFilterChips(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
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
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                0,
                                24,
                                24,
                              ),
                              itemCount: _filteredRequests.length,
                              itemBuilder: (_, i) => _RequestCard(
                                request: _filteredRequests[i],
                                onAccept: () => _onAccept(_filteredRequests[i]),
                                onReject: () => _onReject(_filteredRequests[i]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['Todos', 'Pendentes', 'Aceitos'];
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

  double _homeBannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 48;
    return (width / 3.19).clamp(88.0, 118.0);
  }

  Widget _buildHomeBanner(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/benefits'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: _homeBannerHeight(context),
            width: double.infinity,
            child: Image.asset(
              'assets/images/banner.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
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
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

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
            maxLines: 2,
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
                'R\$ ${request.displayPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 15,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          if (request.isOpen) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
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
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.highlight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Aceitar',
                      style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Aceito',
                style: TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 12,
                  color: Color(0xFF2ECC71),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
