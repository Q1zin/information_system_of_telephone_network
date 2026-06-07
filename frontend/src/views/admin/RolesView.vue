<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as adminApi from '@/api/admin'
import { useAuthStore } from '@/stores/auth'
import type { Row } from '@/api/types'

const auth = useAuthStore()
const roles = ref<Row[]>([])
const permissions = ref<Row[]>([])
const loading = ref(false)

const dialogVisible = ref(false)
const editingId = ref<number | null>(null)
const form = reactive<Row>({ name: '', description: '', permission_ids: [] as number[] })

const canCreate = () => auth.can('role:create')
const canManage = () => auth.can('rbac:manage')

async function load() {
  loading.value = true
  try {
    roles.value = await adminApi.listRoles()
    permissions.value = await adminApi.listPermissions()
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

function permIdsOf(role: Row): number[] {
  const codes: string[] = role.permissions || []
  return permissions.value.filter((p) => codes.includes(p.code)).map((p) => p.id)
}

function openCreate() {
  editingId.value = null
  Object.assign(form, { name: '', description: '', permission_ids: [] })
  dialogVisible.value = true
}
function openEdit(role: Row) {
  editingId.value = role.id
  Object.assign(form, {
    name: role.name,
    description: role.description || '',
    permission_ids: permIdsOf(role),
  })
  dialogVisible.value = true
}
async function submit() {
  try {
    let id = editingId.value
    if (id == null) {
      const res = await adminApi.createRole({ name: form.name, description: form.description })
      id = res.id
    } else {
      await adminApi.updateRole(id, { name: form.name, description: form.description })
    }
    if (canManage()) await adminApi.setRolePermissions(id!, form.permission_ids)
    ElMessage.success('Сохранено')
    dialogVisible.value = false
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
async function remove(role: Row) {
  try {
    await ElMessageBox.confirm(`Удалить роль ${role.name}?`, 'Подтверждение', { type: 'warning' })
  } catch {
    return
  }
  try {
    await adminApi.deleteRole(role.id)
    ElMessage.success('Удалено')
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}

const transferData = () => permissions.value.map((p) => ({ key: p.id, label: p.code }))

onMounted(load)
</script>

<template>
  <div class="page-toolbar">
    <h2 class="page-title">Роли и права</h2>
    <el-button v-if="canCreate()" type="primary" @click="openCreate">Добавить</el-button>
  </div>

  <el-table :data="roles" v-loading="loading" border stripe>
    <el-table-column prop="id" label="ID" width="70" />
    <el-table-column prop="name" label="Роль" width="160" />
    <el-table-column prop="description" label="Описание" />
    <el-table-column label="Системная" width="110">
      <template #default="{ row }">{{ row.is_system ? '✓' : '' }}</template>
    </el-table-column>
    <el-table-column label="Прав" width="90">
      <template #default="{ row }">{{ (row.permissions || []).length }}</template>
    </el-table-column>
    <el-table-column label="Действия" width="150" fixed="right">
      <template #default="{ row }">
        <el-button size="small" @click="openEdit(row)">Изм.</el-button>
        <el-button v-if="!row.is_system" size="small" type="danger" @click="remove(row)">Удал.</el-button>
      </template>
    </el-table-column>
  </el-table>

  <el-dialog v-model="dialogVisible" :title="editingId == null ? 'Новая роль' : 'Редактирование роли'" width="720px">
    <el-form label-position="top">
      <el-form-item label="Название">
        <el-input v-model="form.name" />
      </el-form-item>
      <el-form-item label="Описание">
        <el-input v-model="form.description" />
      </el-form-item>
      <el-form-item v-if="canManage()" label="Права">
        <el-transfer
          v-model="form.permission_ids"
          :data="transferData()"
          :titles="['Доступные', 'Назначенные']"
          filterable
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="dialogVisible = false">Отмена</el-button>
      <el-button type="primary" @click="submit">Сохранить</el-button>
    </template>
  </el-dialog>
</template>
