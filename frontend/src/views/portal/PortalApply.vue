<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { apply, pbxOptions } from '@/api/portal'
import type { Row } from '@/api/types'

const router = useRouter()
const pbxList = ref<Row[]>([])
const loading = ref(false)

const form = reactive<Record<string, any>>({
  postal_index: '',
  district: '',
  street: '',
  house: '',
  apartment: '',
  desired_pbx_id: null,
})

const pbxTypeLabel: Record<string, string> = { city: 'городская', departmental: 'ведомственная', institutional: 'учрежденческая' }

async function load() {
  try {
    pbxList.value = await pbxOptions()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
async function submit() {
  if (!form.district || !form.street || !form.house) {
    ElMessage.warning('Укажите адрес (район, улица, дом)')
    return
  }
  loading.value = true
  try {
    await apply({ ...form })
    ElMessage.success('Заявка отправлена! Оператор подберёт номер.')
    router.push('/portal')
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
onMounted(load)
</script>

<template>
  <el-page-header content="Заявка на подключение телефона" @back="router.push('/portal')" />
  <el-card style="margin-top: 16px; max-width: 640px">
    <el-form label-position="top">
      <div class="grid">
        <el-form-item label="Индекс">
          <el-input v-model="form.postal_index" />
        </el-form-item>
        <el-form-item label="Район">
          <el-input v-model="form.district" />
        </el-form-item>
      </div>
      <el-form-item label="Улица">
        <el-input v-model="form.street" />
      </el-form-item>
      <div class="grid">
        <el-form-item label="Дом">
          <el-input v-model="form.house" />
        </el-form-item>
        <el-form-item label="Квартира">
          <el-input v-model="form.apartment" />
        </el-form-item>
      </div>
      <el-form-item label="Желаемая АТС (где есть свободные номера)">
        <el-select v-model="form.desired_pbx_id" clearable placeholder="любая" style="width: 100%">
          <el-option
            v-for="p in pbxList"
            :key="p.id"
            :label="`${p.name} (${pbxTypeLabel[p.pbx_type] || p.pbx_type}, свободно: ${p.free_numbers})`"
            :value="p.id"
            :disabled="p.free_numbers === 0"
          />
        </el-select>
      </el-form-item>
      <el-button type="primary" :loading="loading" @click="submit">Отправить заявку</el-button>
    </el-form>
  </el-card>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
</style>
