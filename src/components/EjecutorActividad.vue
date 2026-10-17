<template>
  <div class="activity-runner">
    <h2 class="activity-statement">{{ pregunta.enunciado }}</h2>

    <div
      v-if="tipo === 'seleccion' || tipo === 'verdadero_falso'"
      class="options"
    >
      <button
        v-for="(opcion, index) in opcionesVisibles"
        :key="opcion.id"
        type="button"
        class="option"
        :class="optionClasses(opcion)"
        :disabled="bloqueado"
        @click="seleccionarOpcion(opcion)"
      >
        <span class="option-letter k-mono">{{ letters[index] }}</span>
        <code class="option-text k-mono">{{ opcion.texto }}</code>
      </button>
    </div>

    <template v-else-if="tipo === 'completar_texto'">
      <div class="hay-instruccion">
        EscribÃ­ tu respuesta. Cualquier espaciado extra se ignora
        <span v-if="datos.estricta">, pero las mayÃºsculas y minÃºsculas cuentan</span>.
      </div>
      <input
        v-model="textoLibre"
        type="text"
        class="campo-texto k-mono"
        :disabled="bloqueado"
        autocomplete="off"
        spellcheck="false"
        placeholder="EscribÃ­ acÃ¡â€¦"
        @keydown.enter.prevent="accionPrincipal"
      />
    </template>

    <template v-else-if="tipo === 'completar_codigo'">
      <div class="codigo-libro bloq-code">
        <div class="libro-cabecera">
          <span class="libro-punto" />
          <span class="libro-punto" />
          <span class="libro-punto" />
        </div>
        <div class="libro-cuerpo">
          <template v-for="(trozo, index) in trozosCodigo" :key="index">
            <span v-if="trozo.texto" class="k-mono">{{ trozo.texto }}</span>
            <input
              v-else
              :ref="registrarRefBlanco"
              v-model="blancos[trozo.clave]"
              type="text"
              class="blanco-input k-mono"
              :class="{ 'is-lleno': blancos[trozo.clave] }"
              :disabled="bloqueado"
              autocomplete="off"
              spellcheck="false"
              :aria-label="`Completar el hueco ${index + 1}`"
              @focus="indiceBlancoActivo = trozo.clave"
              @click="limpiarBlanco(trozo.clave)"
            />
          </template>
        </div>
      </div>

      <div v-if="candidatos.length" class="candidatos">
        <button
          v-for="(candidato, index) in candidatosVisibles"
          :key="`${candidato}-${index}`"
          type="button"
          class="candidato k-mono"
          :disabled="bloqueado"
          @click="usarCandidato(candidato)"
        >
          {{ candidato }}
        </button>
      </div>
      <div v-else class="hay-instruccion">
        TocÃ¡ un hueco para borrarlo y escribÃ­ el texto que falta.
      </div>
    </template>

    <template v-else-if="tipo === 'ordenar'">
      <div class="hay-instruccion">
        OrdenÃ¡ los elementos con flechas o arrastrÃ¡ndo el Ã­tem.
      </div>
      <ol class="pasosOrden">
        <li
          v-for="(elemento, index) in elementosOrdenables"
          :key="elemento.id"
          class="paso"
          :class="{ 'is-activo': index === marcadoOrden }"
          draggable
          @dragstart="arrancarArrastre(index)"
          @dragover.prevent
          @drop="soltarArrastre(index)"
        >
          <div class="paso-orden">
            <button
              type="button"
              class="paso-btn"
              :disabled="bloqueado || index === 0"
              aria-label="Subir"
              @click="moverPaso(index, -1)"
            >
              <q-icon name="expand_less" size="16px" />
            </button>
            <button
              type="button"
              class="paso-btn"
              :disabled="bloqueado || index === elementosOrdenables.length - 1"
              aria-label="Bajar"
              @click="moverPaso(index, 1)"
            >
              <q-icon name="expand_more" size="16px" />
            </button>
          </div>
          <span class="paso-conteo k-mono">{{ index + 1 }}</span>
          <span class="paso-texto">{{ opcionesPorId[elemento.id] }}</span>
        </li>
      </ol>
    </template>

    <template v-else-if="tipo === 'relacionar'">
      <div class="hay-instruccion">
        TocÃ¡ un elemento de la izquierda y su pareja de la derecha para unirlos.
      </div>
      <div class="dos-col">
        <div class="col">
          <button
            v-for="(item, index) in columnaA"
            :key="item.id"
            type="button"
            class="par pill-a"
            :class="parClases(item.id, 'a')"
            :disabled="bloqueado"
            @click="elegirPar(item.id, 'a')"
          >
            <span class="par-letra">{{ index + 1 }}</span>
            <span>{{ item.texto }}</span>
          </button>
        </div>
        <div class="col">
          <button
            v-for="(item, index) in columnaB"
            :key="item.id"
            type="button"
            class="par pill-b"
            :class="parClases(item.id, 'b')"
            :disabled="bloqueado"
            @click="elegirPar(item.id, 'b')"
          >
            <span class="par-letra">{{ letras[index] }}</span>
            <span>{{ item.texto }}</span>
          </button>
        </div>
      </div>
    </template>

    <transition name="fade">
      <div v-if="devolucion" class="feedback" :class="feedbackClass">
        <q-icon :name="feedbackIcona" size="20px" />
        <div class="feedback-body">
          <strong>{{ feedbackTitulo }}</strong>
          <p>{{ feedbackMensaje }}</p>
        </div>
      </div>
    </transition>

    <button
      type="button"
      class="k-btn k-btn--primary k-btn--block action-main"
      :disabled="!puedeAccionar"
      @click="accionPrincipal"
    >
      <q-spinner v-if="corrigiendo" size="19px" class="on-left" color="white" />
      <q-icon
        v-else
        :name="actionLabel === 'Siguiente' ? 'chevron_right' : 'play_arrow'"
        size="19px"
      />
      {{ actionLabel }}
    </button>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  pregunta: {
    type: Object,
    required: false,
    default: null,
  },
  corrigiendo: {
    type: Boolean,
    default: false,
  },
  devolucion: {
    type: Object,
    default: null,
  },
  // Semilla de mezcla estable por intento + pregunta: si el usuario recarga,
  // la actividad queda con el mismo orden mientras el intento vive.
  semilla: {
    type: String,
    default: '',
  },
})

