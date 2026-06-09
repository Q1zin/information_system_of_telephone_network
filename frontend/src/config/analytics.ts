import type { Opt } from './enums'
import * as E from './enums'
import { pbxLabel } from './resources'

export type ParamType = 'text' | 'number' | 'select' | 'switch' | 'date' | 'reference'

export interface ParamDef {
  name: string
  label: string
  type: ParamType
  options?: Opt[]
  refPath?: string
  refValue?: string
  refLabel?: (row: Record<string, any>) => string
}

export interface ResultColumn {
  prop: string
  label: string
  options?: Opt[]
}

export interface QueryDef {
  key: string
  title: string
  path: string // under /api
  params: ParamDef[]
  columns: ResultColumn[]
}

const anyKindOptions: Opt[] = [
  { label: 'Любой', value: 'any' },
  { label: 'Абонплата', value: 'subscription' },
  { label: 'Межгород', value: 'intercity' },
]

const c = (prop: string, label: string, options?: Opt[]): ResultColumn => ({ prop, label, options })
const pbxParam = (): ParamDef => ({
  name: 'pbx_id',
  label: 'АТС',
  type: 'reference',
  refPath: 'pbx',
  refLabel: pbxLabel,
})

export const analyticsQueries: QueryDef[] = [
  {
    key: 'q1', title: 'Q1. Абоненты АТС', path: 'analytics/subscribers',
    params: [
      pbxParam(),
      { name: 'category', label: 'Категория', type: 'select', options: E.categoryOptions },
      { name: 'min_age', label: 'Возраст от', type: 'number' },
      { name: 'max_age', label: 'Возраст до', type: 'number' },
      { name: 'surname', label: 'Фамилия (префикс)', type: 'text' },
    ],
    columns: [
      c('last_name', 'Фамилия'), c('first_name', 'Имя'), c('middle_name', 'Отчество'),
      c('age', 'Возраст'), c('category', 'Категория', E.categoryOptions),
      c('status', 'Статус', E.subStatusOptions), c('number', 'Номер'),
      c('pbx_name', 'АТС'), c('district', 'Район'), c('street', 'Улица'), c('house', 'Дом'),
    ],
  },
  {
    key: 'q2', title: 'Q2. Свободные номера', path: 'analytics/free-numbers',
    params: [
      pbxParam(),
      { name: 'district', label: 'Район', type: 'text' },
    ],
    columns: [
      c('number', 'Номер'), c('line_type', 'Тип линии', E.lineTypeOptions),
      c('intercity', 'Межгород', E.intercityOptions), c('pbx_name', 'АТС'), c('district', 'Район'),
    ],
  },
  {
    key: 'q3', title: 'Q3. Должники', path: 'analytics/debtors',
    params: [
      pbxParam(),
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'min_days', label: 'Просрочка от (дней)', type: 'number' },
      { name: 'kind', label: 'Вид долга', type: 'select', options: anyKindOptions },
      { name: 'min_amount', label: 'Сумма от', type: 'number' },
    ],
    columns: [
      c('last_name', 'Фамилия'), c('first_name', 'Имя'), c('number', 'Номер'),
      c('pbx_name', 'АТС'), c('pbx_district', 'Район'),
      c('subscription_debt', 'Долг: абонплата'), c('intercity_debt', 'Долг: межгород'),
      c('penalty_debt', 'Пени'), c('total_debt', 'Всего долг'), c('days_overdue', 'Дней просрочки'),
    ],
  },
  {
    key: 'q4', title: 'Q4. Рейтинг АТС по долгам', path: 'analytics/pbx-debt-ranking',
    params: [{ name: 'pbx_type', label: 'Тип АТС', type: 'select', options: E.pbxTypeOptions }],
    columns: [
      c('pbx_name', 'АТС'), c('pbx_type', 'Тип АТС', E.pbxTypeOptions),
      c('debtors', 'Должников'), c('debt_sum', 'Сумма долга'),
    ],
  },
  {
    key: 'q5', title: 'Q5. Таксофоны и общественные', path: 'analytics/public-phones',
    params: [
      pbxParam(),
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'kind', label: 'Вид', type: 'select', options: E.publicKindOptions },
    ],
    columns: [
      c('kind', 'Вид', E.publicKindOptions), c('pbx_name', 'АТС'), c('district', 'Район'),
      c('street', 'Улица'), c('house', 'Дом'), c('active', 'Активен'),
    ],
  },
  {
    key: 'q6', title: 'Q6. Доля простых/льготных', path: 'analytics/category-ratio',
    params: [
      pbxParam(),
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'pbx_type', label: 'Тип АТС', type: 'select', options: E.pbxTypeOptions },
    ],
    columns: [
      c('total', 'Всего'), c('regular', 'Простых'), c('privileged', 'Льготных'),
      c('regular_pct', 'Простых, %'), c('privileged_pct', 'Льготных, %'),
    ],
  },
  {
    key: 'q7', title: 'Q7. Абоненты с параллельными', path: 'analytics/parallel-subscribers',
    params: [
      pbxParam(),
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'pbx_type', label: 'Тип АТС', type: 'select', options: E.pbxTypeOptions },
      { name: 'privileged_only', label: 'Только льготники', type: 'switch' },
    ],
    columns: [
      c('number', 'Номер'), c('last_name', 'Фамилия'), c('first_name', 'Имя'),
      c('line_type', 'Тип линии', E.lineTypeOptions), c('pbx_name', 'АТС'), c('district', 'Район'),
    ],
  },
  {
    key: 'q8', title: 'Q8. Телефоны по адресу', path: 'analytics/phones-by-address',
    params: [
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'street', label: 'Улица', type: 'text' },
      { name: 'house', label: 'Дом', type: 'text' },
    ],
    columns: [
      c('district', 'Район'), c('street', 'Улица'), c('house', 'Дом'),
      c('phones', 'Телефонов'), c('with_intercity', 'С межгородом'),
      c('with_open_intercity', 'С открытым межгородом'),
    ],
  },
  {
    key: 'q9', title: 'Q9. Город-лидер межгорода', path: 'analytics/top-intercity-city', params: [],
    columns: [c('city', 'Город'), c('calls', 'Звонков')],
  },
  {
    key: 'q10', title: 'Q10. Информация по номеру', path: 'analytics/subscriber-by-number',
    params: [{ name: 'number', label: 'Номер', type: 'text' }],
    columns: [
      c('number', 'Номер'), c('last_name', 'Фамилия'), c('first_name', 'Имя'), c('middle_name', 'Отчество'),
      c('age', 'Возраст'), c('category', 'Категория', E.categoryOptions),
      c('status', 'Статус', E.subStatusOptions), c('line_type', 'Тип линии', E.lineTypeOptions),
      c('intercity', 'Межгород', E.intercityOptions), c('pbx_name', 'АТС'),
      c('district', 'Район'), c('street', 'Улица'), c('house', 'Дом'),
    ],
  },
  {
    key: 'q11', title: 'Q11. Расспариваемые спаренные', path: 'analytics/splittable-paired',
    params: [pbxParam()],
    columns: [
      c('number', 'Номер'), c('pbx_name', 'АТС'), c('district', 'Район'),
      c('free_numbers', 'Своб. номеров'), c('free_channels', 'Своб. каналов'),
    ],
  },
  {
    key: 'q12', title: 'Q12. Мало внешних звонков', path: 'analytics/low-external-call-numbers',
    params: [
      pbxParam(),
      { name: 'from', label: 'С даты', type: 'date' },
      { name: 'to', label: 'По дату', type: 'date' },
      { name: 'max_calls', label: 'Менее N звонков', type: 'number' },
    ],
    columns: [
      c('number', 'Номер'), c('pbx_name', 'АТС'), c('pbx_type', 'Тип АТС', E.pbxTypeOptions),
      c('external_calls', 'Внешних звонков'),
    ],
  },
  {
    key: 'q13', title: 'Q13. Кандидаты на действия', path: 'analytics/action-needed-debtors',
    params: [
      pbxParam(),
      { name: 'district', label: 'Район', type: 'text' },
    ],
    columns: [
      c('last_name', 'Фамилия'), c('first_name', 'Имя'), c('number', 'Номер'), c('pbx_name', 'АТС'),
      c('status', 'Статус', E.subStatusOptions), c('intercity', 'Межгород', E.intercityOptions),
      c('subscription_debt', 'Долг: абонплата'), c('intercity_debt', 'Долг: межгород'),
      c('total_debt', 'Всего долг'),
      c('notice_subscription', 'Уведомить: абонплата'), c('notice_intercity', 'Уведомить: межгород'),
      c('should_disconnect', 'Отключить'), c('should_block_intercity', 'Блок. межгород'),
    ],
  },
]
