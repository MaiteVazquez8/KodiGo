<template>
  <div class="k-screen">
    <main class="k-container mas">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else>
        <p class="mas-titulo k-h1">Más</p>
        <p class="mas-subtitulo">Todo lo demás de Kodigo</p>

        <section class="mas-grupo">
          <RouterLink to="/perfil" class="mas-item">
            <q-icon name="person" size="20px" />
            <span>Mi Perfil</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
          <RouterLink to="/logros" class="mas-item">
            <q-icon name="emoji_events" size="20px" />
            <span>Logros</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
          <RouterLink to="/estadisticas" class="mas-item">
            <q-icon name="insights" size="20px" />
            <span>Mis Estadísticas</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
        </section>

        <section class="mas-grupo">
          <RouterLink to="/amigos" class="mas-item">
            <q-icon name="group" size="20px" />
            <span>Amigos</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
          <RouterLink to="/buscar-amigos" class="mas-item">
            <q-icon name="person_search" size="20px" />
            <span>Buscar Amigos</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
          <RouterLink to="/liga" class="mas-item">
            <q-icon name="leaderboard" size="20px" />
            <span>Liga de Honor</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
        </section>

        <section class="mas-grupo">
          <RouterLink to="/configuracion" class="mas-item">
            <q-icon name="settings" size="20px" />
            <span>Configuración</span>
            <q-icon name="chevron_right" size="20px" class="mas-flecha" />
          </RouterLink>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { usarAuth } from '@/services/auth'

const { estado } = usarAuth()
</script>

<style scoped>
.mas {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.mas-titulo {
  margin-top: var(--k-space-2);
}

.mas-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 15px;
  color: var(--k-text-2);
}

.mas-grupo {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-6);
}

.mas-item {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 15px;
  font-weight: 600;
  text-decoration: none;
}

.mas-item .q-icon {
  color: var(--k-text-2);
  flex-shrink: 0;
}

.mas-flecha {
  margin-left: auto;
  color: var(--k-text-3) !important;
}
</style>