const emit = defineEmits(['comprobar', 'siguiente'])

const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']

const tipo = computed(() => props.pregunta?.tipo ?? 'seleccion')
const datos = computed(() => props.pregunta?.datos ?? {})

const seleccionId = ref(null)
const textoLibre = ref('')
const blancos = ref({})
const indiceBlancoActivo = ref(null)
const ordenElementos = ref([])
const paresFormados = ref({})
const lateralPivot = ref(null)
const marcadoOrden = ref(-1)

const respuestaLockeada = computed(() => Boolean(props.devolucion))

const bloqueado = computed(() => props.corrigiendo || respuestaLockeada.value)

const opciones = computed(() =>
  (props.pregunta?.opciones ?? []).map((o) => ({ ...o })),
)

const opcionesPorId = computed(() => {
  const mapa = {}
  opciones.value.forEach((o) => {
    mapa[o.id] = o.texto
  })
  return mapa
})

// ---------------------------------------------------------------------------
// Mezcla aleatoria estable: PRNG con semilla por intento + pregunta, para que
// recargar no rebaraje el mismo intento pero intentos distintos si cambien.
// ---------------------------------------------------------------------------

function generarRuido(str) {
  let h = 1779033703 ^ str.length
  for (let i = 0; i < str.length; i += 1) {
    h = Math.imul(h ^ str.charCodeAt(i), 3432918353)
    h = (h << 13) | (h >>> 19)
  }
  return function aleatorio() {
    h = Math.imul(h ^ (h >>> 16), 2246822507)
    h = Math.imul(h ^ (h >>> 13), 3266489909)
    h ^= h >>> 16
    return (h >>> 0) / 4294967296
  }
}

