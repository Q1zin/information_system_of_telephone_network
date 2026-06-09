<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { resourceByKey, type FieldDef } from '@/config/resources'
import { listResource, createResource, updateResource, deleteResource } from '@/api/crud'
import { useAuthStore } from '@/stores/auth'
import type { Row } from '@/api/types'

const route = useRoute()
const auth = useAuthStore()

const resource = computed(() => resourceByKey(route.params.resource as string))
const idKey = computed(() => resource.value?.idField || 'id')

const rows = ref<Row[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const loading = ref(false)

const dialogVisible = ref(false)
const editingId = ref<number | null>(null)
const form = reactive<Row>({})

const refOptions = reactive<Record<string, { value: any; label: string }[]>>({})
const refLoading = reactive<Record<string, boolean>>({})

const labeledFieldByProp = computed(() => {
  const m: Record<string, FieldDef> = {}
  for (const f of resource.value?.fields || []) {
    if (f.type === 'reference' || f.type === 'select') m[f.prop] = f
  }
  return m
})

function cellLabel(prop: string, value: any): string {
  if (value === null || value === undefined || value === '') return ''
  if (typeof value === 'boolean') return value ? 'Да' : 'Нет'
  const f = labeledFieldByProp.value[prop]
  if (!f) return String(value)
  if (f.type === 'reference') {
    const opt = (refOptions[f.refPath!] || []).find((o) => o.value === value)
    return opt ? opt.label : String(value)
  }
  return f.options?.find((o) => o.value === value)?.label ?? String(value)
}

async function loadRefOptions() {
  if (!resource.value) return
  const refFields = resource.value.fields.filter((f) => f.type === 'reference')
  for (const f of refFields) {
    const path = f.refPath!
    if (refOptions[path] || refLoading[path]) continue 
    refLoading[path] = true
    try {
      const items: Row[] = []
      for (let p = 1; p <= 5; p++) {
        const data = await listResource(path, p, 200)
        items.push(...data.items)
        if (items.length >= data.total || data.items.length === 0) break
      }
      refOptions[path] = items.map((it) => ({
        value: it[f.refValue || 'id'],
        label: f.refLabel ? f.refLabel(it) : String(it[f.refValue || 'id']),
      }))
    } catch {
      refOptions[path] = []
    } finally {
      refLoading[path] = false
    }
  }
}

const canCreate = computed(() => !!resource.value && auth.can(`${resource.value.perm}:create`))
const canUpdate = computed(() => !!resource.value && auth.can(`${resource.value.perm}:update`))
const canDelete = computed(() => !!resource.value && auth.can(`${resource.value.perm}:delete`))

async function load() {
  if (!resource.value) return
  loading.value = true
  try {
    const data = await listResource(resource.value.path, page.value, pageSize.value)
    rows.value = data.items
    total.value = data.total
    loadRefOptions()
  } catch (e: any) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

function clearForm() {
  for (const k of Object.keys(form)) delete form[k]
}
function openCreate() {
  editingId.value = null
  clearForm()
  loadRefOptions()
  dialogVisible.value = true
}
function openEdit(row: Row) {
  editingId.value = row[idKey.value]
  clearForm()
  Object.assign(form, row)
  loadRefOptions()
  dialogVisible.value = true
}
function isPkLocked(prop: string) {
  return editingId.value != null && prop === idKey.value
}
async function submitForm() {
  if (!resource.value) return
  try {
    if (editingId.value == null) await createResource(resource.value.path, { ...form })
    else await updateResource(resource.value.path, editingId.value, { ...form })
    ElMessage.success('Сохранено')
    dialogVisible.value = false
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}
async function remove(row: Row) {
  if (!resource.value) return
  try {
    await ElMessageBox.confirm(`Удалить запись #${row[idKey.value]}?`, 'Подтверждение', { type: 'warning' })
  } catch {
    return
  }
  try {
    await deleteResource(resource.value.path, row[idKey.value])
    ElMessage.success('Удалено')
    load()
  } catch (e: any) {
    ElMessage.error(e.message)
  }
}

function onPage(p: number) {
  page.value = p
}
function onSize(s: number) {
  pageSize.value = s
  page.value = 1
}

watch(() => route.params.resource, () => {
  page.value = 1
  for (const k of Object.keys(refOptions)) delete refOptions[k]
  load()
})
watch([page, pageSize], load)
onMounted(load)
</script>

<template>
  <div v-if="resource">
    <div class="page-toolbar">
      <h2 class="page-title">{{ resource.title }}</h2>
      <el-button v-if="canCreate" type="primary" @click="openCreate">Добавить</el-button>
    </div>

    <el-table :data="rows" v-loading="loading" border stripe>
      <el-table-column
        v-for="c in resource.columns"
        :key="c.prop"
        :prop="c.prop"
        :label="c.label"
        :width="c.width"
      >
        <template #default="{ row }">{{ cellLabel(c.prop, row[c.prop]) }}</template>
      </el-table-column>
      <el-table-column v-if="canUpdate || canDelete" label="Действия" width="150" fixed="right">
        <template #default="{ row }">
          <el-button v-if="canUpdate" size="small" @click="openEdit(row)">Изм.</el-button>
          <el-button v-if="canDelete" size="small" type="danger" @click="remove(row)">Удал.</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination
      style="margin-top: 16px"
      layout="total, sizes, prev, pager, next"
      :total="total"
      :page-size="pageSize"
      :current-page="page"
      :page-sizes="[10, 20, 50, 100]"
      @current-change="onPage"
      @size-change="onSize"
    />

    <el-dialog
      v-model="dialogVisible"
      :title="editingId == null ? 'Создание записи' : 'Редактирование записи'"
      width="540px"
    >
      <el-form label-position="top">
        <el-form-item v-for="f in resource.fields" :key="f.prop" :label="f.label">
          <el-input v-if="f.type === 'text'" v-model="form[f.prop]" :disabled="isPkLocked(f.prop)" clearable />
          <el-input v-else-if="f.type === 'textarea'" v-model="form[f.prop]" type="textarea" />
          <el-input-number
            v-else-if="f.type === 'number'"
            v-model="form[f.prop]"
            :disabled="isPkLocked(f.prop)"
            :controls="false"
            style="width: 100%"
          />
          <el-switch v-else-if="f.type === 'switch'" v-model="form[f.prop]" />
          <el-select v-else-if="f.type === 'select'" v-model="form[f.prop]" clearable style="width: 100%">
            <el-option v-for="o in f.options" :key="o.value" :label="o.label" :value="o.value" />
          </el-select>
          <el-select
            v-else-if="f.type === 'reference'"
            v-model="form[f.prop]"
            filterable
            clearable
            :loading="refLoading[f.refPath!]"
            :disabled="isPkLocked(f.prop)"
            style="width: 100%"
          >
            <el-option
              v-for="o in refOptions[f.refPath!] || []"
              :key="o.value"
              :label="o.label"
              :value="o.value"
            />
          </el-select>
          <el-date-picker
            v-else-if="f.type === 'date'"
            v-model="form[f.prop]"
            type="date"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
          <el-date-picker
            v-else-if="f.type === 'datetime'"
            v-model="form[f.prop]"
            type="datetime"
            value-format="YYYY-MM-DDTHH:mm:ssZ"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">Отмена</el-button>
        <el-button type="primary" @click="submitForm">Сохранить</el-button>
      </template>
    </el-dialog>
  </div>
  <el-empty v-else description="Ресурс не найден" />
</template>
