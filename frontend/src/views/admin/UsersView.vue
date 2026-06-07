<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as adminApi from '@/api/admin'
import { useAuthStore } from '@/stores/auth'
import type { Row } from '@/api/types'

const auth = useAuthStore()
const users = ref<Row[]>([])
const roles = ref<Row[]>([])
const loading = ref(false)

const dialogVisible = ref(false)
const editingId = ref<number | null>(null)
const form = reactive<Row>({
  username: '',
  password: '',
  full_name: '',
  is_superadmin: false,
  is_active: true,
  role_ids: [] as number[],
})

const canCreate = () => auth.can('user:create')
const canUpdate = () => auth.can('user:update')
const canDelete = () => auth.can('user:delete')

async function load() {
  loading.value = true
  try {
    users.value = await adminApi.listUsers()
    roles.value = await adminApi.listRoles()
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

function roleIdsOf(u: Row): number[] {
  return roles.value.filter((r) => (u.roles || []).includes(r.name)).map((r) => r.id)
}

function openCreate() {
  editingId.value = null
  Object.assign(form, {
    username: '',
    password: '',
    full_name: '',
    is_superadmin: false,
    is_active: true,
    role_ids: [],
  })
  dialogVisible.value = true
}
function openEdit(u: Row) {
  editingId.value = u.id
  Object.assign(form, {
    username: u.username,
    password: '',
    full_name: u.full_name || '',
    is_superadmin: u.is_superadmin,
    is_active: u.is_active,
    role_ids: roleIdsOf(u),
  })
  dialogVisible.value = true
}
async function submit() {
  try {
    if (editingId.value == null) {
      await adminApi.createUser({
        username: form.username,
        password: form.password,
        full_name: form.full_name,
        is_superadmin: form.is_superadmin,
        role_ids: form.role_ids,
      })
    } else {
      const body: Row = {
        full_name: form.full_name,
        is_active: form.is_active,
        is_superadmin: form.is_superadmin,
      }
      if (form.password) body.password = form.password
      await adminApi.updateUser(editingId.value, body)
      await adminApi.setUserRoles(editingId.value, form.role_ids)
    }
    ElMessage.success('Сохранено')
    dialogVisible.value = false
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
async function remove(u: Row) {
  try {
    await ElMessageBox.confirm(`Удалить пользователя ${u.username}?`, 'Подтверждение', { type: 'warning' })
  } catch {
    return
  }
  try {
    await adminApi.deleteUser(u.id)
    ElMessage.success('Удалено')
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}

onMounted(load)
</script>

<template>
  <div class="page-toolbar">
    <h2 class="page-title">Пользователи</h2>
    <el-button v-if="canCreate()" type="primary" @click="openCreate">Добавить</el-button>
  </div>

  <el-table :data="users" v-loading="loading" border stripe>
    <el-table-column prop="id" label="ID" width="70" />
    <el-table-column prop="username" label="Логин" />
    <el-table-column prop="full_name" label="Имя" />
    <el-table-column label="Роли">
      <template #default="{ row }">
        <el-tag v-for="r in row.roles" :key="r" size="small" style="margin-right: 4px">{{ r }}</el-tag>
      </template>
    </el-table-column>
    <el-table-column label="Супер" width="80">
      <template #default="{ row }">{{ row.is_superadmin ? '✓' : '' }}</template>
    </el-table-column>
    <el-table-column label="Активен" width="90">
      <template #default="{ row }">{{ row.is_active ? '✓' : '— нет' }}</template>
    </el-table-column>
    <el-table-column v-if="canUpdate() || canDelete()" label="Действия" width="150" fixed="right">
      <template #default="{ row }">
        <el-button v-if="canUpdate()" size="small" @click="openEdit(row)">Изм.</el-button>
        <el-button v-if="canDelete()" size="small" type="danger" @click="remove(row)">Удал.</el-button>
      </template>
    </el-table-column>
  </el-table>

  <el-dialog v-model="dialogVisible" :title="editingId == null ? 'Новый пользователь' : 'Редактирование'" width="480px">
    <el-form label-position="top">
      <el-form-item label="Логин">
        <el-input v-model="form.username" :disabled="editingId != null" />
      </el-form-item>
      <el-form-item :label="editingId == null ? 'Пароль' : 'Новый пароль (если меняем)'">
        <el-input v-model="form.password" type="password" show-password />
      </el-form-item>
      <el-form-item label="Имя">
        <el-input v-model="form.full_name" />
      </el-form-item>
      <el-form-item label="Роли">
        <el-select v-model="form.role_ids" multiple style="width: 100%">
          <el-option v-for="r in roles" :key="r.id" :label="r.name" :value="r.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="Суперадмин">
        <el-switch v-model="form.is_superadmin" />
      </el-form-item>
      <el-form-item v-if="editingId != null" label="Активен">
        <el-switch v-model="form.is_active" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="dialogVisible = false">Отмена</el-button>
      <el-button type="primary" @click="submit">Сохранить</el-button>
    </template>
  </el-dialog>
</template>
