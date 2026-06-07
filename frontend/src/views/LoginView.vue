<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const username = ref('admin')
const password = ref('admin')
const loading = ref(false)

async function submit() {
  loading.value = true
  try {
    await auth.login(username.value, password.value)
    router.push((route.query.redirect as string) || '/app')
  } catch (e: any) {
    ElMessage.error(e.message || 'Ошибка входа')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-wrap">
    <el-card class="login-card">
      <h2>Вход для сотрудников</h2>
      <el-form label-position="top" @submit.prevent="submit">
        <el-form-item label="Логин">
          <el-input v-model="username" />
        </el-form-item>
        <el-form-item label="Пароль">
          <el-input v-model="password" type="password" show-password @keyup.enter="submit" />
        </el-form-item>
        <el-button type="primary" :loading="loading" style="width: 100%" @click="submit">
          Войти
        </el-button>
      </el-form>
      <div class="links">
        <router-link to="/portal">Личный кабинет абонента</router-link>
        <router-link to="/">На главную</router-link>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.login-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  background: #f0f2f5;
}
.login-card {
  width: 360px;
}
.links {
  display: flex;
  justify-content: space-between;
  margin-top: 14px;
  font-size: 13px;
}
h2 {
  text-align: center;
  margin-top: 0;
  font-size: 18px;
}
</style>
