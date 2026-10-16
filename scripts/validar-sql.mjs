import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const aqui = dirname(fileURLToPath(import.meta.url))
export const RUTA_SQL = resolve(aqui, '..', 'src', 'scripts', 'kodigo-completo.sql')

/**
 * Divide un script SQL en sentencias respetando:
 * - bloques delimitados por $$ ... $$ (cuerpos de funciones)
 * - cadenas simples '...' con escapes ''
 * - identificadores entre comillas dobles "..."
 * - comentarios de linea -- ...
 * Devuelve cada sentencia sin el ';' final.
 */
/** Quita comentarios de linea para decidir si hay codigo real. */
function soloCodigo(texto) {
  return texto
    .split('\n')
    .filter((linea) => !linea.trimStart().startsWith('--'))
    .join('\n')
    .trim()
}

export function dividirSentencias(sql) {
  const sentencias = []
  let actual = ''
  let i = 0

  while (i < sql.length) {
    const par = sql.slice(i).match(/^\$\$/)
    if (par) {
      const fin = sql.indexOf('$$', i + 2)
      if (fin === -1) throw new Error('Bloque $$ sin cerrar')
      actual += sql.slice(i, fin + 2)
      i = fin + 2
      continue
    }

    const dos = sql[i]
    if (dos === "'") {
      let j = i + 1
      while (j < sql.length) {
        if (sql[j] === "'" && sql[j + 1] === "'") {
          j += 2
          continue
        }
        if (sql[j] === "'") break
        j += 1
      }
      if (j >= sql.length) throw new Error("Cadena simple sin cerrar")
      actual += sql.slice(i, j + 1)
      i = j + 1
      continue
    }

    const doble = sql[i]
    if (doble === '"') {
      const fin = sql.indexOf('"', i + 1)
      if (fin === -1) throw new Error('Identificador sin cerrar')
      actual += sql.slice(i, fin + 1)
      i = fin + 1
      continue
    }

    if (dos === '-' && sql[i + 1] === '-') {
      const fin = sql.indexOf('\n', i)
      const hasta = fin === -1 ? sql.length : fin
      actual += sql.slice(i, hasta)
      i = hasta
      continue
    }

    if (dos === ';') {
      const limpia = soloCodigo(actual)
      if (limpia) sentencias.push(actual.trim())
      actual = ''
      i += 1
      continue
    }

    actual += dos
    i += 1
  }

  const resto = soloCodigo(actual)
  if (resto) {
    throw new Error('La ultima sentencia no termina en ";":\n' + resto.slice(0, 200))
  }
  return sentencias
}

export function leerSql(ruta = RUTA_SQL) {
  return readFileSync(ruta, 'utf8')
}

export function normalizar(sentencia) {
  return sentencia.replace(/--[^\n]*/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase()
}

export function buscarSentencias(sql, patron) {
  const re = new RegExp(patron, 'i')
  return dividirSentencias(sql).filter((s) => re.test(normalizar(s)))
}

const esEjecucion = () => process.argv[1] && process.argv[1].endsWith('validar-sql.mjs')

if (esEjecucion()) {
  try {
    const sql = leerSql()
    const sentencias = dividirSentencias(sql)
    const tablas = sentencias.filter((s) => /create table/.test(normalizar(s)))
    const funciones = sentencias.filter((s) => /create (or replace )?function/.test(normalizar(s)))
    const politicas = sentencias.filter((s) => /create policy/.test(normalizar(s)))
    console.log('SQL valido:')
    console.log('  sentencias:', sentencias.length)
    console.log('  tablas:', tablas.length)
    console.log('  funciones:', funciones.length)
    console.log('  politicas RLS:', politicas.length)
  } catch (error) {
    console.error('SQL invalido:', error.message)
    process.exitCode = 1
  }
}