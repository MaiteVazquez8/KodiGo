<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Repaso</p>
      <p class="pantalla-subtitulo">Volvé a practicar las clases que ya intentaste</p>

      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'sin-sesion'"
        tipo="vacio"
        titulo="Iniciá sesión para repasar"
        mensaje="El repaso se arma con las clases de tu cuenta."
        accion-label="Ir a acceso"
        @accion="irAcceso"
      />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el repaso"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="!lecciones.length"
        tipo="vacio"
        titulo="Todavía no hay repasos"
        mensaje="Cuando termines una lección vas a poder repasarla desde acá."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <ul v-else class="repaso-lista">
        <li v-for="fila in lecciones" :key="fila.leccion_id" class="repaso-item">
          <RouterLink :to="rutaDe(fila)" class="repaso-enlace">
            <div class="repaso-datos">
              <p class="repaso-curso">{{ fila.curso_nombre }} · {{ fila.unidad_nombre }}</p>
              <p class="repaso-titulo">{{ fila.leccion_titulo }}</p>
              <p class="repaso-detalle">
                Mejor resultado {{ Math.round(fila.mejor_porcentaje) }}% ·
                {{ fila.intentos }} {{ fila.intentos === 1 ? 'intento' : 'intentos' }}
              </p>
            </div>
            <span class="repaso-estado" :class="fila.aprobada ? 'es-aprobada' : 'es-pendiente'">
              {{ fila.aprobada ? 'Aprobada' : 'A repasar' }}
            </span>
          </RouterLink>
        </li>
      </ul>
    </main>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { estado as estadoAuth } from '@/services/auth'
import { aSlug, obtenerRevision } from '@/services/catalogo'

const router = useRouter()
const estado = ref('cargando')
const mensajeError = ref('')
const lecciones = ref([])

function rutaDe(fila) {
  return {
    name: 'leccion',
    params: {
      curso: aSlug(fila.curso_nombre),
      unidad: aSlug(fila.unidad_nombre),
      leccion: aSlug(fila.leccion_titulo),
    },
  }
}

function irAcceso() {
  router.push('/acceso')
}

function verCursos() {
  router.push('/courses')
}

async function cargar() {
  if (!estadoAuth.usuario) {
    estado.value = 'sin-sesion'
    return
  }
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    lecciones.value = await obtenerRevision()
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)
</script>

<style scoped>
.pantalla {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.pantalla-titulo {
  margin-top: var(--k-space-2);
}

.pantalla-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 14px;
  color: var(--k-text-2);
}

.repaso-lista {
  margin: var(--k-space-5) 0 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: var(--k-space-3);
}

.repaso-enlace {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: inherit;
  text-decoration: none;
}

.repaso-datos {
  flex: 1;
  min-width: 0;
}

.repaso-curso {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--k-text-3);
}

.repaso-titulo {
  margin-top: 2px;
  font-size: 14.5px;
  font-weight: 800;
}

.repaso-detalle {
  margin-top: 2px;
  font-size: 12.5px;
  color: var(--k-text-2);
}

.repaso-estado {
  flex-shrink: 0;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.repaso-estado.es-aprobada {
  border: 1px solid rgba(52, 211, 153, 0.4);
  color: var(--k-success);
}

.repaso-estado.es-pendiente {
  border: 1px solid rgba(142, 5, 194, 0.45);
  color: var(--k-accent);
}
</style>
