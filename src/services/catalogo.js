import { courses } from '@/data/cursos'
import { units } from '@/data/unidades'
import { lessons } from '@/data/lecciones'
import { activities } from '@/data/actividades'

const intentosLeccion = {}

function crearEstadoIntento() {
  return {
    completed: false,
    passed: false,
    correct: 0,
    incorrect: 0,
    answeredIds: [],
  }
}

export function asegurarIntentoLeccion(lessonId) {
  if (!intentosLeccion[lessonId]) {
    intentosLeccion[lessonId] = crearEstadoIntento()
  }
  return intentosLeccion[lessonId]
}

export function reiniciarIntentoLeccion(lessonId) {
  intentosLeccion[lessonId] = crearEstadoIntento()
  return intentosLeccion[lessonId]
}

export function registrarRespuestaLeccion(lessonId, activityId, isCorrect) {
  const estado = asegurarIntentoLeccion(lessonId)
  if (estado.answeredIds.includes(activityId)) {
    return estado
  }

  estado.answeredIds.push(activityId)
  if (isCorrect) estado.correct += 1
  else estado.incorrect += 1

  const total = obtenerActividadesPorLeccion(lessonId).length
  estado.completed = estado.answeredIds.length >= total
  estado.passed = estado.correct >= 2

  return estado
}

export function obtenerIntentoLeccion(lessonId) {
  if (!lessonId) return null
  return asegurarIntentoLeccion(lessonId)
}

export function obtenerResultadosLeccion(lessonId) {
  const intento = obtenerIntentoLeccion(lessonId)
  const total = obtenerActividadesPorLeccion(lessonId).length
  const correct = intento?.correct ?? 0
  const incorrect = intento?.incorrect ?? 0
  const percentage = total ? Math.round((correct / total) * 100) : 0

  return {
    total,
    correct,
    incorrect,
    percentage,
    passed: correct >= 2,
    completed: intento?.completed ?? false,
  }
}

export function estaLeccionDesbloqueada(lessonId) {
  const leccion = obtenerLeccion(lessonId)
  if (!leccion) return false

  const leccionesUnidad = lessons
    .filter((entrada) => entrada.unitId === leccion.unitId)
    .sort((a, b) => a.id.localeCompare(b.id))
  const index = leccionesUnidad.findIndex((entrada) => entrada.id === lessonId)

  if (index <= 0) return true

  const leccionAnterior = leccionesUnidad[index - 1]
  const intentoAnterior = obtenerIntentoLeccion(leccionAnterior.id)
  return Boolean(intentoAnterior?.passed)
}

export function obtenerCursos() {
  return courses
}

export function obtenerCursosDisponibles() {
  return courses.filter((curso) => curso.status === 'available')
}

export function obtenerCurso(courseId) {
  return courses.find((curso) => curso.id === courseId)
}

export function obtenerUnidadesPorCurso(courseId) {
  return units.filter((unidad) => unidad.courseId === courseId).sort((a, b) => a.id - b.id)
}

export function obtenerUnidad(courseId, unitId) {
  return units.find((unidad) => unidad.courseId === courseId && unidad.id === Number(unitId))
}

export function obtenerUnidadPorId(unitId) {
  return units.find((unidad) => unidad.id === Number(unitId))
}

export function obtenerUnidades() {
  return units
}

export function obtenerLeccion(lessonId) {
  return lessons.find((leccion) => leccion.id === lessonId)
}

export function obtenerEstadoLeccion(lessonId) {
  const leccion = obtenerLeccion(lessonId)
  if (!leccion) return 'locked'
  if (!estaLeccionDesbloqueada(leccion.id)) return 'locked'

  const intento = obtenerIntentoLeccion(leccion.id)
  if (!intento?.completed) return 'available'
  return intento.passed ? 'passed' : 'completed'
}

export function obtenerLeccionesPorUnidad(unitId) {
  return lessons
    .filter((leccion) => leccion.unitId === Number(unitId))
    .map((leccion) => ({
      ...leccion,
      status: obtenerEstadoLeccion(leccion.id),
    }))
}

export function obtenerLecciones() {
  return lessons
}

export function obtenerActividades() {
  return activities
}

export function obtenerActividad(activityId) {
  return activities.find((actividad) => actividad.id === activityId)
}

export function obtenerIdsActividadesPorLeccion(lessonId) {
  const leccion = obtenerLeccion(lessonId)
  return leccion ? leccion.activityIds : []
}

export function obtenerActividadesPorLeccion(lessonId) {
  return obtenerIdsActividadesPorLeccion(lessonId)
    .map((id) => obtenerActividad(id))
    .filter(Boolean)
}

export function obtenerPosicionActividad(activityId) {
  const actividad = obtenerActividad(activityId)
  if (!actividad) return -1
  return obtenerIdsActividadesPorLeccion(actividad.lessonId).indexOf(activityId)
}

export function obtenerSiguienteActividad(activityId) {
  const actividad = obtenerActividad(activityId)
  if (!actividad) return null
  const ids = obtenerIdsActividadesPorLeccion(actividad.lessonId)
  const index = ids.indexOf(activityId)
  const siguienteId = ids[index + 1]
  return siguienteId ? obtenerActividad(siguienteId) : null
}

export function obtenerPrimeraLeccionDisponible(courseId) {
  const unidadesCurso = obtenerUnidadesPorCurso(courseId)
  for (const unidad of unidadesCurso) {
    const leccionesUnidad = obtenerLeccionesPorUnidad(unidad.id)
    const siguienteLeccion = leccionesUnidad.find(
      (leccion) => leccion.status === 'available' || (leccion.status === 'passed' && !obtenerIntentoLeccion(leccion.id)?.completed),
    )
    if (siguienteLeccion) return siguienteLeccion
  }
  return null
}

export function obtenerCursoDeUnidad(unitId) {
  const unidad = obtenerUnidadPorId(unitId)
  return unidad ? obtenerCurso(unidad.courseId) : null
}

export function rutaUnidad(unitId) {
  const unidad = obtenerUnidadPorId(unitId)
  if (!unidad) return { name: 'cursos' }
  return { name: 'unidad', params: { courseId: unidad.courseId, unitId: String(unidad.id) } }
}

export function rutaLeccion(lessonId) {
  const leccion = obtenerLeccion(lessonId)
  if (!leccion) return { name: 'cursos' }
  const unidad = obtenerUnidadPorId(leccion.unitId)
  if (!unidad) return { name: 'cursos' }
  return {
    name: 'leccion',
    params: { courseId: unidad.courseId, unitId: String(unidad.id), lessonId: leccion.id },
  }
}

export function rutaActividad(lessonId, activityId) {
  const leccion = obtenerLeccion(lessonId)
  if (!leccion) return { name: 'cursos' }
  const unidad = obtenerUnidadPorId(leccion.unitId)
  if (!unidad) return { name: 'cursos' }
  return {
    name: 'actividad-leccion',
    params: {
      courseId: unidad.courseId,
      unitId: String(unidad.id),
      lessonId: leccion.id,
      activityId,
    },
  }
}
