import '../models/order_model.dart';

/// Converte o enum [OrderStatus] para o valor salvo no banco (Postgres ENUM).
/// No banco o status de reembolso é `reembolso_solicitado` (snake_case).
String orderStatusToDb(OrderStatus status) {
  switch (status) {
    case OrderStatus.reembolsoSolicitado:
      return 'reembolso_solicitado';
    case OrderStatus.pendente:
    case OrderStatus.andamento:
    case OrderStatus.entregue:
      return status.name; // valores já batem com o banco
  }
}

/// Converte o valor vindo do banco para o enum [OrderStatus].
/// Aceita tanto `reembolso_solicitado` quanto `reembolsoSolicitado` por segurança.
OrderStatus orderStatusFromDb(dynamic raw) {
  final value = raw?.toString() ?? '';

  switch (value) {
    case 'pendente':
      return OrderStatus.pendente;
    case 'andamento':
      return OrderStatus.andamento;
    case 'entregue':
      return OrderStatus.entregue;
    case 'reembolso_solicitado':
    case 'reembolsoSolicitado':
      return OrderStatus.reembolsoSolicitado;
    default:
      // Fallback seguro
      return OrderStatus.pendente;
  }
}
