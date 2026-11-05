-- Prestador convidado ou atribuído passa a poder LER as fotos do pedido de serviço.
-- Hoje o SELECT em service_request_photos devolve 0 linhas ao prestador (provado por API:
-- pedido 51303666-04a4-44c2-b195-8fe72fb6db67 com 1 foto; cliente vê, prestador convidado
-- não), por isso o app Prestador nunca mostra as fotos.
-- Aditivo: policy permissiva que se soma (OR) às existentes. Não altera dados.
-- Nota: nenhuma migration exportada menciona service_request_photos; se já existir uma
-- policy com este nome, ajustar o nome.
CREATE POLICY service_request_photos_select_provider ON public.service_request_photos
  FOR SELECT TO authenticated
  USING (
    public.is_service_request_provider_candidate_for_current_user(service_request_id)
    OR EXISTS (
      SELECT 1
      FROM public.service_requests sr
      JOIN public.provider_profiles pp ON pp.id = sr.provider_profile_id
      WHERE sr.id = service_request_photos.service_request_id
        AND pp.user_id = auth.uid()
    )
  );
