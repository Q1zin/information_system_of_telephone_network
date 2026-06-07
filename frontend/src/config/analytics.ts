import type { Opt } from './enums'
import * as E from './enums'

export type ParamType = 'text' | 'number' | 'select' | 'switch' | 'date'

export interface ParamDef {
  name: string
  label: string
  type: ParamType
  options?: Opt[]
}

export interface QueryDef {
  key: string
  title: string
  path: string // under /api
  params: ParamDef[]
}

const anyKindOptions: Opt[] = [
  { label: 'Любой', value: 'any' },
  { label: 'Абонплата', value: 'subscription' },
  { label: 'Межгород', value: 'intercity' },
]

export const analyticsQueries: QueryDef[] = [
  {
    key: 'q1', title: 'Q1. Абоненты АТС', path: 'analytics/subscribers',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'category', label: 'Категория', type: 'select', options: E.categoryOptions },
      { name: 'min_age', label: 'Возраст от', type: 'number' },
      { name: 'max_age', label: 'Возраст до', type: 'number' },
      { name: 'surname', label: 'Фамилия (префикс)', type: 'text' },
    ],
  },
  {
    key: 'q2', title: 'Q2. Свободные номера', path: 'analytics/free-numbers',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'district', label: 'Район', type: 'text' },
    ],
  },
  {
    key: 'q3', title: 'Q3. Должники', path: 'analytics/debtors',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'min_days', label: 'Просрочка от (дней)', type: 'number' },
      { name: 'kind', label: 'Вид долга', type: 'select', options: anyKindOptions },
      { name: 'min_amount', label: 'Сумма от', type: 'number' },
    ],
  },
  {
    key: 'q4', title: 'Q4. Рейтинг АТС по долгам', path: 'analytics/pbx-debt-ranking',
    params: [{ name: 'pbx_type', label: 'Тип АТС', type: 'select', options: E.pbxTypeOptions }],
  },
  {
    key: 'q5', title: 'Q5. Таксофоны и общественные', path: 'analytics/public-phones',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'kind', label: 'Вид', type: 'select', options: E.publicKindOptions },
    ],
  },
  {
    key: 'q6', title: 'Q6. Доля простых/льготных', path: 'analytics/category-ratio',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'pbx_type', label: 'Тип АТС', type: 'select', options: E.pbxTypeOptions },
    ],
  },
  {
    key: 'q7', title: 'Q7. Абоненты с параллельными', path: 'analytics/parallel-subscribers',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'pbx_type', label: 'Тип АТС', type: 'select', options: E.pbxTypeOptions },
      { name: 'privileged_only', label: 'Только льготники', type: 'switch' },
    ],
  },
  {
    key: 'q8', title: 'Q8. Телефоны по адресу', path: 'analytics/phones-by-address',
    params: [
      { name: 'district', label: 'Район', type: 'text' },
      { name: 'street', label: 'Улица', type: 'text' },
      { name: 'house', label: 'Дом', type: 'text' },
    ],
  },
  { key: 'q9', title: 'Q9. Город-лидер межгорода', path: 'analytics/top-intercity-city', params: [] },
  {
    key: 'q10', title: 'Q10. Информация по номеру', path: 'analytics/subscriber-by-number',
    params: [{ name: 'number', label: 'Номер', type: 'text' }],
  },
  {
    key: 'q11', title: 'Q11. Расспариваемые спаренные', path: 'analytics/splittable-paired',
    params: [{ name: 'pbx_id', label: 'ID АТС', type: 'number' }],
  },
  {
    key: 'q12', title: 'Q12. Мало внешних звонков', path: 'analytics/low-external-call-numbers',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'from', label: 'С даты', type: 'date' },
      { name: 'to', label: 'По дату', type: 'date' },
      { name: 'max_calls', label: 'Менее N звонков', type: 'number' },
    ],
  },
  {
    key: 'q13', title: 'Q13. Кандидаты на действия', path: 'analytics/action-needed-debtors',
    params: [
      { name: 'pbx_id', label: 'ID АТС', type: 'number' },
      { name: 'district', label: 'Район', type: 'text' },
    ],
  },
]
