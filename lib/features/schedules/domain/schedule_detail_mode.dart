String scheduleDetailHeaderTitle({required bool isDriverRecheck}) {
  return isDriverRecheck
      ? 'Cliente confirmou a sua viagem'
      : 'Nova solicitação';
}

String scheduleDetailHeaderSubtitle({required bool isDriverRecheck}) {
  return isDriverRecheck
      ? 'Verifique os detalhes e confirme se ainda pretende manter o agendamento'
      : 'Defina o seu valor antes de aceitar';
}

String scheduleDetailRecheckMessage() {
  return 'O passageiro confirmou a viagem. Verifique os detalhes e confirme se ainda pretende manter o agendamento.';
}

bool shouldShowPriceOfferCard({required bool isDriverRecheck}) {
  return true;
}

bool isPriceOfferEditable({required bool isDriverRecheck}) {
  return !isDriverRecheck;
}
