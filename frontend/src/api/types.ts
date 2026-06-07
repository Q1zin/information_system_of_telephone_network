export interface CurrentUser {
  id: number
  username: string
  full_name: string | null
  is_superadmin: boolean
  permissions: string[]
}

export interface Page<T> {
  items: T[]
  total: number
  page: number
  page_size: number
  total_pages: number
}

export type Row = Record<string, any>
