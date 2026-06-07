<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { runRawQuery } from '@/api/crud'
import type { Row } from '@/api/types'

const sql = ref('SELECT * FROM v_subscriber_full LIMIT 20')
const rows = ref<Row[]>([])
const columns = ref<string[]>([])
const loading = ref(false)
const ran = ref(false)

async function run() {
  loading.value = true
  try {
    const data = await runRawQuery(sql.value)
    rows.value = data
    columns.value = data.length ? Object.keys(data[0]) : []
    ran.value = true
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <h2 class="page-title">SQL-консоль</h2>
  <el-alert
    type="info"
    :closable="false"
    title="Разрешён один SELECT / WITH. Запрос выполняется в режиме READ ONLY с таймаутом 5 секунд."
    style="margin: 12px 0"
  />
  <el-input v-model="sql" type="textarea" :rows="6" style="font-family: monospace" />
  <el-button type="primary" :loading="loading" style="margin-top: 12px" @click="run">
    Выполнить
  </el-button>

  <div class="result-meta" v-if="ran">Найдено записей: {{ rows.length }}</div>
  <el-table v-if="columns.length" :data="rows" border stripe style="margin-top: 8px">
    <el-table-column v-for="c in columns" :key="c" :prop="c" :label="c" />
  </el-table>
  <el-empty v-else-if="ran" description="Нет данных" />
</template>

<style scoped>
.result-meta {
  margin: 12px 0 8px;
  color: #606266;
}
</style>
