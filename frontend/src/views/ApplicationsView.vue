<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { listApplications, provision } from '@/api/ops'
import { listResource } from '@/api/crud'
import { useAuthStore } from '@/stores/auth'
import type { Row } from '@/api/types'

const auth = useAuthStore()
const apps = ref<Row[]>([])
const pbxList = ref<Row[]>([])
const loading = ref(false)

const dialog = ref(false)
const current = ref<Row | null>(null)
const form = reactive<Record<string, any>>({ pbx_id: null, line_type: 'main' })

const canProvision = () => auth.can('queue:update')
const statusLabel: Record<string, string> = { waiting: 'в очереди', feasible: 'возможно', installed: 'установлен', rejected: 'отклонён' }

async function load() {
  loading.value = true
  try {
    apps.value = await listApplications()
    pbxList.value = (await listResource('pbx', 1, 200)).items
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
function openProvision(row: Row) {
  current.value = row
  form.pbx_id = row.desired_pbx_id || null
  form.line_type = 'main'
  dialog.value = true
}
async function doProvision() {
  if (!current.value) return
  if (!form.pbx_id) {
    ElMessage.warning('Выберите АТС')
    return
  }
  try {
    const res = await provision(current.value.id, { pbx_id: form.pbx_id, line_type: form.line_type })
    ElMessage.success(`Подключено! Выделен номер ${res.number}`)
    dialog.value = false
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
onMounted(load)
</script>

<template>
  <h2 class="page-title">Заявки на подключение</h2>
  <el-table :data="apps" v-loading="loading" border stripe style="margin-top: 16px">
    <el-table-column prop="id" label="№" width="60" />
    <el-table-column label="Заявитель">
      <template #default="{ row }">
        {{ row.applicant_last_name }} {{ row.applicant_first_name }}
        <div class="sub">{{ row.customer_login }}</div>
      </template>
    </el-table-column>
    <el-table-column label="Адрес">
      <template #default="{ row }">{{ row.district }}, {{ row.street }}, д.{{ row.house }}<span v-if="row.apartment">, кв.{{ row.apartment }}</span></template>
    </el-table-column>
    <el-table-column label="Очередь" width="110">
      <template #default="{ row }">{{ row.queue_type === 'privileged' ? 'льготная' : 'обычная' }}</template>
    </el-table-column>
    <el-table-column prop="desired_pbx_name" label="Желаемая АТС" />
    <el-table-column label="Свободно №" width="100">
      <template #default="{ row }">{{ row.free_on_desired ?? '—' }}</template>
    </el-table-column>
    <el-table-column label="Статус" width="120">
      <template #default="{ row }">
        <el-tag :type="row.status === 'installed' ? 'success' : 'warning'">{{ statusLabel[row.status] || row.status }}</el-tag>
      </template>
    </el-table-column>
    <el-table-column label="" width="140">
      <template #default="{ row }">
        <el-button v-if="canProvision() && row.status !== 'installed'" size="small" type="primary" @click="openProvision(row)">
          Подключить
        </el-button>
      </template>
    </el-table-column>
  </el-table>

  <el-dialog v-model="dialog" title="Подключение абонента" width="460px">
    <el-form label-position="top">
      <el-form-item label="АТС">
        <el-select v-model="form.pbx_id" style="width: 100%">
          <el-option v-for="p in pbxList" :key="p.id" :label="`${p.name} (${p.code})`" :value="p.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="Тип линии">
        <el-select v-model="form.line_type" style="width: 100%">
          <el-option label="Основной" value="main" />
          <el-option label="Параллельный" value="parallel" />
          <el-option label="Спаренный" value="paired" />
        </el-select>
      </el-form-item>
      <el-alert
        type="info"
        :closable="false"
        title="Будет выделен свободный номер выбранной АТС и создан абонент из данных аккаунта заявителя."
      />
    </el-form>
    <template #footer>
      <el-button @click="dialog = false">Отмена</el-button>
      <el-button type="primary" @click="doProvision">Подключить</el-button>
    </template>
  </el-dialog>
</template>

<style scoped>
.sub {
  color: #909399;
  font-size: 12px;
}
</style>
