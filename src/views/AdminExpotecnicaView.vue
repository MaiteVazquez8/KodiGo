<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Panel ExpoTécnica" back="/learn">
      <template #default />
    </EncabezadoApp>

    <main class="k-container admin">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="El panel no está disponible"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'sin-acceso'"
        variant="bored"
        eyebrow="Permisos"
        titulo="Acceso solo para administradores"
        mensaje="Tu usuario no tiene alta de administrador de la ExpoTécnica. El alta se hace desde SQL en la tabla expotec_admins y el servidor es quien la verifica: si creés que te corresponde, pedí al equipo de Kodigo que ejecute el insert con tu id de usuario."
        accion-label="Volver al inicio"
        @accion="volverInicio"
      />

      <template v-else>
        <nav class="admin-tabs" aria-label="Secciones del panel">
          <button
            v-for="tab in tabs"
            :key="tab.clave"
            type="button"
            class="admin-tab"
            :class="{ 'is-activa': tabActiva === tab.clave }"
            @click="cambiarTab(tab.clave)"
          >
            {{ tab.nombre }}
          </button>
        </nav>

        <p
          v-if="mensajeAcciones"
          class="admin-msj"
          :class="{ 'is-error': hayError }"
          role="status"
        >
          {{ mensajeAcciones }}
        </p>

        <!-- ================================================================= -->
        <!-- Pestaña EVENTOS                                                    -->
        <!-- ================================================================= -->
        <section v-show="tabActiva === 'eventos'" class="admin-seccion">
          <form class="admin-form" @submit.prevent="crearEventoNuevo">
            <h2 class="admin-h2">Nuevo evento</h2>
            <input
              v-model="nuevoEvento.nombre"
              type="text"
              class="admin-campo"
              placeholder="Nombre del evento (ej. ExpoTécnica 2026)"
              maxlength="120"
            />
            <input
              v-model="nuevoEvento.descripcion"
              type="text"
              class="admin-campo"
              placeholder="Descripción (opcional)"
              maxlength="300"
            />
            <div class="admin-pareja">
              <label class="admin-par">
                <span class="admin-lbl">Desde</span>
                <input v-model="nuevoEvento.fechaInicio" type="datetime-local" class="admin-campo" />
              </label>
              <label class="admin-par">
                <span class="admin-lbl">Hasta</span>
                <input v-model="nuevoEvento.fechaFin" type="datetime-local" class="admin-campo" />
              </label>
            </div>
            <p class="admin-nota">
              El evento nace en borrador. El desafío se configura antes de activar: activar exige
              el cuestionario completo y lo congela para proteger a los participantes.
            </p>
            <button type="submit" class="k-btn k-btn--primary k-btn--block" :disabled="enviando">
              <q-icon name="add" size="18px" />
              Crear evento
            </button>
          </form>

          <div class="admin-lista">
            <div v-for="ev in eventos" :key="ev.id" class="admin-itemo">
              <div class="admin-itemo-cab">
                <strong class="admin-itemo-titulo">{{ ev.nombre }}</strong>
                <span class="admin-estado" :class="`es-${ev.estado}`">{{ ev.estado }}</span>
              </div>
              <p v-if="ev.descripcion" class="admin-itemo-detalle">{{ ev.descripcion }}</p>
              <p class="admin-itemo-fechas">{{ fechasTexto(ev) }}</p>
              <p v-if="desafioDe(ev)" class="admin-itemo-fechas">
                Desafío: {{ desafioDe(ev).nombre }}
                <em v-if="desafioDe(ev).congeladoEn" class="admin-congelado">congelado</em>
              </p>
              <div class="admin-itemo-acciones">
                <button
                  v-if="siguienteEstadoPosible(ev.estado)"
                  type="button"
                  class="admin-a-btn admin-paso"
                  :disabled="enviando"
                  @click="pasarEvento(ev)"
                >
                  Pasar a {{ siguienteEstadoPosible(ev.estado) }}
                </button>
                <button type="button" class="admin-a-btn" :disabled="enviando" @click="abrirDesafio(ev)">
                  Configurar desafío
                </button>
              </div>
            </div>
            <p v-if="!eventos.length" class="admin-vacio">Todavía no hay eventos. Creá el primero acá arriba.</p>
          </div>
        </section>

        <!-- ================================================================= -->
        <!-- Pestaña DESAFÍO                                                    -->
        <!-- ================================================================= -->
        <section v-show="tabActiva === 'desafio'" class="admin-seccion">
          <template v-if="!eventoDesafio">
            <p class="admin-vacio">
              Elegí un evento desde la pestaña de Eventos con el botón «Configurar desafío».
            </p>
          </template>

          <template v-else>
            <div class="admin-itemo-cab">
              <h2 class="admin-h2">Desafío de {{ eventoDesafio.nombre }}</h2>
              <span v-if="eventoDesafio.estado === 'activo'" class="admin-estado es-activo">
                evento activo
              </span>
            </div>

            <p v-if="desafioCongelado" class="admin-msj">
              El desafío ya tiene partidas o el evento ya se activó: está congelado y no admite
              cambios para proteger la igualdad entre los participantes.
            </p>

            <p v-else-if="desafioActual" class="admin-nota">
              Configuración vigente: {{ desafioActual.cantidadPreguntas }} preguntas ·
              {{ desafioActual.puntosPorCorrecta }} puntos por correcta ·
              {{ desafioActual.tiempoCuestionarioSeg == null ? 'cuestionario sin límite' : `cuestionario ${desafioActual.tiempoCuestionarioSeg}s` }} ·
              juego {{ desafioActual.duracionJuegoSeg }}s con {{ desafioActual.vidasJuego }} vidas ·
              intentos ilimitados por persona.
            </p>
            <p v-else class="admin-nota">Este evento todavía no tiene desafío: definilo abajo.</p>

            <form class="admin-form" :class="{ 'is-bloqueado': Boolean(desafioCongelado) }" @submit.prevent="guardarDesafio">
              <h3 class="admin-h3">Parámetros</h3>
              <input
                v-model="desafioEdicion.nombre"
                type="text"
                class="admin-campo"
                placeholder="Nombre del desafío"
                maxlength="120"
                :disabled="Boolean(desafioCongelado)"
              />
              <div class="admin-pareja">
                <label class="admin-par">
                  <span class="admin-lbl">Preguntas por partida</span>
                  <input
                    v-model.number="desafioEdicion.cantidadPreguntas"
                    type="number"
                    min="1"
                    max="50"
                    class="admin-campo"
                    :disabled="Boolean(desafioCongelado)"
                  />
                </label>
                <label class="admin-par">
                  <span class="admin-lbl">Puntos por correcta</span>
                  <input
                    v-model.number="desafioEdicion.puntosPorCorrecta"
                    type="number"
                    min="1"
                    max="10000"
                    class="admin-campo"
                    :disabled="Boolean(desafioCongelado)"
                  />
                </label>
              </div>
              <div class="admin-pareja">
                <label class="admin-par">
                  <span class="admin-lbl">Tiempo del cuestionario (seg)</span>
                  <input
                    v-model="desafioEdicion.tiempoCuestionarioSeg"
                    type="number"
                    min="30"
                    max="7200"
                    class="admin-campo"
                    placeholder="Vacío = sin límite"
                    :disabled="Boolean(desafioCongelado)"
                  />
                </label>
                <label class="admin-par">
                  <span class="admin-lbl">Duración del juego (seg)</span>
                  <input
                    v-model.number="desafioEdicion.duracionJuegoSeg"
                    type="number"
                    min="20"
                    max="900"
                    class="admin-campo"
                    :disabled="Boolean(desafioCongelado)"
                  />
                </label>
              </div>
              <div class="admin-pareja">
                <label class="admin-par">
                  <span class="admin-lbl">Vidas del juego</span>
                  <input
                    v-model.number="desafioEdicion.vidasJuego"
                    type="number"
                    min="1"
                    max="10"
                    class="admin-campo"
                    :disabled="Boolean(desafioCongelado)"
                  />
                </label>
              </div>
              <p class="admin-nota">Los intentos son ilimitados por persona: el desafío se puede repetir libremente; el mejor intento por alias es el que queda en el ranking.</p>

              <h3 class="admin-h3">Banco de actividades</h3>
              <p class="admin-nota">
                Marcá las actividades de selección que entran al sorteo. El servidor elige
                {{ desafioEdicion.cantidadPreguntas }} al azar por partida y mezcla las opciones;
                por eso conviene marcar más de la cantidad exigida.
              </p>
              <div class="admin-checks">
                <label v-for="p in banco" :key="p.id" class="admin-check">
                  <input
                    v-model="seleccionadas"
                    type="checkbox"
                    :value="p.id"
                    :disabled="Boolean(desafioCongelado)"
                  />
                  <span class="admin-check-texto">
                    {{ p.enunciado }}
                    <em class="admin-check-meta">
                      {{ p.cursoNombre }} · {{ p.leccionTitulo }} · {{ p.estadoPublicacion }}
                    </em>
                  </span>
                </label>
                <p v-if="!banco.length" class="admin-vacio">
                  No hay actividades de selección todavía: crealas desde la pestaña Contenido.
                </p>
              </div>

              <p v-if="faltaPreguntas" class="admin-msj is-error">
                Seleccionaste {{ seleccionadas.length }} de {{ desafioEdicion.cantidadPreguntas }}:
                faltan {{ faltantes }} para sortear un cuestionario completo.
              </p>

              <button
                type="submit"
                class="k-btn k-btn--primary k-btn--block"
                :disabled="enviando || Boolean(desafioCongelado) || faltaPreguntas"
              >
                <q-icon name="save" size="18px" />
                Guardar configuración del desafío
              </button>
            </form>
          </template>
        </section>

        <!-- ================================================================= -->
        <!-- Pestaña CONTENIDO                                                  -->
        <!-- ================================================================= -->
        <section v-show="tabActiva === 'contenido'" class="admin-seccion">
          <h2 class="admin-h2">Contenido del catálogo</h2>
          <p class="admin-nota">
            Publicar valida la cascada completa en el servidor: curso con unidad publicada, unidad
            con clase publicada, clase con actividad publicada y cada actividad con opciones y
            solución. Si algo falta, el servidor te dice exactamente qué.
          </p>

          <div v-for="curso in cursos" :key="curso.id" class="admin-itemo">
            <div class="admin-itemo-cab">
              <strong class="admin-itemo-titulo">{{ curso.nombre }}</strong>
              <button
                type="button"
                class="admin-pub"
                :class="etiquetaEstadoClase(curso.estado_publicacion)"
                @click="alternarEstado(curso, 'curso')"
              >
                {{ etiquetaEstadoAccion(curso.estado_publicacion) }}
              </button>
            </div>

            <div v-for="u in unidadesPorCurso[curso.id] ?? []" :key="u.id" class="admin-subitem">
              <div class="admin-itemo-cab">
                <span class="admin-itemo-titulo">{{ u.nombre }}</span>
                <button
                  type="button"
                  class="admin-pub"
                  :class="etiquetaEstadoClase(u.estado_publicacion)"
                  @click="alternarEstado(u, 'unidad')"
                >
                  {{ etiquetaEstadoAccion(u.estado_publicacion) }}
                </button>
              </div>

              <div v-for="l in leccionesPorUnidad[u.id] ?? []" :key="l.id" class="admin-subitem-2">
                <div class="admin-itemo-cab">
                  <span class="admin-itemo-titulo">{{ l.titulo }}</span>
                  <button
                    type="button"
                    class="admin-pub"
                    :class="etiquetaEstadoClase(l.estado_publicacion)"
                    @click="alternarEstado(l, 'leccion')"
                  >
                    {{ etiquetaEstadoAccion(l.estado_publicacion) }}
                  </button>
                </div>
                <button
                  type="button"
                  class="admin-a-btn"
                  @click="elegirLeccion(l)"
                >
                  Administrar actividades
                </button>
              </div>
            </div>
          </div>

          <template v-if="leccionActiva">
            <h3 class="admin-h3">Actividades de «{{ leccionActiva.titulo }}»</h3>

            <div v-for="p in preguntasLeccion" :key="p.id" class="admin-itemo">
              <div class="admin-itemo-cab">
                <strong class="admin-itemo-titulo">{{ p.enunciado }}</strong>
                <span class="admin-tipo">{{ etiquetaTipoActividad(p.tipo) }}</span>
                <button
                  type="button"
                  class="admin-pub"
                  :class="etiquetaEstadoClase(p.estado_publicacion)"
                  @click="alternarEstado(p, 'pregunta')"
                >
                  {{ etiquetaEstadoAccion(p.estado_publicacion) }}
                </button>
              </div>
              <ul v-if="p.opciones.length" class="admin-opciones">
                <li v-for="o in p.opciones" :key="o.id">
                  {{ o.texto }}
                  <em
                    v-if="solucionDe(p.id)?.opcionCorrectaId === o.id"
                    class="admin-opcion-correcta"
                  >
                    correcta
                  </em>
                </li>
              </ul>

              <form
                v-if="usaOpciones(p.tipo, p.datos)"
                class="admin-form admin-form-solucion"
                @submit.prevent="definirSolucionActual(p)"
              >
                <select v-model="nuevaSolucion.opcionId" class="admin-select" aria-label="Opción correcta">
                  <option value="" disabled>Marcar la opción correcta</option>
                  <option v-for="o in p.opciones" :key="o.id" :value="o.id">{{ o.texto }}</option>
                </select>
                <input
                  v-model="nuevaSolucion.explicacion"
                  type="text"
                  class="admin-campo"
                  placeholder="Explicación que se muestra al final del intento"
                  maxlength="400"
                />
                <button type="submit" class="admin-a-btn">Guardar solución</button>
                <button
                  v-if="solucionDe(p.id)"
                  type="button"
                  class="admin-a-btn admin-prefill"
                  @click="precargarSolucion(p.id)"
                >
                  Editar la vigente
                </button>
              </form>

              <button type="button" class="admin-a-btn" @click="editarActividad(p)">
                Editar actividad
              </button>
            </div>

            <details class="admin-detalle" :open="Boolean(actividadForm.id)">
              <summary class="admin-resumen">
                {{ actividadForm.id ? 'Editar actividad' : 'Crear actividad' }}
              </summary>
              <form class="admin-form" @submit.prevent="guardarActividadForm">
                <label class="admin-lbl" for="admin-tipo-actividad">Tipo de actividad</label>
                <select id="admin-tipo-actividad" v-model="actividadForm.tipo" class="admin-select">
                  <option v-for="t in TIPOS_ACTIVIDAD" :key="t.valor" :value="t.valor">
                    {{ t.nombre }}
                  </option>
                </select>

                <input
                  v-model="actividadForm.enunciado"
                  type="text"
                  class="admin-campo"
                  placeholder="Enunciado"
                  maxlength="400"
                />
                <textarea
                  v-model="actividadForm.instrucciones"
                  class="admin-campo admin-area"
                  rows="2"
                  placeholder="Instrucciones para resolverla (opcional)"
                  maxlength="600"
                />
                <input
                  v-model="actividadForm.explicacion"
                  type="text"
                  class="admin-campo"
                  placeholder="Explicación de la solución (obligatoria)"
                  maxlength="400"
                />

                <!-- Opciones: seleccion, verdadero_falso y salida/predecir con opciones -->
                <template v-if="tipoConOpciones">
                  <label class="admin-lbl">Opciones (una por línea)</label>
                  <textarea
                    v-model="actividadForm.opciones"
                    class="admin-campo admin-area k-mono"
                    rows="4"
                    placeholder="Opción A&#10;Opción B&#10;Opción C"
                  />
                  <label class="admin-lbl">Opción correcta</label>
                  <select v-model.number="actividadForm.indiceCorrecta" class="admin-select">
                    <option
                      v-for="(texto, indice) in lineas(actividadForm.opciones)"
                      :key="indice"
                      :value="indice"
                    >
                      {{ indice + 1 }}. {{ texto }}
                    </option>
                  </select>
                </template>

                <!-- Completar texto -->
                <template v-if="actividadForm.tipo === 'completar_texto'">
                  <label class="admin-lbl">Respuesta correcta</label>
                  <input
                    v-model="actividadForm.valor"
                    type="text"
                    class="admin-campo"
                    placeholder="Valor esperado"
                  />
                  <label class="admin-lbl">Alternativas aceptadas (separadas por coma)</label>
                  <input
                    v-model="actividadForm.alternativas"
                    type="text"
                    class="admin-campo"
                    placeholder="Ej: typeof, type of"
                  />
                  <label class="admin-check">
                    <input v-model="actividadForm.estricta" type="checkbox" />
                    Distinguir mayúsculas y minúsculas
                  </label>
                </template>

                <!-- Completar código -->
                <template v-if="actividadForm.tipo === 'completar_codigo'">
                  <label class="admin-lbl">Código base (usá {clave} para cada blanco)</label>
                  <textarea
                    v-model="actividadForm.codigo"
                    class="admin-campo admin-area k-mono"
                    rows="5"
                    placeholder="const total = {total};"
                  />
                  <label class="admin-lbl">Blancos: clave = valor | alternativa1, alternativa2</label>
                  <textarea
                    v-model="actividadForm.blancos"
                    class="admin-campo admin-area k-mono"
                    rows="3"
                    placeholder="total = 10 | diez"
                  />
                </template>

                <!-- Ordenar -->
                <template v-if="actividadForm.tipo === 'ordenar'">
                  <label class="admin-lbl">Elementos en el orden correcto (uno por línea)</label>
                  <textarea
                    v-model="actividadForm.opciones"
                    class="admin-campo admin-area k-mono"
                    rows="4"
                  />
                </template>

                <!-- Relacionar -->
                <template v-if="actividadForm.tipo === 'relacionar'">
                  <label class="admin-lbl">Pares: izquierda | derecha (uno por línea)</label>
                  <textarea
                    v-model="actividadForm.pares"
                    class="admin-campo admin-area k-mono"
                    rows="4"
                    placeholder="let | declara una variable reasignable"
                  />
                </template>

                <!-- Escribir / corregir código -->
                <template
                  v-if="actividadForm.tipo === 'escribir_codigo' || actividadForm.tipo === 'corregir_codigo'"
                >
                  <label v-if="actividadForm.tipo === 'corregir_codigo'" class="admin-lbl">
                    Código con errores (punto de partida)
                  </label>
                  <textarea
                    v-if="actividadForm.tipo === 'corregir_codigo'"
                    v-model="actividadForm.codigoInicial"
                    class="admin-campo admin-area k-mono"
                    rows="5"
                  />
                  <label class="admin-lbl">Soluciones aceptadas (una por línea, opcional)</label>
                  <textarea
                    v-model="actividadForm.soluciones"
                    class="admin-campo admin-area k-mono"
                    rows="3"
                  />
                  <label class="admin-lbl">Patrones requeridos (regex, uno por línea)</label>
                  <textarea
                    v-model="actividadForm.requeridos"
                    class="admin-campo admin-area k-mono"
                    rows="2"
                    placeholder="function\\s+sumar"
                  />
                  <label class="admin-lbl">Patrones prohibidos (regex, uno por línea)</label>
                  <textarea
                    v-model="actividadForm.prohibidos"
                    class="admin-campo admin-area k-mono"
                    rows="2"
                  />
                  <label class="admin-lbl">Casos de ejemplo: entrada => esperado (uno por línea)</label>
                  <textarea
                    v-model="actividadForm.pruebas"
                    class="admin-campo admin-area k-mono"
                    rows="2"
                  />
                  <label class="admin-check">
                    <input v-model="actividadForm.estricta" type="checkbox" />
                    Comparar el código distinguiendo mayúsculas
                  </label>
                </template>

                <!-- Salida de código / predecir -->
                <template
                  v-if="actividadForm.tipo === 'salida_codigo' || actividadForm.tipo === 'predecir'"
                >
                  <label class="admin-lbl">Código a analizar</label>
                  <textarea
                    v-model="actividadForm.codigo"
                    class="admin-campo admin-area k-mono"
                    rows="4"
                  />
                  <label class="admin-lbl">Modo de respuesta</label>
                  <select v-model="actividadForm.modo" class="admin-select">
                    <option value="texto">Respuesta escrita</option>
                    <option value="opciones">Opciones</option>
                  </select>
                  <template v-if="actividadForm.modo === 'texto'">
                    <input
                      v-model="actividadForm.valor"
                      type="text"
                      class="admin-campo"
                      placeholder="Salida esperada"
                    />
                    <input
                      v-model="actividadForm.alternativas"
                      type="text"
                      class="admin-campo"
                      placeholder="Alternativas aceptadas (separadas por coma)"
                    />
                  </template>
                </template>

                <!-- Bloques -->
                <template v-if="actividadForm.tipo === 'bloques'">
                  <label class="admin-lbl">Bloques disponibles (uno por línea, incluí distractores)</label>
                  <textarea
                    v-model="actividadForm.bloques"
                    class="admin-campo admin-area k-mono"
                    rows="5"
                  />
                  <label class="admin-lbl">Orden correcto por número de bloque (ej: 1, 3, 2)</label>
                  <input
                    v-model="actividadForm.orden"
                    type="text"
                    class="admin-campo k-mono"
                    placeholder="1, 3, 2"
                  />
                </template>

                <label class="admin-lbl" for="admin-estado-actividad">Estado</label>
                <select id="admin-estado-actividad" v-model="actividadForm.estado" class="admin-select">
                  <option value="borrador">Guardar como borrador</option>
                  <option value="publicado">Publicar (valida antes)</option>
                </select>

                <div class="admin-form-acciones">
                  <button type="submit" class="admin-a-btn" :disabled="enviando">
                    {{ actividadForm.id ? 'Guardar cambios' : 'Crear actividad' }}
                  </button>
                  <button
                    v-if="actividadForm.id"
                    type="button"
                    class="admin-a-btn admin-prefill"
                    @click="resetActividadForm"
                  >
                    Cancelar edición
                  </button>
                </div>
              </form>
            </details>
          </template>
        </section>

        <!-- ================================================================= -->
        <!-- Pestaña RESULTADOS                                                 -->
        <!-- ================================================================= -->
        <section v-show="tabActiva === 'resultados'" class="admin-seccion">
          <h2 class="admin-h2">Estadísticas y reportes</h2>

          <label class="admin-lbl" for="admin-evento-reporte">Evento</label>
          <select id="admin-evento-reporte" v-model="eventoReporteId" class="admin-select">
            <option value="" disabled>Elegí un evento</option>
            <option v-for="ev in eventos" :key="ev.id" :value="ev.id">{{ ev.nombre }}</option>
          </select>

          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block"
            :disabled="!eventoReporteId || enviando"
            @click="calcularEstadisticas"
          >
            <q-icon name="insights" size="18px" />
            Calcular estadísticas
          </button>

          <template v-if="stats">
            <div class="admin-stats">
              <div class="admin-dato">
                <span class="admin-dato-valor">{{ stats.participantes }}</span>
                <span class="admin-dato-etiq">participantes</span>
              </div>
              <div class="admin-dato">
                <span class="admin-dato-valor">{{ stats.partidas }}</span>
                <span class="admin-dato-etiq">partidas</span>
              </div>
              <div class="admin-dato">
                <span class="admin-dato-valor">{{ stats.resultados_publicados }}</span>
                <span class="admin-dato-etiq">en el ranking</span>
              </div>
              <div class="admin-dato">
                <span class="admin-dato-valor">{{ formatoPromedio(stats.puntaje_promedio) }}</span>
                <span class="admin-dato-etiq">puntaje promedio</span>
              </div>
              <div class="admin-dato">
                <span class="admin-dato-valor">{{ formatoPromedio(stats.acierto_promedio) }}%</span>
                <span class="admin-dato-etiq">prom. de acierto</span>
              </div>
              <div class="admin-dato">
                <span class="admin-dato-valor">{{ formatoPromedio(stats.tiempo_cuestionario_promedio) }}</span>
                <span class="admin-dato-etiq">tiempo prom. (seg)</span>
              </div>
            </div>

            <p v-if="hayEstados" class="admin-nota">{{ estadosTexto(stats.por_estado) }}</p>
          </template>

          <div v-if="partidas.length" class="admin-lista">
            <div v-for="fila in partidas" :key="fila.partidaId" class="admin-itemo">
              <div class="admin-itemo-cab">
                <strong class="admin-itemo-titulo">{{ fila.alias }}</strong>
                <span class="admin-estado" :class="`es-${fila.estado}`">{{ fila.estado }}</span>
              </div>
              <p class="admin-itemo-detalle">
                Cuestionario: {{ fila.correctas }} correctas · {{ fila.incorrectas }} incorrectas ·
                {{ fila.puntajeCuestionario }} pts
                <template v-if="fila.tiempoCuestionarioSeg !== null">
                  · {{ fila.tiempoCuestionarioSeg }}s
                </template>
              </p>
              <p class="admin-itemo-fechas">
                Juego {{ fila.puntajeJuego }} pts · total {{ fila.puntajeTotal }} ·
                iniciada {{ fechaCorta(fila.iniciadoAt) }}
                <template v-if="fila.finalizadoAt"> · cerrada {{ fechaCorta(fila.finalizadoAt) }}</template>
              </p>
            </div>
          </div>
          <p v-else-if="stats" class="admin-vacio">Sin partidas registradas para este evento.</p>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import {
  cambiarEstadoContenido,
  cambiarEstadoEvento,
  configurarDesafio,
  crearEvento as crearEventoServicio,
  definirSolucion,
  esAdmin,
  estadisticasEvento,
  guardarActividad,
  listarBancoPreguntas,
  listarCursos,
  listarDesafios,
  listarEventos,
  listarLeccionesPorUnidad,
  listarPreguntasConOpciones,
  listarPreguntasDelDesafio,
  listarSolucionesDeLeccion,
  listarUnidadesPorCurso,
  resultadosDelEvento,
} from '@/services/expotecnica-admin'

