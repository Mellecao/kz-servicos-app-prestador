-- Prestador convidado (service_request_provider_candidates) passa a poder LER o pedido
-- para o qual foi convidado. Hoje a policy service_requests_select só deixa ver pedidos
-- cujo provider_profile_id já é o do prestador, por isso um convite 'pending' fica
-- invisível e a lista de convites do app Prestador vem sempre vazia.
-- Aditivo: policies permissivas somam-se (OR) às existentes. A função helper já existe
-- (migration 20260814133242). Não altera dados.
CREATE POLICY service_requests_select_invited_provider ON public.service_requests
  FOR SELECT TO authenticated
  USING (public.is_service_request_provider_candidate_for_current_user(id));

-- Se, depois de aplicar, o endereço ou as fotos do pedido aparecerem vazios no app
-- (embeds addresses/service_request_photos), a RLS dessas tabelas precisa do mesmo
-- tratamento; confirmo por API e peço o SQL.
