String scheduleDetailHeaderTitle({required bool isDriverRecheck}) {
  return isDriverRecheck ? 'Cliente confirmou sua viagem' : 'Nova solicitação';
}

String scheduleDetailHeaderSubtitle({required bool isDriverRecheck}) {
  return isDriverRecheck
      ? 'Confira os detalhes e confirme se ainda quer manter o agendamento'
      : 'Defina seu valor antes de aceitar';
}

String scheduleDetailRecheckMessage() {
  return 'O passageiro confirmou a corrida. Confira os detalhes e confirme se ainda quer manter o agendamento.';
}

bool shouldShowPriceOfferCard({required bool isDriverRecheck}) {
  return true;
}

bool isPriceOfferEditable({required bool isDriverRecheck}) {
  return !isDriverRecheck;
}