const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const mensajeAcciones = ref('')
const hayError = ref(false)
const enviando = ref(false)

const tabActiva = ref('eventos')
const tabs = [
  { clave: 'eventos', nombre: 'Eventos' },
  { clave: 'desafio', nombre: 'Desafío' },
  { clave: 'contenido', nombre: 'Contenido' },
  { clave: 'resultados', nombre: 'Resultados' },
]

// Eventos y desafíos
const eventos = ref([])
const desafios = ref([])
const nuevoEvento = reactive({
  nombre: '',
  descripcion: '',
  fechaInicio: '',
  fechaFin: '',
})
const eventoDesafio = ref(null)
const desafioEdicion = reactive({
  nombre: '',
  cantidadPreguntas: 10,
  puntosPorCorrecta: 100,
  tiempoCuestionarioSeg: '',
  duracionJuegoSeg: 180,
  vidasJuego: 3,
})
const seleccionadas = ref([])
const banco = ref([])

// Contenido
const cursos = ref([])
const unidadesPorCurso = reactive({})
const leccionesPorUnidad = reactive({})
const leccionActiva = ref(null)
const preguntasLeccion = ref([])
const solucionesPorPregunta = reactive({})
const nuevaSolucion = reactive({ opcionId: '', explicacion: '' })

const TIPOS_ACTIVIDAD = [
  { valor: 'seleccion', nombre: 'Selección múltiple' },
  { valor: 'verdadero_falso', nombre: 'Verdadero o falso' },
  { valor: 'completar_texto', nombre: 'Completar texto' },
  { valor: 'completar_codigo', nombre: 'Completar código' },
  { valor: 'ordenar', nombre: 'Ordenar pasos' },
  { valor: 'relacionar', nombre: 'Relacionar columnas' },
  { valor: 'escribir_codigo', nombre: 'Escribir código' },
  { valor: 'corregir_codigo', nombre: 'Corregir código' },
  { valor: 'salida_codigo', nombre: 'Salida de código' },
  { valor: 'predecir', nombre: 'Predecir resultado' },
  { valor: 'bloques', nombre: 'Armar con bloques' },
]

