<template>
  <div class="k-screen">
    <main class="k-container perfil">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else-if="!estado.usuario">
        <EstadoPantalla
          tipo="error"
          titulo="Sin sesión activa"
          mensaje="No hay una sesión para mostrar el perfil."
        />
        <RouterLink to="/acceso" class="k-btn k-btn--primary k-btn--block k-btn--lg perfil-boton">
          IR A ACCESO
        </RouterLink>
      </template>

      <template v-else>
        <header class="perfil-encabezado">
          <p class="perfil-titulo k-h1">Mi Perfil</p>
          <p class="perfil-subtitulo">{{ nombreVisible }}</p>
        </header>

        <section class="perfil-card">
          <div class="perfil-avatar" aria-hidden="true">{{ inicial }}</div>
          <p class="perfil-card-nombre">{{ nombreVisible }}</p>
          <p class="perfil-card-dato">{{ correoMostrado }}</p>
          <span class="perfil-estado" :class="esInvitadoActual ? 'es-invitado' : 'es-cuenta'">
            {{ esInvitadoActual ? 'Invitado' : 'Cuenta verificada' }}
          </span>
        </section>

        <section class="perfil-stats">
          <div class="perfil-stat">
            <p class="perfil-stat-etiqueta">NIVEL ACTUAL</p>
            <p class="perfil-stat-valor">Nivel {{ perfil?.nivel ?? 1 }}</p>
          </div>
          <div class="perfil-stat">
            <p class="perfil-stat-etiqueta">TOTAL XP</p>
            <p class="perfil-stat-valor es-acento">{{ perfil?.experiencia ?? 0 }} XP</p>
          </div>
          <div class="perfil-stat">
            <p class="perfil-stat-etiqueta">RACHA DE DÍAS</p>
            <p class="perfil-stat-valor">{{ perfil?.racha_dias ?? 0 }} Días Seguidos</p>
          </div>
<div class="perfil-stat">
        <p class="perfil-stat-etiqueta">CURSOS ACTIVOS</p>
        <p class="perfil-stat-valor">{{ cursosActivos }}</p>
      </div>
      <div class="perfil-stat">
        <p class="perfil-stat-etiqueta">CLASES APROBADAS</p>
        <p class="perfil-stat-valor">{{ resumen.aprobadas }}</p>
      </div>
      <div class="perfil-stat">
        <p class="perfil-stat-etiqueta">INTENTOS REALIZADOS</p>
        <p class="perfil-stat-valor">{{ resumen.intentos }}</p>
      </div>
        </section>

        <section v-if="esInvitadoActual" class="perfil-logros">
          <p class="perfil-logros-titulo">Tu sesión de invitado</p>
          <p class="perfil-logros-texto">
            Practicás con una sesión anónima propia. Si creás una cuenta, esta misma sesión se
            convierte en tu cuenta y conserva tu identidad y tu progreso.
          </p>
        </section>

        <section v-else class="perfil-logros">
          <p class="perfil-logros-titulo">Logros Destacados</p>
          <p v-if="!logros.length" class="perfil-logros-texto">
            Todavía no hay logros. Completá tu primera lección para desbloquearlos.
          </p>
          <ul v-else class="perfil-logros-lista">
            <li v-for="logro in logros" :key="logro.id" class="perfil-logro">
              <q-icon name="emoji_events" size="20px" />
              <div>
                <p class="perfil-logro-nombre">{{ logro.nombre }}</p>
                <p class="perfil-logro-descripcion">{{ logro.descripcion }}</p>
              </div>
            </li>
          </ul>
        </section>

        <div class="perfil-acciones">
          <RouterLink to="/configuracion" class="perfil-editar">EDITAR INFORMACIÓN</RouterLink>
          <RouterLink
            v-if="esInvitadoActual"
            to="/acceso/registro"
            class="k-btn k-btn--primary k-btn--block"
          >
            CREAR MI CUENTA
          </RouterLink>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { obtenerCursos, obtenerResumenProgreso } from '@/services/catalogo'
import { esInvitado, usarAuth } from '@/services/auth'

const { estado } = usarAuth()

