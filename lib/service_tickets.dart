/// Каталог служебных тикетов компании (EG Project).
class ServiceTicket {
  final String key;
  final String category;
  final String description;

  const ServiceTicket({
    required this.key,
    required this.category,
    required this.description,
  });
}

/// Полный список служебных тикетов (EG Project).
const List<ServiceTicket> kServiceTickets = [
  ServiceTicket(
    key: 'EG-294',
    category: 'Non-utilized Meeting/Events',
    description: 'Созвоны, синги, таунхоллы (не привязанные к конкретной задаче)',
  ),
  ServiceTicket(
    key: 'EG-295',
    category: 'Other (please describe the work)',
    description: 'Общая активность, разные мелкие задачи без тикета',
  ),
  ServiceTicket(
    key: 'EG-296',
    category: 'Customer support (provide details)',
    description: 'Помощь клиентам, расследование инцидентов клиентов',
  ),
  ServiceTicket(
    key: 'EG-297',
    category: 'Work with e-mails (internal/external)',
    description: 'Разбор и написание писем (коллегам или контрагентам)',
  ),
  ServiceTicket(
    key: 'EG-298',
    category: 'PreSales',
    description: 'Участие в пресейлах (демо, RFI, RFP)',
  ),
  ServiceTicket(
    key: 'EG-299',
    category: 'SysAdmin Department Assistance',
    description: 'Помощь сисадминам / инфраструктурные вопросы',
  ),
  ServiceTicket(
    key: 'EG-300',
    category: 'Support Department Assistance',
    description: 'Помощь отделу саппорта',
  ),
  ServiceTicket(
    key: 'EG-301',
    category: 'Personal Training',
    description: 'Обучение, самообразование, курсы',
  ),
  ServiceTicket(
    key: 'EG-302',
    category: 'Product Planning',
    description: 'Планирование продукта, обсуждение роадмапа',
  ),
  ServiceTicket(
    key: 'EG-303',
    category: 'Equipment setup',
    description: 'Настройка софта / железа для коллег',
  ),
  ServiceTicket(
    key: 'EG-304',
    category: 'Recruiting',
    description: 'Собеседования, HR-активности',
  ),
  ServiceTicket(
    key: 'EG-1',
    category: 'Support Sales',
    description: 'Помощь отделу продаж',
  ),
  ServiceTicket(
    key: 'EG-3',
    category: 'Vacation',
    description: 'Отпуск / отгулы',
  ),
  ServiceTicket(
    key: 'EG-4',
    category: 'Sick/Other',
    description: 'Больничный',
  ),
  ServiceTicket(
    key: 'EG-6',
    category: 'Methods/Tools Development',
    description: 'Разработка внутренних инструментов и скриптов',
  ),
  ServiceTicket(
    key: 'EG-9',
    category: 'Non-Billable Travel',
    description: 'Время в дороге (командировки, конференции)',
  ),
  ServiceTicket(
    key: 'EG-10',
    category: 'Bench (Other)',
    description: 'Бенч / ожидание проекта',
  ),
  ServiceTicket(
    key: 'EG-12',
    category: 'Knowledge Transfer Meetings',
    description: 'Передача знаний (KT) с коллегами',
  ),
];

/// Найти описание служебного тикета по ключу или идентификатору (регистронезависимо).
ServiceTicket? findServiceTicket(String keyOrId) {
  final upper = keyOrId.toUpperCase().trim();
  for (final ticket in kServiceTickets) {
    if (ticket.key.toUpperCase() == upper) {
      return ticket;
    }
  }
  return null;
}