const formularioVacio = () => ({
  id: null,
  tipo: 'seleccion',
  enunciado: '',
  instrucciones: '',
  explicacion: '',
  opciones: '',
  indiceCorrecta: 0,
  valor: '',
  alternativas: '',
  estricta: false,
  codigo: '',
  blancos: '',
  codigoInicial: '',
  soluciones: '',
  requeridos: '',
  prohibidos: '',
  pruebas: '',
  modo: 'texto',
  pares: '',
  bloques: '',
  orden: '',
  estado: 'borrador',
})

const actividadForm = reactive(formularioVacio())

const tipoConOpciones = computed(() => {
  if (actividadForm.tipo === 'seleccion' || actividadForm.tipo === 'verdadero_falso') return true
  return (
    (actividadForm.tipo === 'salida_codigo' || actividadForm.tipo === 'predecir') &&
    actividadForm.modo === 'opciones'
  )
})

// Resultados
const eventoReporteId = ref('')
const stats = ref(null)
const partidas = ref([])

const desafioActual = computed(() =>
  eventoDesafio.value
    ? desafios.value.find((d) => d.eventoId === eventoDesafio.value.id) ?? null
    : null,
)

const desafioCongelado = computed(() => {
  if (!eventoDesafio.value) return false
  if (desafioActual.value?.congeladoEn) return true
  const ev = eventos.value.find((e) => e.id === eventoDesafio.value.id)
  return ev ? ev.estado === 'activo' || ev.estado === 'cerrado' : false
})

