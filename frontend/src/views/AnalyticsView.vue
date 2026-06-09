<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { analyticsQueries, type ResultColumn } from '@/config/analytics'
import { runAnalytics, listResource } from '@/api/crud'
import type { Row } from '@/api/types'

const selectedKey = ref(analyticsQueries[0].key)
const query = computed(() => analyticsQueries.find((q) => q.key === selectedKey.value)!)

const params = reactive<Row>({})
const rows = ref<Row[]>([])
const columns = ref<ResultColumn[]>([])
const loading = ref(false)
const ran = ref(false)

const refOptions = reactive<Record<string, { value: any; label: string }[]>>({})
const refLoading = reactive<Record<string, boolean>>({})

async function loadRefOptions() {
  for (const p of query.value.params) {
    if (p.type !== 'reference' || !p.refPath) continue
    const path = p.refPath
    if (refOptions[path] || refLoading[path]) continue
    refLoading[path] = true
    try {
      const items: Row[] = []
      for (let pg = 1; pg <= 5; pg++) {
        const data = await listResource(path, pg, 200)
        items.push(...data.items)
        if (items.length >= data.total || data.items.length === 0) break
      }
      refOptions[path] = items.map((it) => ({
        value: it[p.refValue || 'id'],
        label: p.refLabel ? p.refLabel(it) : String(it[p.refValue || 'id']),
      }))
    } catch {
      refOptions[path] = []
    } finally {
      refLoading[path] = false
    }
  }
}

function fmtCell(col: ResultColumn, value: any): string {
  if (value === null || value === undefined || value === '') return ''
  if (typeof value === 'boolean') return value ? 'Да' : 'Нет'
  if (col.options) return col.options.find((o) => o.value === value)?.label ?? String(value)
  return String(value)
}

function onSelect() {
  for (const k of Object.keys(params)) delete params[k]
  rows.value = []
  columns.value = []
  ran.value = false
  loadRefOptions()
}

async function run() {
  loading.value = true
  try {
    const clean: Row = {}
    for (const [k, v] of Object.entries(params)) {
      if (v !== '' && v !== null && v !== undefined) clean[k] = v
    }
    const data = await runAnalytics(query.value.path, clean)
    rows.value = data
    columns.value = query.value.columns.length
      ? query.value.columns
      : data.length
        ? Object.keys(data[0]).map((k) => ({ prop: k, label: k }))
        : []
    ran.value = true
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

onMounted(loadRefOptions)
</script>

<template>
  <h2 class="page-title">Аналитика — 13 запросов варианта</h2>

  <el-card style="margin: 16px 0">
    <el-form>
      <el-form-item label="Запрос">
        <el-select v-model="selectedKey" style="width: 360px" @change="onSelect">
          <el-option v-for="q in analyticsQueries" :key="q.key" :label="q.title" :value="q.key" />
        </el-select>
      </el-form-item>

      <div class="params">
        <el-form-item v-for="p in query.params" :key="p.name" :label="p.label">
          <el-input v-if="p.type === 'text'" v-model="params[p.name]" clearable style="width: 180px" />
          <el-input-number
            v-else-if="p.type === 'number'"
            v-model="params[p.name]"
            :controls="false"
            style="width: 140px"
          />
          <el-switch v-else-if="p.type === 'switch'" v-model="params[p.name]" />
          <el-select v-else-if="p.type === 'select'" v-model="params[p.name]" clearable style="width: 180px">
            <el-option v-for="o in p.options" :key="o.value" :label="o.label" :value="o.value" />
          </el-select>
          <el-select
            v-else-if="p.type === 'reference'"
            v-model="params[p.name]"
            filterable
            clearable
            :loading="refLoading[p.refPath!]"
            style="width: 220px"
          >
            <el-option
              v-for="o in refOptions[p.refPath!] || []"
              :key="o.value"
              :label="o.label"
              :value="o.value"
            />
          </el-select>
          <el-date-picker
            v-else-if="p.type === 'date'"
            v-model="params[p.name]"
            type="date"
            value-format="YYYY-MM-DD"
            style="width: 180px"
          />
        </el-form-item>
      </div>

      <el-button type="primary" :loading="loading" @click="run">Выполнить</el-button>
    </el-form>
  </el-card>

  <div class="result-meta" v-if="ran">Найдено записей: {{ rows.length }}</div>
  <el-table v-if="columns.length" :data="rows" border stripe>
    <el-table-column v-for="col in columns" :key="col.prop" :prop="col.prop" :label="col.label">
      <template #default="{ row }">{{ fmtCell(col, row[col.prop]) }}</template>
    </el-table-column>
  </el-table>
  <el-empty v-else-if="ran" description="Нет данных" />
</template>

<style scoped>
.params {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
}
.result-meta {
  margin-bottom: 8px;
  color: #606266;
}
</style>
