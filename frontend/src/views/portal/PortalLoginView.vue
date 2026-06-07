<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useCustomerStore } from '@/stores/customer'
import { genderOptions, categoryOptions, privilegeOptions } from '@/config/enums'

const customer = useCustomerStore()
const router = useRouter()
const route = useRoute()

const tab = ref<'login' | 'register'>('login')
const loading = ref(false)

const loginForm = reactive({ login: '', password: '' })
const regForm = reactive<Record<string, any>>({
  login: '',
  password: '',
  last_name: '',
  first_name: '',
  middle_name: '',
  gender: 'male',
  birth_date: '',
  category: 'regular',
  privilege: null,
})

function go() {
  router.push((route.query.redirect as string) || '/portal')
}

async function doLogin() {
  loading.value = true
  try {
    await customer.login(loginForm.login, loginForm.password)
    go()
  } catch (e: any) {
    ElMessage.error(e.message || 'Неверный логин или пароль')
  } finally {
    loading.value = false
  }
}
async function doRegister() {
  loading.value = true
  try {
    const payload = { ...regForm }
    if (payload.category !== 'privileged') payload.privilege = null
    await customer.register(payload)
    ElMessage.success('Аккаунт создан')
    go()
  } catch (e: any) {
    ElMessage.error(e.message || 'Ошибка регистрации')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="wrap">
    <el-card class="card">
      <h2>Личный кабинет абонента</h2>
      <el-tabs v-model="tab" stretch>
        <el-tab-pane label="Вход" name="login">
          <el-form label-position="top" @submit.prevent="doLogin">
            <el-form-item label="Логин (e-mail)">
              <el-input v-model="loginForm.login" />
            </el-form-item>
            <el-form-item label="Пароль">
              <el-input v-model="loginForm.password" type="password" show-password @keyup.enter="doLogin" />
            </el-form-item>
            <el-button type="primary" :loading="loading" style="width: 100%" @click="doLogin">Войти</el-button>
          </el-form>
        </el-tab-pane>

        <el-tab-pane label="Регистрация" name="register">
          <el-form label-position="top">
            <el-form-item label="Логин (e-mail)">
              <el-input v-model="regForm.login" />
            </el-form-item>
            <el-form-item label="Пароль">
              <el-input v-model="regForm.password" type="password" show-password />
            </el-form-item>
            <div class="grid">
              <el-form-item label="Фамилия">
                <el-input v-model="regForm.last_name" />
              </el-form-item>
              <el-form-item label="Имя">
                <el-input v-model="regForm.first_name" />
              </el-form-item>
            </div>
            <el-form-item label="Отчество">
              <el-input v-model="regForm.middle_name" />
            </el-form-item>
            <div class="grid">
              <el-form-item label="Пол">
                <el-select v-model="regForm.gender" style="width: 100%">
                  <el-option v-for="o in genderOptions" :key="o.value" :label="o.label" :value="o.value" />
                </el-select>
              </el-form-item>
              <el-form-item label="Дата рождения">
                <el-date-picker v-model="regForm.birth_date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
              </el-form-item>
            </div>
            <div class="grid">
              <el-form-item label="Категория">
                <el-select v-model="regForm.category" style="width: 100%">
                  <el-option v-for="o in categoryOptions" :key="o.value" :label="o.label" :value="o.value" />
                </el-select>
              </el-form-item>
              <el-form-item v-if="regForm.category === 'privileged'" label="Льгота">
                <el-select v-model="regForm.privilege" style="width: 100%">
                  <el-option v-for="o in privilegeOptions" :key="o.value" :label="o.label" :value="o.value" />
                </el-select>
              </el-form-item>
            </div>
            <el-button type="primary" :loading="loading" style="width: 100%" @click="doRegister">
              Зарегистрироваться
            </el-button>
          </el-form>
        </el-tab-pane>
      </el-tabs>
      <div class="links">
        <router-link to="/">На главную</router-link>
        <router-link to="/staff/login">Вход для сотрудников</router-link>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: #f0f2f5;
  padding: 24px;
}
.card {
  width: 440px;
}
h2 {
  text-align: center;
  margin: 0 0 8px;
  font-size: 18px;
}
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.links {
  display: flex;
  justify-content: space-between;
  margin-top: 12px;
  font-size: 13px;
}
</style>
