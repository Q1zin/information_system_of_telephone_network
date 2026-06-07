<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { resources } from '@/config/resources'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const visibleResources = computed(() =>
  resources.filter((r) => auth.can(`${r.perm}:read`)),
)

async function logout() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <el-container style="height: 100%">
    <el-aside width="240px" class="aside">
      <div class="brand">📞 ГТС</div>
      <el-menu :default-active="route.path" router unique-opened>
        <el-menu-item index="/dashboard">
          <el-icon><DataLine /></el-icon><span>Главная</span>
        </el-menu-item>
        <el-sub-menu index="crud">
          <template #title><el-icon><Files /></el-icon><span>Справочники</span></template>
          <el-menu-item v-for="r in visibleResources" :key="r.key" :index="`/crud/${r.key}`">
            {{ r.title }}
          </el-menu-item>
        </el-sub-menu>
        <el-menu-item v-if="auth.can('analytics:read')" index="/analytics">
          <el-icon><TrendCharts /></el-icon><span>Аналитика</span>
        </el-menu-item>
        <el-menu-item v-if="auth.can('raw_query:run')" index="/raw-query">
          <el-icon><Cpu /></el-icon><span>SQL-консоль</span>
        </el-menu-item>
        <el-menu-item v-if="auth.can('billing_settings:read')" index="/settings">
          <el-icon><Money /></el-icon><span>Настройки биллинга</span>
        </el-menu-item>
        <el-sub-menu v-if="auth.can('user:read') || auth.can('role:read')" index="admin">
          <template #title><el-icon><Setting /></el-icon><span>Администрирование</span></template>
          <el-menu-item v-if="auth.can('user:read')" index="/admin/users">Пользователи</el-menu-item>
          <el-menu-item v-if="auth.can('role:read')" index="/admin/roles">Роли</el-menu-item>
        </el-sub-menu>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="header">
        <div />
        <div class="user">
          <el-tag v-if="auth.user?.is_superadmin" type="danger" size="small">superadmin</el-tag>
          <span>{{ auth.user?.full_name || auth.user?.username }}</span>
          <el-button text type="primary" @click="logout">Выйти</el-button>
        </div>
      </el-header>
      <el-main><router-view /></el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.aside {
  background: #fff;
  border-right: 1px solid #e6e6e6;
}
.brand {
  font-size: 20px;
  font-weight: 700;
  padding: 16px;
  color: #303133;
}
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  border-bottom: 1px solid #e6e6e6;
}
.user {
  display: flex;
  align-items: center;
  gap: 12px;
}
:deep(.el-menu) {
  border-right: none;
}
</style>