const esInvitadoActual = computed(() => esInvitado(estado.usuario))
const perfil = computed(() => estado.perfil)

const cursos = ref([])
const logros = ref([])

// Lecciones aprobadas e intentos: salen del progreso guardado en Supabase,
// asi que se mantienen al recargar o entrar desde otro dispositivo.
const resumen = computed(() => obtenerResumenProgreso())

const nombreVisible = computed(() => {
  const visible = perfil.value?.nombre_visible || ''
  if (visible.trim()) return visible.trim()
  return perfil.value?.nombre_usuario || 'Invitado'
})

const inicial = computed(() => (nombreVisible.value || 'K').charAt(0).toUpperCase())

const correoMostrado = computed(() => estado.usuario?.email || 'Sesión de invitado')

const cursosActivos = computed(() => {
  const nombres = cursos.value.map((curso) => curso.nombre).filter(Boolean)
  return nombres.length ? nombres.join(', ') : '—'
})

onMounted(async () => {
  try {
    cursos.value = await obtenerCursos()
  } catch {
    cursos.value = []
  }
})
</script>

<style scoped>
.perfil {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.perfil-titulo {
  margin-top: var(--k-space-2);
}

.perfil-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 15px;
  color: var(--k-text-2);
}

.perfil-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: var(--k-space-5);
  padding: var(--k-space-6) var(--k-space-4);
  border-radius: var(--k-radius);
  border: 1px solid rgba(142, 5, 194, 0.45);
  background: rgba(24, 9, 31, 0.9);
  text-align: center;
}

.perfil-avatar {
  width: 84px;
  height: 84px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  border: 2px solid var(--k-accent);
  background: linear-gradient(180deg, #9d2ad8 0%, #7f00c7 100%);
  color: #fff;
  font-family: var(--k-font-brand);
  font-size: 38px;
  font-weight: 800;
}

.perfil-card-nombre {
  margin-top: var(--k-space-4);
  font-size: 20px;
  font-weight: 800;
}

.perfil-card-dato {
  margin-top: 2px;
  font-size: 13.5px;
  color: var(--k-text-2);
}

.perfil-estado {
  margin-top: var(--k-space-3);
  padding: 5px 12px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 800;
}

.perfil-estado.es-invitado {
  color: var(--k-text-2);
  border: 1px solid var(--k-line);
  background: rgba(255, 255, 255, 0.06);
}

.perfil-estado.es-cuenta {
  color: var(--k-success);
  border: 1px solid rgba(52, 211, 153, 0.3);
  background: rgba(52, 211, 153, 0.1);
}

.perfil-stats {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--k-space-3);
  margin-top: var(--k-space-4);
}

.perfil-stat {
  padding: var(--k-space-4) var(--k-space-3);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.perfil-stat-etiqueta {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  color: var(--k-text-3);
}

.perfil-stat-valor {
  margin-top: 4px;
  font-size: 15px;
  font-weight: 800;
}

.perfil-stat-valor.es-acento {
  color: var(--k-accent);
}

.perfil-logros {
  margin-top: var(--k-space-4);
  padding: var(--k-space-5);
  border-radius: var(--k-radius);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.perfil-logros-titulo {
  font-size: 16px;
  font-weight: 800;
}

.perfil-logros-texto {
  margin-top: var(--k-space-2);
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.perfil-logros-lista {
  margin-top: var(--k-space-3);
  display: grid;
  gap: var(--k-space-3);
}

.perfil-logro {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-3);
}

.perfil-logro .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
  margin-top: 2px;
}

.perfil-logro-nombre {
  font-size: 13.5px;
  font-weight: 800;
}

.perfil-logro-descripcion {
  font-size: 12.5px;
  color: var(--k-text-2);
}

.perfil-acciones {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-6);
}

.perfil-editar {
  display: block;
  padding: 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-accent);
  background: transparent;
  color: var(--k-accent);
  font-size: 14px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-align: center;
  text-decoration: none;
}

.perfil-acciones .k-btn {
  text-decoration: none;
}

.perfil-boton {
  margin-top: var(--k-space-5);
  text-decoration: none;
}
</style>
