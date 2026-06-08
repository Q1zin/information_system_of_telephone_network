<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useCustomerStore } from '@/stores/customer'

const customer = useCustomerStore()
const router = useRouter()

async function logout() {
  await customer.logout()
  router.push('/')
}
</script>

<template>
  <div class="portal">
    <header class="topbar">
      <div class="brand" @click="router.push('/portal')">ГТС · Личный кабинет</div>
      <div class="right">
        <span class="who">{{ customer.fullName }}</span>
        <el-button text type="primary" @click="logout">Выйти</el-button>
      </div>
    </header>
    <main class="content">
      <router-view />
    </main>
  </div>
</template>

<style scoped>
.portal {
  min-height: 100%;
  background: #f0f2f5;
}
.topbar {
  height: 56px;
  background: #fff;
  border-bottom: 1px solid #e6e6e6;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
}
.brand {
  font-weight: 700;
  font-size: 18px;
  cursor: pointer;
  color: #1f2d3d;
}
.right {
  display: flex;
  align-items: center;
  gap: 12px;
}
.who {
  color: #606266;
}
.content {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px;
}
</style>
