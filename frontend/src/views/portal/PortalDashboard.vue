<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { overview, invoices, payInvoice } from '@/api/portal'
import type { Row } from '@/api/types'

const router = useRouter()
const data = ref<Row>({ lines: [], applications: [], total_debt: 0 })
const inv = ref<Row[]>([])
const loading = ref(false)

const lineTypeLabel: Record<string, string> = { main: 'основной', parallel: 'параллельный', paired: 'спаренный' }
const intercityLabel: Record<string, string> = { open: 'открыт', closed: 'закрыт', none: 'недоступен' }
const statusLabel: Record<string, string> = { waiting: 'в очереди', feasible: 'возможно', installed: 'установлен', rejected: 'отклонён' }
const invStatusType: Record<string, any> = { paid: 'success', pending: 'warning', overdue: 'danger', cancelled: 'info' }

async function load() {
  loading.value = true
  try {
    data.value = await overview()
    inv.value = await invoices()
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
async function pay(row: Row) {
  try {
    await ElMessageBox.confirm(`Оплатить счёт на ${row.amount} ₽?`, 'Оплата', { type: 'info' })
  } catch {
    return
  }
  try {
    await payInvoice(row.id)
    ElMessage.success('Счёт оплачен')
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <div class="head">
      <h2>Здравствуйте!</h2>
      <el-button type="primary" @click="router.push('/portal/apply')">＋ Подать заявку на подключение</el-button>
    </div>

    <el-alert
      v-if="Number(data.total_debt) > 0"
      :title="`К оплате: ${data.total_debt} ₽`"
      type="warning"
      :closable="false"
      show-icon
      style="margin-bottom: 16px"
    />

    <h3>Мои линии</h3>
    <div v-if="data.lines.length" class="lines">
      <el-card v-for="l in data.lines" :key="l.number_id" shadow="hover" class="line">
        <div class="num">{{ l.number }}</div>
        <div class="meta">{{ l.pbx_name }}</div>
        <div class="tags">
          <el-tag size="small">{{ lineTypeLabel[l.line_type] || l.line_type }}</el-tag>
          <el-tag size="small" :type="l.intercity === 'open' ? 'success' : 'info'">
            межгород: {{ intercityLabel[l.intercity] || l.intercity }}
          </el-tag>
        </div>
        <div class="fee">Абонплата: <b>{{ l.monthly_fee }} ₽/мес</b></div>
        <el-button type="primary" plain size="small" @click="router.push(`/portal/line/${l.number_id}`)">
          Управление линией
        </el-button>
      </el-card>
    </div>
    <el-empty v-else description="У вас пока нет подключённых линий — подайте заявку" />

    <h3 style="margin-top: 24px">Мои заявки</h3>
    <el-table v-if="data.applications.length" :data="data.applications" border>
      <el-table-column label="Адрес">
        <template #default="{ row }">{{ row.district }}, {{ row.street }}, д.{{ row.house }}<span v-if="row.apartment">, кв.{{ row.apartment }}</span></template>
      </el-table-column>
      <el-table-column prop="desired_pbx_name" label="Желаемая АТС" />
      <el-table-column label="Очередь" width="120">
        <template #default="{ row }">{{ row.queue_type === 'privileged' ? 'льготная' : 'обычная' }}</template>
      </el-table-column>
      <el-table-column label="Статус" width="130">
        <template #default="{ row }">
          <el-tag :type="row.status === 'installed' ? 'success' : 'warning'">{{ statusLabel[row.status] || row.status }}</el-tag>
        </template>
      </el-table-column>
    </el-table>
    <el-empty v-else :image-size="60" description="Заявок нет" />

    <h3 style="margin-top: 24px">Счета</h3>
    <el-table v-if="inv.length" :data="inv" border>
      <el-table-column prop="number" label="Номер" width="120" />
      <el-table-column label="Вид" width="130">
        <template #default="{ row }">{{ row.kind === 'intercity' ? 'межгород' : 'абонплата' }}</template>
      </el-table-column>
      <el-table-column label="Период" width="110">
        <template #default="{ row }">{{ row.period_month }}/{{ row.period_year }}</template>
      </el-table-column>
      <el-table-column prop="amount" label="Сумма, ₽" width="110" />
      <el-table-column label="Статус" width="120">
        <template #default="{ row }"><el-tag :type="invStatusType[row.status]">{{ row.status }}</el-tag></template>
      </el-table-column>
      <el-table-column label="" width="120">
        <template #default="{ row }">
          <el-button v-if="row.status !== 'paid'" size="small" type="success" @click="pay(row)">Оплатить</el-button>
        </template>
      </el-table-column>
    </el-table>
    <el-empty v-else :image-size="60" description="Счетов нет" />
  </div>
</template>

<style scoped>
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.lines {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
}
.line {
  width: 260px;
}
.num {
  font-size: 22px;
  font-weight: 700;
  letter-spacing: 1px;
}
.meta {
  color: #909399;
  margin-bottom: 8px;
}
.tags {
  display: flex;
  gap: 6px;
  margin-bottom: 8px;
}
.fee {
  margin-bottom: 10px;
}
</style>
