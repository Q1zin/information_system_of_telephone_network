import type { Opt } from './enums'
import * as E from './enums'

export type FieldType = 'text' | 'number' | 'textarea' | 'select' | 'date' | 'datetime' | 'switch'

export interface FieldDef {
  prop: string
  label: string
  type: FieldType
  required?: boolean
  options?: Opt[]
}

export interface ColumnDef {
  prop: string
  label: string
  width?: number
}

export interface ResourceDef {
  key: string // route param + permission resource name
  path: string // REST path under /api
  title: string
  perm: string // permission resource name (entity)
  columns: ColumnDef[]
  fields: FieldDef[]
}

const t = (prop: string, label: string, required = false): FieldDef => ({ prop, label, type: 'text', required })
const n = (prop: string, label: string, required = false): FieldDef => ({ prop, label, type: 'number', required })
const sel = (prop: string, label: string, options: Opt[], required = false): FieldDef => ({ prop, label, type: 'select', options, required })

export const resources: ResourceDef[] = [
  {
    key: 'cities', path: 'cities', title: 'Города', perm: 'city',
    columns: [{ prop: 'id', label: 'ID', width: 70 }, { prop: 'name', label: 'Название' }, { prop: 'is_home', label: 'Свой город' }],
    fields: [t('name', 'Название', true), { prop: 'is_home', label: 'Свой город', type: 'switch' }],
  },
  {
    key: 'addresses', path: 'addresses', title: 'Адреса', perm: 'address',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'postal_index', label: 'Индекс' },
      { prop: 'district', label: 'Район' }, { prop: 'street', label: 'Улица' },
      { prop: 'house', label: 'Дом' }, { prop: 'apartment', label: 'Кв.' },
    ],
    fields: [t('postal_index', 'Индекс', true), t('district', 'Район', true), t('street', 'Улица', true), t('house', 'Дом', true), t('apartment', 'Квартира')],
  },
  {
    key: 'pbx', path: 'pbx', title: 'АТС', perm: 'pbx',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'name', label: 'Название' }, { prop: 'code', label: 'Код' },
      { prop: 'pbx_type', label: 'Тип' }, { prop: 'district', label: 'Район' }, { prop: 'capacity_numbers', label: 'Ёмкость' },
      { prop: 'free_channels', label: 'Своб. каналы' },
    ],
    fields: [
      t('name', 'Название', true), t('code', 'Код', true), sel('pbx_type', 'Тип', E.pbxTypeOptions, true),
      t('district', 'Район', true), n('address_id', 'ID адреса'), n('capacity_numbers', 'Ёмкость номеров', true),
      n('total_channels', 'Всего каналов', true), n('free_channels', 'Свободно каналов', true),
      { prop: 'has_free_cable', label: 'Есть кабель', type: 'switch' },
    ],
  },
  {
    key: 'phone-numbers', path: 'phone-numbers', title: 'Номера', perm: 'phone_number',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'number', label: 'Номер' }, { prop: 'pbx_id', label: 'АТС' },
      { prop: 'line_type', label: 'Тип линии' }, { prop: 'intercity', label: 'Межгород' }, { prop: 'status', label: 'Статус' },
    ],
    fields: [
      t('number', 'Номер', true), n('pbx_id', 'ID АТС', true), sel('line_type', 'Тип линии', E.lineTypeOptions),
      sel('intercity', 'Межгород', E.intercityOptions), sel('status', 'Статус', E.numberStatusOptions), n('address_id', 'ID адреса'),
    ],
  },
  {
    key: 'subscribers', path: 'subscribers', title: 'Абоненты', perm: 'subscriber',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'last_name', label: 'Фамилия' }, { prop: 'first_name', label: 'Имя' },
      { prop: 'category', label: 'Категория' }, { prop: 'status', label: 'Статус' }, { prop: 'phone_number_id', label: 'Номер' },
    ],
    fields: [
      t('last_name', 'Фамилия', true), t('first_name', 'Имя', true), t('middle_name', 'Отчество'),
      sel('gender', 'Пол', E.genderOptions, true), { prop: 'birth_date', label: 'Дата рождения', type: 'date', required: true },
      sel('category', 'Категория', E.categoryOptions), sel('privilege', 'Льгота', E.privilegeOptions),
      sel('status', 'Статус', E.subStatusOptions), n('phone_number_id', 'ID номера', true), n('address_id', 'ID адреса', true),
      { prop: 'connected_at', label: 'Подключён', type: 'date' },
    ],
  },
  {
    key: 'calls', path: 'calls', title: 'Звонки (CDR)', perm: 'call',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'from_number_id', label: 'Откуда' }, { prop: 'call_type', label: 'Тип' },
      { prop: 'dest_city_id', label: 'Город' }, { prop: 'duration_sec', label: 'Длит., c' }, { prop: 'cost', label: 'Стоимость' },
    ],
    fields: [
      n('from_number_id', 'ID номера-источника', true), sel('call_type', 'Тип', E.callTypeOptions, true),
      n('dest_city_id', 'ID города (для межгорода)'), { prop: 'started_at', label: 'Начало', type: 'datetime', required: true },
      n('duration_sec', 'Длительность, c', true), n('cost', 'Стоимость'),
    ],
  },
  {
    key: 'tariffs', path: 'tariffs', title: 'Тарифы', perm: 'tariff',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'line_type', label: 'Тип линии' }, { prop: 'with_intercity', label: 'С межгородом' },
      { prop: 'monthly_fee', label: 'Абонплата' }, { prop: 'valid_from', label: 'Действует с' },
    ],
    fields: [
      sel('line_type', 'Тип линии', E.lineTypeOptions, true), { prop: 'with_intercity', label: 'С межгородом', type: 'switch' },
      n('monthly_fee', 'Абонплата', true), { prop: 'valid_from', label: 'Действует с', type: 'date' },
    ],
  },
  {
    key: 'invoices', path: 'invoices', title: 'Счета', perm: 'invoice',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'subscriber_id', label: 'Абонент' }, { prop: 'kind', label: 'Вид' },
      { prop: 'amount', label: 'Сумма' }, { prop: 'due_date', label: 'Срок' }, { prop: 'status', label: 'Статус' },
    ],
    fields: [
      n('subscriber_id', 'ID абонента', true), sel('kind', 'Вид', E.invoiceKindOptions, true),
      n('period_year', 'Год', true), n('period_month', 'Месяц', true), n('amount', 'Сумма', true),
      { prop: 'due_date', label: 'Срок оплаты', type: 'date', required: true }, sel('status', 'Статус', E.invoiceStatusOptions),
    ],
  },
  {
    key: 'payments', path: 'payments', title: 'Платежи', perm: 'payment',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'subscriber_id', label: 'Абонент' },
      { prop: 'invoice_id', label: 'Счёт' }, { prop: 'amount', label: 'Сумма' }, { prop: 'paid_at', label: 'Дата' },
    ],
    fields: [n('subscriber_id', 'ID абонента', true), n('invoice_id', 'ID счёта'), n('amount', 'Сумма', true)],
  },
  {
    key: 'penalties', path: 'penalties', title: 'Пени', perm: 'penalty',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'subscriber_id', label: 'Абонент' },
      { prop: 'amount', label: 'Сумма' }, { prop: 'reason', label: 'Причина' }, { prop: 'paid', label: 'Оплачена' },
    ],
    fields: [
      n('subscriber_id', 'ID абонента', true), n('invoice_id', 'ID счёта'), n('amount', 'Сумма', true),
      t('reason', 'Причина'), { prop: 'paid', label: 'Оплачена', type: 'switch' },
    ],
  },
  {
    key: 'notifications', path: 'notifications', title: 'Уведомления', perm: 'notification',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'subscriber_id', label: 'Абонент' }, { prop: 'kind', label: 'Вид' },
      { prop: 'sent_at', label: 'Отправлено' }, { prop: 'deadline', label: 'Дедлайн' }, { prop: 'resolved', label: 'Закрыто' },
    ],
    fields: [
      n('subscriber_id', 'ID абонента', true),
      sel('kind', 'Вид', [{ label: 'Долг абонплата', value: 'subscription_debt' }, { label: 'Долг межгород', value: 'intercity_debt' }], true),
      { prop: 'deadline', label: 'Дедлайн', type: 'date', required: true }, { prop: 'resolved', label: 'Закрыто', type: 'switch' },
    ],
  },
  {
    key: 'queue', path: 'queue', title: 'Очередь установки', perm: 'queue',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'applicant_last_name', label: 'Фамилия' },
      { prop: 'queue_type', label: 'Очередь' }, { prop: 'status', label: 'Статус' }, { prop: 'address_id', label: 'Адрес' },
    ],
    fields: [
      t('applicant_last_name', 'Фамилия', true), t('applicant_first_name', 'Имя', true), t('applicant_middle_name', 'Отчество'),
      sel('queue_type', 'Очередь', E.queueTypeOptions), n('address_id', 'ID адреса', true), n('desired_pbx_id', 'ID желаемой АТС'),
      sel('status', 'Статус', E.queueStatusOptions),
    ],
  },
  {
    key: 'public-phones', path: 'public-phones', title: 'Таксофоны', perm: 'public_phone',
    columns: [
      { prop: 'id', label: 'ID', width: 70 }, { prop: 'kind', label: 'Вид' }, { prop: 'pbx_id', label: 'АТС' },
      { prop: 'address_id', label: 'Адрес' }, { prop: 'active', label: 'Активен' },
    ],
    fields: [
      sel('kind', 'Вид', E.publicKindOptions, true), n('pbx_id', 'ID АТС', true), n('address_id', 'ID адреса', true),
      n('phone_number_id', 'ID номера'), { prop: 'active', label: 'Активен', type: 'switch' },
    ],
  },
]

export const resourceByKey = (key: string) => resources.find((r) => r.key === key)
