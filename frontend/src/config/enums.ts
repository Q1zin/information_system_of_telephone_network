// Shared option lists matching the database enum values (Russian labels).
export interface Opt {
  label: string
  value: string
}

export const pbxTypeOptions: Opt[] = [
  { label: 'Городская', value: 'city' },
  { label: 'Ведомственная', value: 'departmental' },
  { label: 'Учрежденческая', value: 'institutional' },
]
export const lineTypeOptions: Opt[] = [
  { label: 'Основной', value: 'main' },
  { label: 'Параллельный', value: 'parallel' },
  { label: 'Спаренный', value: 'paired' },
]
export const intercityOptions: Opt[] = [
  { label: 'Нет', value: 'none' },
  { label: 'Открыт', value: 'open' },
  { label: 'Закрыт', value: 'closed' },
]
export const numberStatusOptions: Opt[] = [
  { label: 'Свободен', value: 'free' },
  { label: 'Зарезервирован', value: 'reserved' },
  { label: 'Активен', value: 'active' },
  { label: 'Заблокирован', value: 'blocked' },
]
export const genderOptions: Opt[] = [
  { label: 'М', value: 'male' },
  { label: 'Ж', value: 'female' },
]
export const categoryOptions: Opt[] = [
  { label: 'Простой', value: 'regular' },
  { label: 'Льготный', value: 'privileged' },
]
export const privilegeOptions: Opt[] = [
  { label: 'Пенсионер', value: 'pensioner' },
  { label: 'Инвалид', value: 'disabled' },
  { label: 'Ветеран', value: 'veteran' },
  { label: 'Другое', value: 'other' },
]
export const subStatusOptions: Opt[] = [
  { label: 'Активен', value: 'active' },
  { label: 'Межгород заблокирован', value: 'intercity_blocked' },
  { label: 'Отключён', value: 'disconnected' },
]
export const callTypeOptions: Opt[] = [
  { label: 'Местный', value: 'local' },
  { label: 'Внутренний', value: 'internal' },
  { label: 'Внешний', value: 'external' },
  { label: 'Межгород', value: 'intercity' },
]
export const invoiceKindOptions: Opt[] = [
  { label: 'Абонплата', value: 'subscription' },
  { label: 'Межгород', value: 'intercity' },
]
export const invoiceStatusOptions: Opt[] = [
  { label: 'Ожидает', value: 'pending' },
  { label: 'Оплачен', value: 'paid' },
  { label: 'Просрочен', value: 'overdue' },
  { label: 'Отменён', value: 'cancelled' },
]
export const queueTypeOptions: Opt[] = [
  { label: 'Обычная', value: 'regular' },
  { label: 'Льготная', value: 'privileged' },
]
export const queueStatusOptions: Opt[] = [
  { label: 'Ожидает', value: 'waiting' },
  { label: 'Возможно', value: 'feasible' },
  { label: 'Установлен', value: 'installed' },
  { label: 'Отклонён', value: 'rejected' },
]
export const publicKindOptions: Opt[] = [
  { label: 'Общественный', value: 'public' },
  { label: 'Таксофон', value: 'payphone' },
]
