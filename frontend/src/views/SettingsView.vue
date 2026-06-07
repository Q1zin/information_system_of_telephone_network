<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getBillingSettings, updateBillingSettings } from '@/api/crud'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const loading = ref(false)
const form = reactive<Record<string, any>>({
  privilege_discount: 0.5,
  reconnection_fee: 0,
  penalty_daily_rate: 0,
  payment_due_day: 20,
  notice_grace_days: 2,
})

const canUpdate = () => auth.can('billing_settings:update')

async function load() {
  loading.value = true
  try {
    Object.assign(form, await getBillingSettings())
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
async function save() {
  try {
    Object.assign(form, await updateBillingSettings({ ...form }))
    ElMessage.success('Сохранено')
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
onMounted(load)
</script>

<template>
  <h2 class="page-title">Настройки биллинга</h2>
  <el-card v-loading="loading" style="margin-top: 16px; max-width: 520px">
    <el-form label-position="top">
      <el-form-item label="Скидка льготникам (доля, 0..1)">
        <el-input-number v-model="form.privilege_discount" :step="0.05" :min="0" :max="1" :controls="false" style="width: 100%" />
      </el-form-item>
      <el-form-item label="Стоимость включения">
        <el-input-number v-model="form.reconnection_fee" :min="0" :controls="false" style="width: 100%" />
      </el-form-item>
      <el-form-item label="Дневная ставка пени (доля)">
        <el-input-number v-model="form.penalty_daily_rate" :step="0.001" :min="0" :controls="false" style="width: 100%" />
      </el-form-item>
      <el-form-item label="День оплаты (число месяца)">
        <el-input-number v-model="form.payment_due_day" :min="1" :max="28" :controls="false" style="width: 100%" />
      </el-form-item>
      <el-form-item label="Отсрочка после уведомления (дней)">
        <el-input-number v-model="form.notice_grace_days" :min="0" :controls="false" style="width: 100%" />
      </el-form-item>
      <el-button v-if="canUpdate()" type="primary" @click="save">Сохранить</el-button>
    </el-form>
  </el-card>
</template>