const faltantes = computed(() =>
  Math.max(0, Number(desafioEdicion.cantidadPreguntas || 0) - seleccionadas.value.length),
)
const faltaPreguntas = computed(() => faltantes.value > 0)
const hayEstados = computed(() => Object.keys(stats.value?.por_estado ?? {}).length > 0)

function mensaje(texto, esError = false) {
  mensajeAcciones.value = texto
  hayError.value = esError
  if (!esError) {
    // El mensaje de acierto se apaga solo para no ensuciar la proxima accion.
    setTimeout(() => {
      if (mensajeAcciones.value === texto) {
        mensajeAcciones.value = ''
        hayError.value = false
      }
    }, 4000)
  }
}

// ---------------------------------------------------------------------------
// Carga inicial
// ---------------------------------------------------------------------------

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    const esAdministrador = await esAdmin()
    if (!esAdministrador) {
      estado.value = 'sin-acceso'
      return
    }

    eventos.value = await listarEventos()
    desafios.value = await listarDesafios()
    await cargarArbolContenido()
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

async function cargarArbolContenido() {
  const listaCursos = await listarCursos()
  cursos.value = listaCursos

  const unidadListas = await Promise.all(
    listaCursos.map(async (curso) => ({
      cursoId: curso.id,
      unidades: await listarUnidadesPorCurso(curso.id),
    })),
  )
  for (const lista of unidadListas) {
    unidadesPorCurso[lista.cursoId] = lista.unidades
  }

  const leccionListas = await Promise.all(
    unidadListas.flatMap((lista) =>
      lista.unidades.map(async (unidad) => ({
        unidadId: unidad.id,
        lecciones: await listarLeccionesPorUnidad(unidad.id),
      })),
    ),
  )
  for (const lista of leccionListas) {
    leccionesPorUnidad[lista.unidadId] = lista.lecciones
  }
}