function mezclarConSemilla(lista, semillaExtra) {
  const result = lista.map((item) => item)
  const aleatorio = generarRuido(
    `${props.semilla}:${props.pregunta?.id ?? 'sin-pregunta'}:${semillaExtra}`,
  )
  for (let i = result.length - 1; i > 0; i -= 1) {
    const j = Math.floor(aleatorio() * (i + 1))
    const tmp = result[i]
    result[i] = result[j]
    result[j] = tmp
  }
  return result
}

const opcionesVisibles = computed(() => {
  if (tipo.value !== 'seleccion') return opciones.value
  return mezclarConSemilla(opciones.value, 'opciones')
})

// ---------------------------------------------------------------------------
// Completar el cÃ³digo: trozos de cÃ³digo con los blancos visibles y chips con
// los tokens candidatos (mezclados; la solucion correcta nunca viaja al cliente).
// ---------------------------------------------------------------------------

const blancosDefinidos = computed(() =>
  Array.isArray(datos.value.blancos) ? datos.value.blancos : [],
)

const trozosCodigo = computed(() => {
  const codigo = datos.value.codigo || ''
  const trozos = []
  const regex = /\{(\w+)\}/g
  let ultimo = 0
  let match = regex.exec(codigo)
  while (match) {
    if (match.index > ultimo) trozos.push({ texto: codigo.slice(ultimo, match.index) })
    trozos.push({ clave: match[1] })
    ultimo = match.index + match[0].length
    match = regex.exec(codigo)
  }
  if (ultimo < codigo.length) trozos.push({ texto: codigo.slice(ultimo) })
  return trozos
})

const candidatosVisibles = computed(() => {
  const candidatos = Array.isArray(datos.value.candidatos) ? datos.value.candidatos : []
  return mezclarConSemilla(candidatos, 'candidatos')
})

const candidatos = computed(() =>
  Array.isArray(datos.value.candidatos) ? datos.value.candidatos : [],
)

const refsBlancos = ref([])

function registrarRefBlanco(el) {
  if (el) refsBlancos.value.push(el)
  return el
}

watch(
  () => props.pregunta?.id,
  () => {
    refsBlancos.value = []
    seleccionId.value = null
    textoLibre.value = ''
    blancos.value = {}
    indiceBlancoActivo.value = null
    paresFormados.value = {}
    lateralPivot.value = null
    marcadoOrden.value = -1
    ordenElementos.value = mezclarConSemilla(
      opciones.value.map((o) => o.id),
      'orden',
    )
  },
  { immediate: true },
)

function usarCandidato(candidato) {
  const clave = indiceBlancoActivo.value || blancosDefinidos.value[0]?.clave
  if (!clave || bloqueado.value) return
  blancos.value[clave] = candidato
}

function limpiarBlanco(clave) {
  if (blancos.value[clave] && !bloqueado.value) {
    blancos.value[clave] = ''
  }
}

// ---------------------------------------------------------------------------
// Ordenar: mezcla inicial estable; se ordena con botones o arrastando.
// ---------------------------------------------------------------------------

const elementosOrdenables = computed(() =>
  ordenElementos.value.map((id) => ({ id })),
)

function moverPaso(index, delta) {
  const nuevo = Math.min(Math.max(index + delta, 0), ordenElementos.value.length - 1)
  if (nuevo === index) return
  const lista = ordenElementos.value
  const item = lista[index]
  lista.splice(index, 1)
  lista.splice(nuevo, 0, item)
}

let indexArrastre = null

function arrancarArrastre(index) {
  indexArrastre = index
}

function soltarArrastre(destino) {
  if (indexArrastre === null || indexArrastre === destino) return
  const lista = ordenElementos.value
  const item = lista[indexArrastre]
  lista.splice(indexArrastre, 1)
  lista.splice(destino, 0, item)
  indexArrastre = null
}

// ---------------------------------------------------------------------------
// Relacionar: dos columnas, tap una opciÃ³n de cada lado para formar un par.
// ---------------------------------------------------------------------------

