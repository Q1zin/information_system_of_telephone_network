<script setup lang="ts">
import { useRouter } from 'vue-router'
const router = useRouter()
</script>

<template>
  <div class="landing">
    <div class="hero">
      <div class="logo">📞</div>
      <h1>Городская телефонная сеть</h1>
      <p class="subtitle">Подключение, управление линией, междугородняя связь и оплата — онлайн</p>

      <div class="cards">
        <el-card class="choice" shadow="hover" @click="router.push('/portal')">
          <div class="emoji">👤</div>
          <h3>Личный кабинет абонента</h3>
          <p>Подать заявку на подключение, управлять тарифом, звонить и оплачивать счета.</p>
          <el-button type="primary" round>Войти / Регистрация</el-button>
        </el-card>

        <el-card class="choice" shadow="hover" @click="router.push('/staff/login')">
          <div class="emoji">🛠️</div>
          <h3>Вход для сотрудников</h3>
          <p>Операторская панель: справочники, аналитика, заявки, администрирование.</p>
          <el-button round>Войти</el-button>
        </el-card>
      </div>
    </div>
  </div>
</template>

<style scoped>
.landing {
  min-height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(160deg, #e8f0fe 0%, #f0f2f5 100%);
  padding: 24px;
}
.hero {
  text-align: center;
  max-width: 860px;
}
.logo {
  font-size: 56px;
}
h1 {
  margin: 8px 0 4px;
  font-size: 32px;
  color: #1f2d3d;
}
.subtitle {
  color: #606266;
  margin-bottom: 32px;
}
.cards {
  display: flex;
  gap: 24px;
  justify-content: center;
  flex-wrap: wrap;
}
.choice {
  width: 340px;
  cursor: pointer;
  transition: transform 0.15s;
}
.choice:hover {
  transform: translateY(-4px);
}
.choice .emoji {
  font-size: 40px;
}
.choice h3 {
  margin: 8px 0;
}
.choice p {
  color: #606266;
  min-height: 48px;
}
</style>
