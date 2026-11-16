// Construye la migracion incremental del curso Pensamiento Logico.
// Idempotente: constraint drop/add, create or replace de las funciones, seeds con on conflict do nothing.
import { readFileSync, writeFileSync } from 'node:fs'

const src = readFileSync('src/scripts/kodigo-completo.sql', 'utf8').split(/\r?\n/)

let marker = -1
for (let i = 0; i < src.length; i += 1) {
  if (src[i].includes('22. Curso Pensamiento')) { marker = i - 1; break }
}
if (marker < 0) throw new Error('No se encontro el marcador de la seccion 22')

const seed = src.slice(marker).join('\n')
const constraint = src.slice(6199, 6215).join('\n')
const comprobar = src.slice(6320, 6728).join('\n')
const expotec = src.slice(7172, 7443).join('\n')

const delta = [
  '-- =====================================================================',
  '-- Migracion incremental: curso Pensamiento Logico + tipo de actividad robot',
  '-- Idempotente: puede aplicarse mas de una vez sin duplicar datos.',
  '-- =====================================================================',
  '',
  '-- 1. constraint preguntas_tipo_check (ETAPA 8)',
  constraint,
  '',
  '-- 2. comprobar_respuesta con soporte para la modalidad robot (repetir x3)',
  comprobar,
  '',
  '-- 3. validacion de la modalidad robot en el panel de administracion',
  expotec,
  '',
  '-- 4. seed: curso Pensamiento Logico (3 unidades, 14 lecciones, 14 actividades robot)',
  seed,
].join('\n')

writeFileSync('scripts/_migracion-robot.sql', delta, 'utf8')
console.log('bytes:', Buffer.byteLength(delta, 'utf8'))
console.log('lines:', delta.split('\n').length)
console.log('mojibake:', (delta.match(/├/g) || []).length)
console.log('seccion 22 incluida:', delta.includes('-- 22. Curso Pensamiento'))
console.log('robot en constraint:', constraint.includes("'robot'"))
console.log('robot en comprobar:', comprobar.includes("v_tipo = 'robot'"))
console.log('robot en expotec:', expotec.includes("v_pregunta.tipo = 'robot'"))