const columnaA = computed(() =>
  mezclarConSemilla(datos.value.columna_a || [], 'colA'),
)

const columnaB = computed(() =>
  mezclarConSemilla(datos.value.columna_b || [], 'colB'),
)

function elegirPar(id, lado) {
  if (bloqueado.value) return
  if (lado === 'a') {
    lateralPivot.value = lateralPivot.value === id ? null : id
    return
  }

  const idA = lateralPivot.value
  if (!idA) return

  // Si la pareja B ya esta unida a otro elemento, se recablea: unicamente un
  // par por lado y tocar de nuevo la misma B deshace la union.
  const ocupadaPor = Object.entries(paresFormados.value).find(([, idB]) => idB === id)
  if (ocupadaPor) {
    if (ocupadaPor[0] === idA) {
      delete paresFormados.value[idA]
      lateralPivot.value = null
      return
    }
    delete paresFormados.value[ocupadaPor[0]]
  }
  paresFormados.value[idA] = id
  lateralPivot.value = null
}

function parClases(item, lado) {
  const unido =
    lado === 'a'
      ? Boolean(paresFormados.value[item])
      : Object.values(paresFormados.value).includes(item)

  return {
    'is-par': unido,
    'is-activo': lateralPivot.value === item,
  }
}

// ---------------------------------------------------------------------------
// Resumen de acciones
// ---------------------------------------------------------------------------

const hayRespuesta = computed(() => {
  if (tipo.value === 'seleccion' || tipo.value === 'verdadero_falso') {
    return seleccionId.value !== null
  }
  if (tipo.value === 'completar_texto') {
    return textoLibre.value.trim().length > 0
  }
  if (tipo.value === 'completar_codigo') {
    return blancosDefinidos.value.every((b) => (blancos.value[b.clave] ?? '').length > 0)
  }
  if (tipo.value === 'ordenar') {
    return ordenElementos.value.length > 0
  }
  if (tipo.value === 'relacionar') {
    return Object.keys(paresFormados.value).length === (datos.value.columna_a?.length ?? 0)
  }
  return false
})

const puedeAccionar = computed(() => {
  if (props.corrigiendo) return false
  if (respuestaLockeada.value) return true
  return hayRespuesta.value
})

const actionLabel = computed(() => {
  if (props.corrigiendo) return 'Comprobandoâ€¦'
  if (respuestaLockeada.value && props.devolucion?.estado === 'error') return 'Reintentar'
  if (respuestaLockeada.value) return 'Siguiente'
  return 'Comprobar'
})

const feedbackClass = computed(() => {
  if (!props.devolucion) return ''
  if (props.devolucion.estado === 'correcta') return 'is-correct'
  if (props.devolucion.estado === 'error') return 'is-neutral'
  return 'is-wrong'
})

const feedbackIcona = computed(() => {
  if (props.devolucion?.estado === 'correcta') return 'check_circle'
  if (props.devolucion?.estado === 'error') return 'error_outline'
  return 'cancel'
})

const feedbackTitulo = computed(() => {
  if (props.devolucion?.estado === 'correcta') return 'Correcto'
  if (props.devolucion?.estado === 'error') return 'No se pudo comprobar'
  return 'Incorrecto'
})

const feedbackMensaje = computed(() => {
  if (props.devolucion?.estado === 'error') {
    return (
      props.devolucion.mensaje ||
      'Hubo un problema al comprobar tu respuesta. ReintentÃ¡ o revisÃ¡ tu conexiÃ³n.'
    )
  }
  return props.devolucion?.explicacion || ''
})

function seleccionarOpcion(opcion) {
  if (bloqueado.value) return
  seleccionId.value = opcion.id
}

function optionClasses(opcion) {
  const clases = { 'is-selected': seleccionId.value === opcion.id }
  if (!props.devolucion) return clases
  if (props.devolucion.estado === 'error') return clases
  return {
    ...clases,
    'is-correct': seleccionId.value === opcion.id && props.devolucion.estado === 'correcta',
    'is-wrong': seleccionId.value === opcion.id && props.devolucion.estado === 'incorrecta',
  }
}