onMounted(() => {
  void cargar()
})

// ---------------------------------------------------------------------------
// Eventos
// ---------------------------------------------------------------------------

function siguienteEstadoPosible(estadoActual) {
  if (estadoActual === 'borrador') return 'programado'
  if (estadoActual === 'programado') return 'activo'
  if (estadoActual === 'activo') return 'cerrado'
  return null
}

async function crearEventoNuevo() {
  const nombre = nuevoEvento.nombre.trim()
  if (!nombre) {
    mensaje('El evento necesita un nombre.', true)
    return
  }
  enviando.value = true
  try {
    await crearEventoServicio({
      nombre,
      descripcion: nuevoEvento.descripcion.trim() || null,
      fechaInicio: aIso(nuevoEvento.fechaInicio),
      fechaFin: aIso(nuevoEvento.fechaFin),
    })
    nuevoEvento.nombre = ''
    nuevoEvento.descripcion = ''
    nuevoEvento.fechaInicio = ''
    nuevoEvento.fechaFin = ''
    eventos.value = await listarEventos()
    mensaje(`Evento «${nombre}» creado en borrador.`)
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

async function pasarEvento(ev) {
  const destino = siguienteEstadoPosible(ev.estado)
  if (!destino) return
  enviando.value = true
  try {
    await cambiarEstadoEvento(ev.id, destino)
    ev.estado = destino
    desafios.value = await listarDesafios()
    mensaje(`El evento «${ev.nombre}» ahora está ${destino}.`)
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

function desafioDe(ev) {
  return desafios.value.find((d) => d.eventoId === ev.id) ?? null
}

// ---------------------------------------------------------------------------
// Desafío
// ---------------------------------------------------------------------------

async function abrirDesafio(ev) {
  eventoDesafio.value = ev
  tabActiva.value = 'desafio'
  mensajeAcciones.value = ''

  const desafio = desafioDe(ev)
  precargarEdicion(desafio)

  try {
    // El banco se refresca cada vez que entra a la pestana: si se creo una
    // actividad nueva ya esta disponible para seleccionar.
    banco.value = await listarBancoPreguntas()
    if (desafio) {
      const actuales = await listarPreguntasDelDesafio(desafio.id)
      const idsDelBanco = new Set(banco.value.map((p) => p.id))
      seleccionadas.value = actuales
        .map((f) => f.preguntaId)
        .filter((id) => idsDelBanco.has(id))
    } else {
      seleccionadas.value = []
    }
  } catch (error) {
    banco.value = []
    seleccionadas.value = []
    mensaje(error.message, true)
  }
}

function precargarEdicion(desafio) {
  desafioEdicion.nombre = desafio?.nombre || eventoDesafio.value?.nombre || 'Desafío ExpoTécnica'
  desafioEdicion.cantidadPreguntas = desafio?.cantidadPreguntas ?? 10
  desafioEdicion.puntosPorCorrecta = desafio?.puntosPorCorrecta ?? 100
  desafioEdicion.tiempoCuestionarioSeg =
    desafio?.tiempoCuestionarioSeg == null ? '' : String(desafio.tiempoCuestionarioSeg)
  desafioEdicion.duracionJuegoSeg = desafio?.duracionJuegoSeg ?? 180
  desafioEdicion.vidasJuego = desafio?.vidasJuego ?? 3
}

async function guardarDesafio() {
  if (!eventoDesafio.value) return
  const cantidad = Number(desafioEdicion.cantidadPreguntas)
  if (!Number.isFinite(cantidad) || cantidad < 1) {
    mensaje('La cantidad de preguntas debe ser de al menos 1.', true)
    return
  }
  if (seleccionadas.value.length < cantidad) {
    mensaje(`Seleccioná al menos ${cantidad} actividades del banco.`, true)
    return
  }

  enviando.value = true
  try {
    const tiempo = String(desafioEdicion.tiempoCuestionarioSeg).trim()
    await configurarDesafio(
      eventoDesafio.value.id,
      {
        nombre: desafioEdicion.nombre.trim() || eventoDesafio.value.nombre,
        cantidad_preguntas: cantidad,
        puntos_por_correcta: Number(desafioEdicion.puntosPorCorrecta),
        tiempo_cuestionario_seg: tiempo === '' ? null : Number(tiempo),
        duracion_juego_seg: Number(desafioEdicion.duracionJuegoSeg),
        vidas_juego: Number(desafioEdicion.vidasJuego),
      },
      seleccionadas.value,
    )
    desafios.value = await listarDesafios()
    precargarEdicion(desafioDe(eventoDesafio.value))
    mensaje('Configuración del desafío guardada: el servidor sorteará ' + cantidad + ' preguntas por partida.')
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

// ---------------------------------------------------------------------------
// Contenido
// ---------------------------------------------------------------------------

/** Ciclo de publicacion reutilizado para todo contenido. */
function proximoEstado(tipo, actual) {
  if (actual === 'publicado') return tipo === 'curso' ? 'oculto' : 'oculta'
  return 'publicado'
}

function etiquetaEstadoAccion(actual) {
  return actual === 'publicado' ? 'Ocultar' : 'Publicar'
}

function etiquetaEstadoClase(actual) {
  return actual === 'publicado' ? 'es-publicado' : 'es-borrador'
}

async function alternarEstado(item, tipo) {
  const destino = proximoEstado(tipo, item.estado_publicacion)
  enviando.value = true
  try {
    await cambiarEstadoContenido(tipo, item.id, destino)
    item.estado_publicacion = destino
    // El banco se refresca al cambiar estados: las actividades ocultas siguen
    // siendo seleccionables, solo pierden la marca de publicadas.
    banco.value = await listarBancoPreguntas()
    if (leccionActiva.value?.id === item.id) {
      await recargarLeccionActiva()
    }
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

async function elegirLeccion(leccion) {
  leccionActiva.value = leccion
  preguntasLeccion.value = []
  Object.keys(solucionesPorPregunta).forEach((k) => delete solucionesPorPregunta[k])
  nuevaSolucion.opcionId = ''
  nuevaSolucion.explicacion = ''
  resetActividadForm()
  await recargarLeccionActiva()
}

async function recargarLeccionActiva() {
  try {
    const id = leccionActiva.value.id
    const [lista, soluciones] = await Promise.all([
      listarPreguntasConOpciones(id),
      listarSolucionesDeLeccion(id),
    ])
    if (leccionActiva.value?.id !== id) return
    preguntasLeccion.value = lista
    for (const s of soluciones) {
      solucionesPorPregunta[s.preguntaId] = s
    }
  } catch (error) {
    mensaje(error.message, true)
  }
}

function solucionDe(preguntaId) {
  return solucionesPorPregunta[preguntaId] ?? null
}

function precargarSolucion(preguntaId) {
  const vigente = solucionDe(preguntaId)
  if (!vigente) return
  nuevaSolucion.opcionId = vigente.opcionCorrectaId
  nuevaSolucion.explicacion = vigente.explicacion
}

async function definirSolucionActual(pregunta) {
  const opcionId = nuevaSolucion.opcionId
  const explicacion = nuevaSolucion.explicacion.trim()
  if (!opcionId || !pregunta.opciones.some((o) => o.id === opcionId)) {
    mensaje('Elegí la opción correcta de la lista.', true)
    return
  }
  if (!explicacion) {
    mensaje('La explicación de la solución es obligatoria: es lo que ven los participantes al final.', true)
    return
  }
  enviando.value = true
  try {
    await definirSolucion(pregunta.id, opcionId, explicacion)
    await recargarLeccionActiva()
    mensaje('Solución guardada: sin ella la actividad no se puede publicar.')
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

function etiquetaTipoActividad(tipo) {
  return TIPOS_ACTIVIDAD.find((t) => t.valor === tipo)?.nombre ?? tipo ?? 'Actividad'
}

function usaOpciones(tipo, datos) {
  if (tipo === 'seleccion' || tipo === 'verdadero_falso') return true
  if (tipo === 'salida_codigo' || tipo === 'predecir') {
    return (datos?.modo ?? 'texto') === 'opciones'
  }
  return false
}

function lineas(texto) {
  return String(texto ?? '')
    .split(/\r?\n/)
    .map((linea) => linea.trim())
    .filter(Boolean)
}

function resetActividadForm() {
  Object.assign(actividadForm, formularioVacio())
}

function editarActividad(pregunta) {
  const solucion = solucionDe(pregunta.id)?.solucion ?? {}
  const datos = pregunta.datos ?? {}
  const opciones = (pregunta.opciones ?? []).map((o) => o.texto)

  resetActividadForm()
  actividadForm.id = pregunta.id
  actividadForm.tipo = pregunta.tipo ?? 'seleccion'
  actividadForm.enunciado = pregunta.enunciado ?? ''
  actividadForm.instrucciones = datos.instrucciones ?? ''
  actividadForm.explicacion = solucionDe(pregunta.id)?.explicacion ?? ''
  actividadForm.opciones = opciones.join('\n')
  actividadForm.indiceCorrecta = Math.max(
    0,
    (pregunta.opciones ?? []).findIndex((o) => o.id === solucionDe(pregunta.id)?.opcionCorrectaId),
  )
  actividadForm.valor = solucion.valor ?? datos.valor ?? ''
  actividadForm.alternativas = (solucion.alternativas ?? datos.alternativas ?? []).join(', ')
  actividadForm.estricta = Boolean(solucion.estricta ?? datos.estricta)
  actividadForm.codigo = datos.codigo ?? ''
  actividadForm.codigoInicial = datos.codigo_inicial ?? ''
  actividadForm.modo = datos.modo ?? 'texto'
  actividadForm.estado = pregunta.estado_publicacion ?? 'borrador'
  actividadForm.soluciones = (solucion.soluciones ?? []).join('\n')
  actividadForm.requeridos = (solucion.requeridos ?? []).join('\n')
  actividadForm.prohibidos = (solucion.prohibidos ?? []).join('\n')
  actividadForm.pruebas = (datos.pruebas ?? [])
    .map((prueba) => `${prueba.entrada ?? ''} => ${prueba.esperado ?? ''}`)
    .join('\n')

  const blancos = solucion.blancos ?? datos.blancos ?? []
  actividadForm.blancos = blancos
    .map((blanco) => {
      const alternativas = (blanco.alternativas ?? []).join(', ')
      return `${blanco.clave} = ${blanco.valor ?? ''}${alternativas ? ` | ${alternativas}` : ''}`
    })
    .join('\n')

  const textoA = Object.fromEntries((datos.columna_a ?? []).map((item) => [item.id, item.texto]))
  const textoB = Object.fromEntries((datos.columna_b ?? []).map((item) => [item.id, item.texto]))
  actividadForm.pares = (solucion.pares ?? [])
    .map((par) => `${textoA[par.id_a] ?? par.id_a} | ${textoB[par.id_b] ?? par.id_b}`)
    .join('\n')

  const bloques = datos.bloques ?? []
  actividadForm.bloques = bloques.map((bloque) => bloque.texto).join('\n')
  actividadForm.orden = (solucion.orden ?? [])
    .map((id) => {
      const indice = bloques.findIndex((bloque) => bloque.id === id)
      return indice === -1 ? '' : String(indice + 1)
    })
    .filter(Boolean)
    .join(', ')
}

function armarActividad() {
  const tipo = actividadForm.tipo
  const datos = {}
  const solucion = {}

  if (actividadForm.instrucciones.trim()) {
    datos.instrucciones = actividadForm.instrucciones.trim()
  }

  const opciones = lineas(actividadForm.opciones)
  let indiceCorrecta = 0

  if (tipoConOpciones.value) {
    if (opciones.length < 2) {
      throw new Error('La actividad necesita al menos dos opciones.')
    }
    indiceCorrecta = Number(actividadForm.indiceCorrecta)
    if (indiceCorrecta < 0 || indiceCorrecta >= opciones.length) {
      throw new Error('Elegí una opción correcta válida.')
    }
  }

  if (tipo === 'ordenar') {
    if (opciones.length < 2) throw new Error('Necesitás al menos dos elementos para ordenar.')
  }

  if (tipo === 'completar_texto') {
    solucion.valor = actividadForm.valor.trim()
    const alternativas = actividadForm.alternativas
      .split(',')
      .map((a) => a.trim())
      .filter(Boolean)
    if (alternativas.length) solucion.alternativas = alternativas
    solucion.estricta = Boolean(actividadForm.estricta)
    if (actividadForm.estricta) datos.estricta = true
    if (!solucion.valor && !alternativas.length) {
      throw new Error('Indicá la respuesta correcta o alguna alternativa.')
    }
  }

  if (tipo === 'completar_codigo') {
    datos.codigo = actividadForm.codigo
    const blancos = lineas(actividadForm.blancos).map((linea) => {
      const igual = linea.indexOf('=')
      const izquierda = igual === -1 ? linea : linea.slice(0, igual)
      const derecha = igual === -1 ? '' : linea.slice(igual + 1)
      const [valor, alternativas] = String(derecha ?? '').split('|')
      const blanco = {
        clave: String(izquierda ?? '').trim(),
        valor: String(valor ?? '').trim(),
      }
      const alts = String(alternativas ?? '')
        .split(',')
        .map((a) => a.trim())
        .filter(Boolean)
      if (alts.length) blanco.alternativas = alts
      return blanco
    })
    if (!datos.codigo.trim()) throw new Error('Falta el código base.')
    if (!blancos.length || blancos.some((b) => !b.clave || !b.valor)) {
      throw new Error('Cada blanco necesita clave y valor.')
    }
    // Presentacion sin respuestas: las claves viven en datos y los valores en
    // soluciones, que tiene RLS sin lectura para estudiantes.
    datos.blancos = blancos.map((blanco) => ({ clave: blanco.clave }))
    solucion.blancos = blancos
  }

  if (tipo === 'relacionar') {
    const filas = lineas(actividadForm.pares).map((linea) => linea.split('|'))
    if (!filas.length) throw new Error('Agregá al menos un par.')
    const columnaA = []
    const columnaB = []
    const pares = []
    for (const fila of filas) {
      const textoA = String(fila[0] ?? '').trim()
      const textoB = String(fila[1] ?? '').trim()
      if (!textoA || !textoB) throw new Error('Cada par necesita izquierda y derecha.')
      let itemA = columnaA.find((item) => item.texto === textoA)
      if (!itemA) {
        itemA = { id: `a${columnaA.length + 1}`, texto: textoA }
        columnaA.push(itemA)
      }
      let itemB = columnaB.find((item) => item.texto === textoB)
      if (!itemB) {
        itemB = { id: `b${columnaB.length + 1}`, texto: textoB }
        columnaB.push(itemB)
      }
      pares.push({ id_a: itemA.id, id_b: itemB.id })
    }
    datos.columna_a = columnaA
    datos.columna_b = columnaB
    solucion.pares = pares
  }

  if (tipo === 'escribir_codigo' || tipo === 'corregir_codigo') {
    if (tipo === 'corregir_codigo') {
      datos.codigo_inicial = actividadForm.codigoInicial
      if (!String(actividadForm.codigoInicial ?? '').trim()) {
        throw new Error('Indicá el código con errores que el estudiante va a corregir.')
      }
    }
    const soluciones = lineas(actividadForm.soluciones)
    const requeridos = lineas(actividadForm.requeridos)
    const prohibidos = lineas(actividadForm.prohibidos)
    if (!soluciones.length && !requeridos.length) {
      throw new Error('Indicá soluciones aceptadas o al menos un patrón requerido.')
    }
    if (soluciones.length) solucion.soluciones = soluciones
    if (requeridos.length) solucion.requeridos = requeridos
    if (prohibidos.length) solucion.prohibidos = prohibidos
    solucion.estricto = Boolean(actividadForm.estricta)
    const pruebas = lineas(actividadForm.pruebas).map((linea) => {
      const [entrada, esperado] = linea.split('=>')
      return { entrada: String(entrada ?? '').trim(), esperado: String(esperado ?? '').trim() }
    })
    if (pruebas.length) datos.pruebas = pruebas
  }

  if (tipo === 'salida_codigo' || tipo === 'predecir') {
    datos.codigo = actividadForm.codigo
    datos.modo = actividadForm.modo
    if (!datos.codigo.trim()) throw new Error('Falta el código a analizar.')
    if (actividadForm.modo === 'texto') {
      solucion.valor = actividadForm.valor.trim()
      const alternativas = actividadForm.alternativas
        .split(',')
        .map((a) => a.trim())
        .filter(Boolean)
      if (alternativas.length) solucion.alternativas = alternativas
      solucion.estricta = Boolean(actividadForm.estricta)
      if (!solucion.valor && !alternativas.length) {
        throw new Error('Indicá la salida esperada o alguna alternativa.')
      }
    }
  }

  if (tipo === 'bloques') {
    const textos = lineas(actividadForm.bloques)
    if (textos.length < 2) throw new Error('Necesitás al menos dos bloques disponibles.')
    const bloques = textos.map((texto, indice) => ({ id: `b${indice + 1}`, texto }))
    const orden = actividadForm.orden
      .split(',')
      .map((n) => Number.parseInt(n.trim(), 10))
      .filter((n) => Number.isInteger(n))
    if (!orden.length) throw new Error('Indicá el orden correcto de los bloques.')
    solucion.orden = orden.map((numero) => {
      const bloque = bloques[numero - 1]
      if (!bloque) throw new Error(`El bloque ${numero} no existe en la lista.`)
      return bloque.id
    })
    datos.bloques = bloques
  }

  return { datos, solucion, opciones, indiceCorrecta }
}

async function guardarActividadForm() {
  if (!leccionActiva.value) {
    mensaje('Primero elegí la clase de destino.', true)
    return
  }
  const enunciado = actividadForm.enunciado.trim()
  const explicacion = actividadForm.explicacion.trim()
  if (!enunciado) {
    mensaje('La actividad necesita enunciado.', true)
    return
  }
  if (!explicacion) {
    mensaje('La explicación es obligatoria: es lo que ve el estudiante al final.', true)
    return
  }

  let armado
  try {
    armado = armarActividad()
  } catch (error) {
    mensaje(error.message, true)
    return
  }

  enviando.value = true
  const estadoElegido = actividadForm.estado
  try {
    await guardarActividad({
      id: actividadForm.id,
      leccion_id: leccionActiva.value.id,
      tipo: actividadForm.tipo,
      enunciado,
      explicacion,
      datos: armado.datos,
      solucion: armado.solucion,
      opciones: tipoConOpciones.value ? armado.opciones : null,
      indice_correcta: tipoConOpciones.value ? armado.indiceCorrecta : null,
      estado_publicacion: estadoElegido,
    })
    await recargarLeccionActiva()
    resetActividadForm()
    mensaje(
      estadoElegido === 'publicado'
        ? 'Actividad publicada: el servidor validó la estructura y la solución.'
        : 'Actividad guardada en borrador. Podés publicarla cuando esté completa.',
    )
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

// ---------------------------------------------------------------------------
// Resultados
// ---------------------------------------------------------------------------

async function calcularEstadisticas() {
  if (!eventoReporteId.value) return
  enviando.value = true
  try {
    const [resumen, listado] = await Promise.all([
      estadisticasEvento(eventoReporteId.value),
      resultadosDelEvento(eventoReporteId.value, null, 200),
    ])
    stats.value = resumen ?? {}
    partidas.value = listado
  } catch (error) {
    mensaje(error.message, true)
  } finally {
    enviando.value = false
  }
}

function estadosTexto(porEstado) {
  const orden = ['creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego', 'finalizada', 'vencida', 'abandonada']
  const etiquetas = {
    creada: 'abiertas sin responder',
    en_cuestionario: 'respondiendo',
    cuestionario_completado: 'en el parcial',
    en_juego: 'en el juego',
    finalizada: 'finalizadas',
    vencida: 'vencidas',
    abandonada: 'abandonadas',
  }
  return orden
    .filter((k) => porEstado?.[k])
    .map((k) => `${porEstado[k]} ${etiquetas[k] ?? k}`)
    .join(' · ')
}

// ---------------------------------------------------------------------------
// Formato y utilidades
// ---------------------------------------------------------------------------

function aIso(valor) {
  if (!valor) return null
  const fecha = new Date(valor)
  return Number.isNaN(fecha.getTime()) ? null : fecha.toISOString()
}

function fechasTexto(ev) {
  if (!ev.fechaInicio && !ev.fechaFin) return 'Sin fechas: disponible siempre que esté activo.'
  const desde = ev.fechaInicio ? fechaCorta(ev.fechaInicio) : '—'
  const hasta = ev.fechaFin ? fechaCorta(ev.fechaFin) : '—'
  return `Del ${desde} al ${hasta}`
}

function fechaCorta(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  const dia = d.getDate().toString().padStart(2, '0')
  const mes = (d.getMonth() + 1).toString().padStart(2, '0')
  const anio = d.getFullYear()
  const hh = d.getHours().toString().padStart(2, '0')
  const mm = d.getMinutes().toString().padStart(2, '0')
  return `${dia}/${mes}/${anio} ${hh}:${mm}`
}

function formatoPromedio(valor) {
  return valor === null || valor === undefined || valor === '' ? '—' : String(valor)
}

function cambiarTab(clave) {
  tabActiva.value = clave
  // En pestañas de accion los mensajes viejos ya no aplican.
  mensajeAcciones.value = ''
  hayError.value = false
}

function volverInicio() {
  router.push('/learn')
}
</script>

<style scoped>
.admin {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-5);
  padding-bottom: var(--k-space-7);
}

/* Tabs ------------------------------------------------------------ */
.admin-tabs {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 6px;
}

.admin-tab {
  padding: 9px 4px;
  border-radius: var(--k-radius-sm);
  border: 0;
  background: transparent;
  color: var(--k-text-2);
  font-weight: 700;
  font-size: 12.5px;
  cursor: pointer;
  transition:
    color 0.15s ease,
    background 0.15s ease;
}

.admin-tab.is-activa {
  background: var(--k-accent-soft);
  color: #fff;
}

/* Secciones y tipografia ------------------------------------------ */
.admin-seccion {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-4);
}

.admin-h2 {
  font-size: 18px;
  font-weight: 800;
  font-family: var(--k-font-brand);
  color: var(--k-text);
  margin: 0;
}

.admin-h3 {
  font-size: 14px;
  font-weight: 700;
  color: var(--k-text-2);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin: 0;
}

/* Formularios ------------------------------------------------------ */
.admin-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius);
  padding: var(--k-space-5);
}

.admin-form.is-bloqueado {
  opacity: 0.55;
  pointer-events: none;
}

.admin-par {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 1;
  min-width: 0;
}

.admin-pareja {
  display: flex;
  gap: 10px;
}

.admin-campo {
  width: 100%;
  padding: 11px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 14px;
  outline: none;
  font-family: var(--k-font);
}

.admin-campo:focus {
  border-color: var(--k-accent);
}

.admin-lbl {
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-2);
}

.admin-select {
  width: 100%;
  padding: 10px 12px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 14px;
  outline: none;
}

/* Listas ----------------------------------------------------------- */
.admin-lista {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.admin-itemo {
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 14px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.admin-itemo-cab {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.admin-itemo-titulo {
  font-size: 14.5px;
  color: var(--k-text);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-itemo-detalle {
  font-size: 13px;
  color: var(--k-text-2);
  line-height: 1.55;
  margin: 0;
}

.admin-itemo-fechas {
  font-size: 12px;
  color: var(--k-text-3);
  margin: 0;
}

.admin-itemo-acciones {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.admin-subitem {
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 10px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.admin-subitem-2 {
  border: 1px dashed var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

/* Estados ---------------------------------------------------------- */
.admin-estado,
.admin-pub {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  border-radius: 999px;
  padding: 4px 10px;
  flex-shrink: 0;
}

.admin-estado.es-borrador,
.admin-pub.es-borrador {
  background: var(--k-accent-softer);
  color: var(--k-text-2);
}

.admin-estado.es-programado {
  background: rgba(112, 11, 151, 0.24);
  color: #d9b3f5;
}

.admin-estado.es-activo {
  background: rgba(52, 211, 153, 0.14);
  color: var(--k-success);
}

.admin-estado.es-cerrado {
  background: rgba(255, 93, 115, 0.12);
  color: var(--k-error);
}

.admin-estado.es-en_cuestionario,
.admin-estado.es-cuestionario_completado,
.admin-estado.es-en_juego {
  background: var(--k-accent-softer);
  color: var(--k-accent);
}

.admin-estado.es-finalizada {
  background: rgba(52, 211, 153, 0.14);
  color: var(--k-success);
}

.admin-estado.es-vencida,
.admin-estado.es-abandonada {
  background: rgba(255, 93, 115, 0.12);
  color: var(--k-error);
}

.admin-congelado {
  font-style: normal;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--k-error);
  margin-left: 6px;
}

.admin-pub {
  border: 1px solid var(--k-line);
  cursor: pointer;
  background: transparent;
  transition: border-color 0.15s ease;
}

.admin-pub:hover {
  border-color: var(--k-accent);
}

.admin-pub.es-publicado {
  background: rgba(52, 211, 153, 0.14);
  color: var(--k-success);
  border-color: transparent;
}

/* Acciones de items ------------------------------------------------ */
.admin-a-btn {
  padding: 9px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: border-color 0.15s ease;
}

.admin-a-btn:hover {
  border-color: var(--k-accent);
}

.admin-a-btn:disabled,
.admin-pub:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.admin-paso {
  border-color: var(--k-accent);
  color: var(--k-accent);
}

.admin-prefill {
  opacity: 0.85;
}

/* Mensajes --------------------------------------------------------- */
.admin-msj {
  font-size: 13.5px;
  line-height: 1.6;
  color: var(--k-success);
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 12px 14px;
  margin: 0;
}

.admin-msj.is-error {
  color: var(--k-error);
}

.admin-nota {
  font-size: 12.5px;
  color: var(--k-text-3);
  line-height: 1.6;
  margin: 0;
}

.admin-vacio {
  font-size: 13.5px;
  color: var(--k-text-2);
  margin: 0;
  padding: 6px 0;
}

/* Banco de preguntas ----------------------------------------------- */
.admin-checks {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 380px;
  overflow-y: auto;
  padding-right: 4px;
}

.admin-check {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  background: var(--k-surface-2);
  cursor: pointer;
}

.admin-check input[type='checkbox'] {
  margin-top: 2px;
  accent-color: var(--k-accent);
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.admin-check-texto {
  font-size: 13.5px;
  color: var(--k-text);
  line-height: 1.5;
  min-width: 0;
}

.admin-check-meta {
  display: block;
  font-style: normal;
  font-size: 11.5px;
  color: var(--k-text-3);
  margin-top: 2px;
}

/* Actividades ------------------------------------------------------ */
.admin-tipo {
  flex-shrink: 0;
  padding: 3px 8px;
  border-radius: 999px;
  border: 1px solid rgba(142, 5, 194, 0.45);
  background: rgba(142, 5, 194, 0.14);
  color: var(--k-accent);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.admin-area {
  min-height: 62px;
  resize: vertical;
  line-height: 1.5;
}

.admin-check {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--k-text-2);
}

.admin-form-acciones {
  display: flex;
  flex-wrap: wrap;
  gap: var(--k-space-3);
}

.admin-opciones {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.admin-opciones li {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13.5px;
  color: var(--k-text-2);
}

.admin-opcion-correcta {
  font-style: normal;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--k-success);
  border: 1px solid rgba(52, 211, 153, 0.35);
  border-radius: 999px;
  padding: 2px 8px;
}

.admin-form-solucion {
  border-top: 1px dashed var(--k-line);
  border-radius: 0;
  padding-top: 10px;
  background: transparent;
  border-left: 0;
  border-right: 0;
  border-bottom: 0;
  margin-top: 4px;
}

.admin-detalle {
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 12px 14px;
}

.admin-resumen {
  font-size: 13.5px;
  font-weight: 700;
  color: var(--k-accent);
  cursor: pointer;
}

.admin-detalle[open] .admin-form {
  margin-top: 12px;
}

/* Estadisticas ----------------------------------------------------- */
.admin-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.admin-dato {
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 14px 10px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  text-align: center;
}

.admin-dato-valor {
  font-family: var(--k-font-brand);
  font-weight: 700;
  font-size: 20px;
  color: var(--k-text);
}

.admin-dato-etiq {
  font-size: 11px;
  color: var(--k-text-3);
  text-align: center;
}

@media (max-width: 380px) {
  .admin-pareja {
    flex-direction: column;
  }

  .admin-stats {
    grid-template-columns: repeat(2, 1fr);
  }

  .admin-tabs {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
