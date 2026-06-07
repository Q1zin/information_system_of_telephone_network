<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { overview, cities, setIntercity, makeCall, callHistory } from '@/api/portal'
import type { Row } from '@/api/types'

const route = useRoute()
const router = useRouter()
const numberId = Number(route.params.id)

const line = ref<Row | null>(null)
const cityList = ref<Row[]>([])
const history = ref<Row[]>([])
const loading = ref(false)
const busy = ref(false)

const call = reactive<Record<string, any>>({
  kind: 'intercity',
  dest_city_id: null,
  dest_number: '',
  duration_sec: 120,
})

const intercityOn = computed({
  get: () => line.value?.intercity === 'open',
  set: () => {},
})
const intercitySupported = computed(() => line.value && line.value.intercity !== 'none')

async function loadLine() {
  const data = await overview()
  line.value = (data.lines as Row[]).find((l) => l.number_id === numberId) || null
}
async function loadHistory() {
  history.value = await callHistory(numberId)
}
async function load() {
  loading.value = true
  try {
    await loadLine()
    cityList.value = (await cities()).filter((c) => !c.is_home)
    await loadHistory()
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
async function toggleIntercity(val: boolean) {
  try {
    await setIntercity(numberId, val)
    ElMessage.success(val ? 'Межгород включён' : 'Межгород отключён')
    await loadLine()
  } catch (e: any) {
    ElMessage.error(e.message)
    await loadLine()
  }
}
async function placeCall() {
  busy.value = true
  try {
    const payload: Row = { kind: call.kind, duration_sec: call.duration_sec }
    if (call.kind === 'intercity') payload.dest_city_id = call.dest_city_id
    else payload.dest_number = call.dest_number
    const res = await makeCall(numberId, payload)
    ElMessage.success(`Звонок выполнен. Стоимость: ${res.cost} ₽`)
    await loadHistory()
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    busy.value = false
  }
}
onMounted(load)
</script>

<template>
  <el-page-header :content="line ? `Линия ${line.number}` : 'Линия'" @back="router.push('/portal')" />

  <div v-loading="loading" v-if="line" class="cols">
    <div class="col">
      <el-card>
        <template #header>Тариф и услуги</template>
        <p>АТС: <b>{{ line.pbx_name }}</b></p>
        <p>Тип линии: <b>{{ line.line_type }}</b></p>
        <p>Абонентская плата: <b>{{ line.monthly_fee }} ₽/мес</b></p>
        <el-divider />
        <div class="row">
          <span>Междугородняя связь</span>
          <el-switch
            :model-value="intercityOn"
            :disabled="!intercitySupported"
            @change="(v: any) => toggleIntercity(!!v)"
          />
        </div>
        <p v-if="!intercitySupported" class="hint">Недоступно на этой АТС (замкнутая сеть)</p>
        <p v-else class="hint">Включение/выключение меняет абонентскую плату по тарифу.</p>
      </el-card>

      <el-card style="margin-top: 16px">
        <template #header>Позвонить</template>
        <el-form label-position="top">
          <el-form-item label="Тип звонка">
            <el-radio-group v-model="call.kind">
              <el-radio-button value="local">Местный</el-radio-button>
              <el-radio-button value="intercity">Межгород</el-radio-button>
            </el-radio-group>
          </el-form-item>
          <el-form-item v-if="call.kind === 'intercity'" label="Город">
            <el-select v-model="call.dest_city_id" placeholder="выберите город" style="width: 100%">
              <el-option v-for="c in cityList" :key="c.id" :label="c.name" :value="c.id" />
            </el-select>
          </el-form-item>
          <el-form-item v-else label="Номер абонента">
            <el-input v-model="call.dest_number" placeholder="например, 2100001" />
          </el-form-item>
          <el-form-item label="Длительность, сек">
            <el-input-number v-model="call.duration_sec" :min="1" :max="36000" :controls="false" style="width: 100%" />
          </el-form-item>
          <el-button type="primary" :loading="busy" @click="placeCall">📞 Позвонить</el-button>
        </el-form>
      </el-card>
    </div>

    <div class="col">
      <el-card>
        <template #header>История звонков</template>
        <el-table :data="history" size="small" max-height="520">
          <el-table-column label="Когда" width="160">
            <template #default="{ row }">{{ new Date(row.started_at).toLocaleString('ru-RU') }}</template>
          </el-table-column>
          <el-table-column label="Тип" width="100">
            <template #default="{ row }">{{ row.call_type === 'intercity' ? 'межгород' : 'местный' }}</template>
          </el-table-column>
          <el-table-column label="Куда">
            <template #default="{ row }">{{ row.dest_city || row.dest_number || '—' }}</template>
          </el-table-column>
          <el-table-column prop="duration_sec" label="Сек" width="70" />
          <el-table-column prop="cost" label="₽" width="70" />
        </el-table>
        <el-empty v-if="!history.length" :image-size="60" description="Звонков пока нет" />
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.cols {
  display: grid;
  grid-template-columns: 380px 1fr;
  gap: 16px;
  margin-top: 16px;
}
.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.hint {
  color: #909399;
  font-size: 13px;
  margin-top: 8px;
}
@media (max-width: 820px) {
  .cols {
    grid-template-columns: 1fr;
  }
}
</style>