function cuerpoRespuesta() {
  if (tipo.value === 'seleccion' || tipo.value === 'verdadero_falso') {
    return { opcion_id: seleccionId.value }
  }
  if (tipo.value === 'completar_texto') {
    return { valor: textoLibre.value }
  }
  if (tipo.value === 'completar_codigo') {
    return { blancos: { ...blancos.value } }
  }
  if (tipo.value === 'ordenar') {
    return { orden: [...ordenElementos.value] }
  }
  if (tipo.value === 'relacionar') {
    return {
      pares: Object.entries(paresFormados.value).map(([id_a, id_b]) => ({ id_a, id_b })),
    }
  }
  return null
}

function accionPrincipal() {
  if (props.corrigiendo) return
  if (respuestaLockeada.value && props.devolucion?.estado === 'error') {
    emit('comprobar', cuerpoRespuesta())
    return
  }
  if (respuestaLockeada.value) {
    emit('siguiente')
    return
  }
  if (hayRespuesta.value) {
    emit('comprobar', cuerpoRespuesta())
  }
}
</script>

<style scoped>
.activity-runner {
  display: grid;
  gap: var(--k-space-4);
}

.activity-statement {
  font-size: 18px;
  font-weight: 700;
  line-height: 1.45;
  white-space: pre-wrap;
}

.hay-instruccion {
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.options {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.option {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
  padding: 14px 16px;
  border-radius: 16px;
  border: 2px solid var(--k-line);
  background: linear-gradient(180deg, rgba(24, 9, 31, 0.96), rgba(12, 6, 17, 1));
  color: var(--k-text);
  cursor: pointer;
  text-align: left;
  transition:
    border-color 0.12s ease,
    background 0.12s ease,
    transform 0.08s ease;
  -webkit-tap-highlight-color: transparent;
}

.option:disabled {
  cursor: default;
}

.option-letter {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  flex-shrink: 0;
  border-radius: 9px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  font-size: 13px;
  font-weight: 600;
  color: var(--k-text-2);
}

.option-text {
  font-size: 13px;
  color: var(--k-text);
  white-space: pre-wrap;
  word-break: break-word;
}

.option.is-selected {
  border-color: var(--k-accent);
  background: var(--k-accent-soft);
}

.option.is-selected .option-letter {
  border-color: var(--k-accent);
  color: var(--k-accent);
}

.option.is-correct {
  border-color: var(--k-success);
  background: rgba(52, 211, 153, 0.12);
}

.option.is-correct .option-letter {
  border-color: var(--k-success);
  color: var(--k-success);
}

.option.is-wrong {
  border-color: var(--k-error);
  background: rgba(255, 93, 115, 0.1);
}

.option.is-wrong .option-letter {
  border-color: var(--k-error);
  color: var(--k-error);
}

/* Completar el codigo */

.codigo-libro {
  border: 2px solid var(--k-accent);
  border-radius: 14px;
  overflow: hidden;
  background: rgba(12, 6, 17, 0.95);
}

.libro-cabecera {
  display: flex;
  gap: 6px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--k-line);
}

.libro-punto {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: rgba(243, 132, 245, 0.35);
}

.libro-cuerpo {
  padding: var(--k-space-4);
  font-size: 15px;
  line-height: 2.1;
  white-space: pre-wrap;
}

.blanco-input {
  display: inline-block;
  width: 90px;
  padding: 2px 10px;
  border-radius: 8px;
  border: 1px solid var(--k-accent);
  background: rgba(240, 70, 240, 0.12);
  color: var(--k-text);
  text-align: center;
}

.blanco-input.is-lleno {
  background: var(--k-accent);
  color: #0b0611;
}

.blanco-input:disabled {
  opacity: 0.75;
  cursor: default;
}

.candidatos {
  display: flex;
  flex-wrap: wrap;
  gap: var(--k-space-2);
}

.candidato {
  padding: 8px 14px;
  border-radius: 999px;
  border: 1px solid var(--k-accent);
  background: rgba(240, 70, 240, 0.1);
  color: var(--k-text);
  font-size: 13px;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.candidato:disabled {
  cursor: default;
  opacity: 0.7;
}

.campo-texto {
  width: 100%;
  padding: 14px 16px;
  border-radius: 14px;
  border: 2px solid var(--k-line);
  background: rgba(12, 6, 17, 0.95);
  color: var(--k-text);
  font-size: 15px;
}

.campo-texto:focus {
  outline: none;
  border-color: var(--k-accent);
}

/* Ordenar */

.pasosOrden {
  display: grid;
  gap: var(--k-space-2);
  list-style: none;
  padding: 0;
  margin: 0;
}

.paso {
  display: flex;
  align-items: stretch;
  gap: 0;
  margin-top: var(--k-space-1);
  border: 2px solid var(--k-line);
  border-radius: 14px;
  background: linear-gradient(180deg, rgba(24, 9, 31, 0.96), rgba(12, 6, 17, 1));
}

.paso-orden {
  display: grid;
  align-content: center;
  padding: 4px;
}

.paso-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 20px;
  border-radius: 6px;
  border: none;
  background: rgba(240, 70, 240, 0.12);
  color: var(--k-text-2);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.paso-btn:disabled {
  opacity: 0.35;
  cursor: default;
}

.paso-conteo {
  align-self: center;
  padding: 0 10px;
  font-size: 13px;
  font-weight: 700;
  color: var(--k-accent);
}

.paso-texto {
  flex: 1;
  padding: 12px 12px 12px 0;
  font-size: 14px;
  color: var(--k-text);
  line-height: 1.4;
}

/* Relacionar */

.dos-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--k-space-3);
}

