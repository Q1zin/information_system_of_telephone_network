<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
</script>

<template>
  <h2 class="page-title">Главная</h2>
  <el-card style="margin-top: 16px">
    <p>
      Добро пожаловать, <b>{{ auth.user?.full_name || auth.user?.username }}</b>.
    </p>
    <p>Информационная система городской телефонной сети (ГТС).</p>
    <el-descriptions :column="2" border style="margin-top: 12px">
      <el-descriptions-item label="Пользователь">{{ auth.user?.username }}</el-descriptions-item>
      <el-descriptions-item label="Суперадмин">{{ auth.user?.is_superadmin ? 'да' : 'нет' }}</el-descriptions-item>
      <el-descriptions-item label="Число прав">{{ auth.user?.permissions.length }}</el-descriptions-item>
    </el-descriptions>
  </el-card>
</template>