.col {
  display: grid;
  gap: var(--k-space-2);
  align-content: start;
}

.par {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 10px;
  border-radius: 12px;
  border: 2px solid var(--k-line);
  background: linear-gradient(180deg, rgba(24, 9, 31, 0.96), rgba(12, 6, 17, 1));
  color: var(--k-text);
  font-size: 13px;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  word-break: break-word;
}

.par .par-letra {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 1px solid var(--k-line);
  font-size: 11px;
  font-weight: 700;
  color: var(--k-text-2);
}

.par.is-par {
  border-color: var(--k-accent);
  background: rgba(240, 70, 240, 0.14);
}

.par.is-par .par-letra {
  background: var(--k-accent);
  border-color: var(--k-accent);
  color: #0b0611;
}

.par.is-activo {
  border-color: var(--k-accent);
}

.par.is-usado {
  opacity: 0.75;
}

.par:disabled {
  cursor: default;
}

.pill-a .par-letra {
  background: rgba(243, 132, 245, 0.16);
}

.pill-b .par-letra {
  background: rgba(74, 222, 128, 0.12);
}

/* Feedback */

.feedback {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
  padding: 14px 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
}

.feedback.is-correct {
  border-color: rgba(52, 211, 153, 0.4);
  background: rgba(52, 211, 153, 0.1);
}

.feedback.is-wrong {
  border-color: rgba(255, 93, 115, 0.4);
  background: rgba(255, 93, 115, 0.1);
}

.feedback.is-neutral {
  border-color: rgba(250, 204, 21, 0.4);
  background: rgba(250, 204, 21, 0.08);
}

.feedback.is-correct .q-icon {
  color: var(--k-success);
}

.feedback.is-wrong .q-icon {
  color: var(--k-error);
}

.feedback.is-neutral .q-icon {
  color: #facc14;
}

.feedback-body strong {
  display: block;
  font-size: 14px;
}

.feedback-body p {
  margin-top: var(--k-space-1);
  font-size: 13px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.action-main {
  margin-top: var(--k-space-6);
}

.action-main .on-left {
  margin-right: 8px;
}

.fade-enter-active,
.fade-leave-active {
  transition:
    opacity 0.15s ease,
    transform 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(4px);
}

@media (max-width: 480px) {
  .dos-col {
    grid-template-columns: 1fr;
  }
}
</style>
