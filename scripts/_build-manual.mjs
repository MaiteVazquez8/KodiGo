// Genera docs/kodigo-manual de usuario.docx: manual práctico para quienes
// usan Kodigo por primera vez. Todas las capturas son reales (NO mockups),
// tomadas en Chrome headless sobre el build de producción.
import {
  h1, h2, h3, p, bullet, code, callout, tabla, tablaNota, spacer,
  headerFooter, buildDocument, saveDocument, coverBlocks, image,
} from './_docs-lib.mjs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { AlignmentType } from 'docx'
import { COLOR } from './_docs-lib.mjs'

const aqui = dirname(fileURLToPath(import.meta.url))
const root = join(aqui, '..')
const IMG = (name) => join(root, 'docs', 'imagenes-usuario', name)

const cover = coverBlocks({
  title: 'Manual de usuario',
  subtitle: 'Kodigo · Aprendé a programar paso a paso, episodio por episodio',
  lineas: [
    { izq: 'Aplicación', der: 'Kodigo' },
    { izq: 'Para quién', der: 'Estudiantes y personas que empiezan a programar' },
    { izq: 'Qué incluye', der: 'Cómo entrar, cursos, actividades, progreso, logros, FAQ' },
    { izq: 'Versión', der: 'Noviembre 2026 · incluye los cursos publicados en este momento' },
    { izq: 'Publicado en', der: 'Kodigo · ukrdyolkregjrmjlcemk.supabase.co' },
  ],
})

// ============================================================ Portada / Intro
const children = [
  ...cover,

  h1('1. Introducción: qué es Kodigo'),
  p('Kodigo es una aplicación para aprender a programar de manera progresiva, con ejercicios interactivos cortos y un sistema de progreso con experiencia (XP), niveles y logros. Está pensada para principiantes: no necesitás saber inglés ni programación para empezar.'),
  h2('1.1. ¿Para qué sirve?'),
  bullet('Aprender los conceptos básicos de la programación jugando.'),
  bullet('Practicar con ejercicios reales: elegir opciones, ordenar fragmentos, escribir código, corrigir errores o resolver desafíos con un robot virtual.'),
  bullet('Seguir tu progreso con XP, niveles y rachas de días.'),
  bullet('Competir sanamente: participar en el Desafío ExpoTécnica contra estudiantes de todos los grupos.'),
  h2('1.2. ¿Qué se puede aprender hoy?'),
  tabla({
    headers: ['Curso', 'Contenido'],
    rows: [
      ['JavaScript', 'Variables, operadores, condicionales, bucles, funciones, arrays, objetos, cadenas y un proyecto final. 10 lecciones, 76 actividades.'],
      ['HTML', 'Documento HTML, etiquetas de texto, listas y enlaces, formularios, imágenes, tablas, etiquetas semánticas, atributos y clases, formularios avanzados y proyecto final. 10 lecciones, 53 actividades.'],
      ['Pensamiento Lógico', 'Pensamiento computacional: secuencias, patrones, descomposición y algoritmos. 14 actividades con el juego "Ruta del robot" (tablero 5×5).'],
    ],
    widths: [2.2, 7.0],
  }),
  spacer(160),

  h1('2. Requisitos para usar la aplicación'),
  p('Kodigo es una aplicación web (también hay una app de Android como APK) que se usa desde el navegador; todo el avance queda guardado en tu perfil.'),
  tabla({
    headers: ['Requisito', 'Detalle'],
    rows: [
      ['Navegador', 'Chrome o Edge (recomendados), Firefox o Safari actualizados. Requiere JavaScript habilitado.'],
      ['Conexión a internet', 'Necesaria todo el tiempo; el progreso se guarda en la nube (Supabase).'],
      ['Dispositivo', 'Celular Android (recomendado por el diseño mobile-first), tablet o computadora.'],
      ['Cuenta', 'No es obligatoria para probar: "Entrar como invitado" crea tu perfil automáticamente y guarda tu progreso. Crear una cuenta con correo es opcional (convertir tu invitado en cuenta definitiva).'],
      ['Espacio de almacenamiento', 'Ninguno especial (es una app ligera).'],
    ],
    widths: [2.2, 6.5],
  }),
  spacer(140),

  h1('3. Cómo ingresar a Kodigo'),
  h2('3.1. Primera visita'),
  p('Cuando abrís la app por primera vez, Kodigo te muestra una pantalla de bienvenida con dos opciones. La forma más rápida de probar la app sin registrarse es:'),
  callout('Acción rápida: en la pantalla de bienvenida, tocá «Entrar como invitado». El sistema crea una sesión anónima única para vos y te lleva a tu perfil.', COLOR.acentoSuave, COLOR.violetaIntenso),
  ...image(IMG('01-inicio-bienvenida.png'), 78, 'Figura 3.1 — Pantalla de bienvenida: «INICIAR SESIÓN» y «Entrar como invitado».'),
  spacer(80),
  h2('3.2. Qué pasa al iniciar sesión'),
  bullet('Si entrás como invitado: se crea una identidad anónima propia (un perfil de usuario llamado, por ejemplo, "usuario_81fb15bd") y se guarda tu progreso normalmente.'),
  bullet('Si creás una cuenta (login con correo): tu invitado se convierte en tu cuenta y conserva TODO tu progreso y tu identidad.'),
  bullet('Si cerrás sesión: tu identidad anónima se pierde (no podrás acceder a su progreso sin el correo o la cuenta).'),
  h2('3.3. Cerrar sesión'),
  p('Desde la pantalla de "Más opciones" (pestaña "More" de la navegación inferior) o desde tu perfil, podés cerrar la sesión actual. Reabrir la app crea un nuevo invitado nuevo — perdiendo el anterior si no lo registraste.'),
  ...image(IMG('02-perfil-invitado.png'), 78, 'Figura 3.2 — Perfil tras entrar como invitado: Sesión de invitado, Nivel 1, 0 XP.'),
  spacer(120),

  h1('4. La pantalla principal'),
  p('Cuando entrás como invitado, Kodigo te muestra tu portal personal con todo lo que importa hoy:'),
  bullet('KODI(GO): el logo de la app y tu racha actual (días seguidos entrando).'),
  bullet('Progreso Diario: tu objetivo del día (0 % al principio; sube al aprobar lecciones).'),
  bullet('Continuar Aprendiendo: la tarjeta del curso que estás haciendo y tu próxima lección.'),
  bullet('Evento Especial: un acceso directo al Desafío ExpoTécnica si hay un evento activo (siempre lo verás cuando el colegio lo publica).'),
  bullet('Cursos Sugeridos: los cursos publicados y disponibles.'),
  ...image(IMG('03-aprender.png'), 78, 'Figura 4.1 — Pantalla principal "Tu portal de aprendizaje gamificado".'),
  spacer(120),

  h1('5. Catálogo de cursos'),
  p('La pestaña "Search" (Buscar cursos) te muestra el catálogo completo. Cada tarjeta de curso muestra su nombre, descripción corta, estado y progreso. Actualmente el catálogo publicado incluye:'),
  bullet('JavaScript — disponible, 10 lecciones publicadas.'),
  bullet('HTML — disponible, 10 lecciones publicadas.'),
  bullet('Pensamiento Lógico — disponible, lección 1 publicadas (curso de programación visual).'),
  ...image(IMG('04-cursos.png'), 78, 'Figura 5.1 — Catálogo de cursos publicado: JavaScript, HTML y Pensamiento Lógico.'),
  spacer(120),

  h1('6. Unidades de aprendizaje'),
  p('Cada curso está dividido en unidades. Las unidades se desbloquean de a una: primero completás el 100 % de la unidad 1 para habilitar la unidad 2, y así sucesivamente. Las unidades aparecen con estados:'),
  tabla({
    headers: ['Estado', 'Significado'],
    rows: [
      ['Disponible', 'Podés entrar y resolver sus lecciones.'],
      ['Bloqueada', 'Aún no podés entrar; completá la unidad anterior primero.'],
      ['Completada', 'La terminaste; aparecen con tilde y no se pueden rehacer (más bien sí se pueden repetir para practicar).'],
    ],
    widths: [1.8, 7.8],
  }),
  p('El camino de aprendizaje se muestra en forma de nodos conectados (una línea con tus nodos visibles): cada nodo es una lección; los que ya aprobaste tienen una tilde.'),
  ...image(IMG('06-unidad-javascript.png'), 70, 'Figura 6.1 — Unidad de JavaScript: 3 nodos con la línea de conexión entre ellos (zigzag suave, nodo 1 activo, 2 y 3 bloqueados).'),
  spacer(100),

  h1('7. Las lecciones: cómo se leen'),
  p('Cada lección presenta primero un concepto y un ejemplo, y después las actividades para comprobarlo. Ejemplo real de la lección 1 de Pensamiento Lógico:'),
  callout('Conocé al robot — El tablero es un 5 × 5. El robot empieza en la letra I y la estrella indica dónde debe llegar. Construí una secuencia y pulsa Ejecutar. Orde primero: la I marca la posición inicial.', COLOR.acentoSuave, COLOR.violeta),
  p('Cada lección muestra:'),
  bullet('Título y objetivo (ej.: "Alcanzá la estrella").'),
  bullet('Explicación breve del concepto (ej.: "Cada avance cuenta como una instrucción").'),
  bullet('Ejemplo de código/señal con el qué vas a practicar.'),
  bullet('Duración estimada y recompensa (XP).'),
  bullet('Botón grande "COMENZAR AHORA".'),
  spacer(60),

  h1('8. Actividades: cómo resolverlas'),
  p('Cada lección trae distintas modalidades de actividad. La siguiente es la lista de las que podés encontrar, con una breve guía de cada una:'),
  tabla({
    headers: ['Modalidad', 'Cómo se resuelve'],
    rows: [
      ['Selección múltiple', 'Tocá la opción correcta (una sola) y pulsá Comprobar.'],
      ['Verdadero / Falso', 'Tocá la opción correcta: verdadero o falso ante la afirmación planteada.'],
      ['Ordenar', 'Arrastrá los fragmentos para dejarlos en el orden correcto. Tocá dos veces el fragmento para moverlo hacia arriba o abajo; la papelera lo elimina de tu arreglo.'],
      ['Relacionar columnas', 'Uní cada concepto de la columna izquierda con su par de la derecha. Vas tocando primero un elemento de la izquierda y después uno de la derecha.'],
      ['Completar texto', 'Escribí la palabra que falta según la consigna; se acepta la respuesta incluso con diferencias leves de mayúsculas.'],
      ['Completar código', 'Escribí el valor que falta en cada blanco marcado con {clave}.'],
      ['Escribir código', 'Escribí el código completo que resuelve la consigna; el servidor valida patrones requeridos/prohibidos o las soluciones aceptadas.'],
      ['Corregir código', 'El código contiene errores; editálo hasta que funcione. El servidor acepta soluciones equivalentes.'],
      ['Salida de código', 'Leé el código y elegí qué valor imprime, o escribilo directamente según la modalidad.'],
      ['Predecir resultado', 'Elegí el resultado correcto o escribilo, según el tipo de pregunta.'],
      ['Bloques', 'Tocá los bloques del panel de abajo para agregarlos, y acomodalos con las flechas para formar el programa correcto.'],
      ['Ruta del robot', 'Armá una secuencia de instrucciones para que el robot llegue a la estrella esquivando los obstáculos (×). Tenés que agregar la secuencia completa (avanzar y girar a izquierda o derecha) y pulsar Ejecutar para probarla, y después Comprobar para validar. Podés repetir mientras el nivel lo permita.'],
    ],
    widths: [2.2, 7.2],
  }),
  spacer(140),

  h1('9. Comprobación de respuestas y resultados'),
  p('Cuando termines de armar tu respuesta:'),
  bullet('Pulsá «Comprobar» (abajo de la pantalla). El servidor la valida.'),
  bullet('Si es correcta: aparece el botón «Siguiente»; la explicación del profesor se muestra como refuerzo.'),
  bullet('Si es incorrecta: aparece el mensaje con la explicación y podés intentar de nuevo (si el nivel lo permite).'),
  bullet('Si hay un problema técnico (ej. sin conexión): aparece el botón «Reintentar» y se hace un nuevo intento de envío.'),
  p('Panel de resultado: al alcanzar las respuestas, se muestra el resumen (PRECISIÓN, RESPUESTAS, TOTAL XP GANADO, progreso del curso).'),
  ...image(IMG('10-actividad-robot-acierto.png'), 74, 'Figura 9.1 — Tras pulsar Comprobar: feedback verde del servidor con la explicación y el botón Siguiente habilitado.'),
  spacer(60),
  ...image(IMG('11-resultado.png'), 74, 'Figura 9.2 — Panel "Clase Completada" con la precisión, las respuestas, el XP total y el progreso del curso.'),
  spacer(120),

  h1('10. Progreso, XP, niveles, rachas y logros'),
  h2('10.1. Experiencia (XP) y niveles'),
  p('Ganás XP por aprobar lecciones (el valor depende de la cantidad de respuestas correctas: por ejemplo, el 100 % da 25 XP en la primera lección). Tu NIVEL sube con la práctica.'),
  h2('10.2. Racha de días'),
  p('Cada día que entres a Kodigo y apruebes al menos una lección, tu racha (🔥) sube. Si pasan 48 h sin aprobar, la racha se pierde.'),
  h2('10.3. Logros'),
  p('Kodigo entrega logros automáticamente al lograr ciertos hitos (aprobar tu primera lección, 5 lecciones, 10 lecciones, terminar un curso, etc). Todo queda en tu perfil.'),
  ...image(IMG('14-logros.png'), 70, 'Figura 10.1 — Sección de logros: 0/12 al empezar; cada objetivo muestra su progreso.'),
  spacer(100),

  h1('11. Tu perfil'),
  p('Tu perfil reúne toda tu información. Aprendés a leerlo rápido:'),
  bullet('Nombre de usuario (ej. usuario_81fb15bd) y si sos sesión de invitado o cuenta registrada.'),
  bullet('Nivel actual y total de XP.'),
  bullet('Racha de días seguidos.'),
  bullet('Cursos iniciados, lecciones aprobadas, intentos realizados.'),
  ...image(IMG('12-perfil.png'), 70, 'Figura 11.1 — Perfil de invitado: Nivel 1, 35 XP, racha de 1 día, cursos iniciados 1, lecciones aprobadas 1.'),
  spacer(120),

  h1('12. Navegación'),
  p('La navegación inferior tiene 5 accesos que funcionan siempre igual:'),
  tabla({
    headers: ['Pestaña', 'Para qué sirve'],
    rows: [
      ['Learn (Aprender)', 'Tu portal: progreso diario, continuar aprendiendo, cursos sugeridos.'],
      ['Search (Buscar)', 'Catálogo completo de cursos publicados.'],
      ['Review (Repaso)', 'Repaso de las preguntas que ya respondiste (ideal (ideal para reforzar conceptos).'],
      ['Dictionary (Diccionario)', 'Diccionario de términos de programación con búsqueda y ejemplos.'],
      ['More (Más)', 'Más opciones: logros, estadísticas, diccionario, ayuda, amigos, Liga de Honor, configuración y, si es tu caso, acceso al panel de administración.'],
    ],
    widths: [2.4, 7.0],
  }),
  bullet('Volver a la pantalla anterior: botón de atrás del sistema, o el icono de flecha que aparece en las pantallas internas.'),
  bullet('Volver al inicio del curso: desde cualquier pantalla, tocá "Learn" (abajo).'),
  ...image(IMG('20-mas.png'), 64, 'Figura 12.1 — Pestaña More: accesos a ligas, logros, estadísticas, diccionario, amigos, configuración y administración.'),
  spacer(120),

  h1('13. Problemas frecuentes y cómo resolverlos'),
  tabla({
    headers: ['Situación', 'Qué hacer'],
    rows: [
      ['«No se pueden cargar los cursos»', 'Verificá tu conexión a internet y recargá la página. Si persiste, cerrá la sesión y volvé a entrar como invitado.'],
      ['Una unidad o lección no aparece', 'Sólo se desbloquean al aprobar la unidad/lecciones anteriores. Si ya la aprobaste y no aparece, cerrá y reabrí la app.'],
      ['La actividad no carga / se queda en "Cargando contenido…"', 'Esperá unos segundos; si la pantalla no avanza, recargá. Si se repite, hay un problema del servidor — avisá al docente.'],
      ['No puedo enviar una respuesta / el botón está deshabilitado', 'Aseguráte de que hayas completado al menos una instrucción o elegido una opción. Si el error es "Reintentar", tocálo; el progreso se registra igual.'],
      ['El resultado dice "incorrecta" pero suena mal', 'Empezá de nuevo y revisá la explicación que aparece debajo del mensaje de resultado; ahí está el porqué.'],
      ['Perdí mi progreso', 'Pasa si borraste los datos del navegador sin crear cuenta. Para conservar el progreso, creá una cuenta con correo (ver sección 3.2).'],
      ['Aparece "No pudimos cargar …"', 'Hay un problema de conexión con el servidor. Revisá tu red o esperá unos minutos y reintentá.'],
      ['La app muestra un error que no entiendo', 'Tomá una captura y avisá al profesor/admin; la app guarda mucha información en el servidor.'],
    ],
    widths: [3.0, 6.5],
  }),
  spacer(140),

  h1('14. Recomendaciones de uso'),
  bullet('Avanzá un poco todos los días: la racha los premia.'),
  bullet('Antes de pulsar Comprobar, razoná la respuesta: leer y pensar es parte del aprendizaje, no un trámite.'),
  bullet('Si te equivocás, leé la explicación que Kodigo muestra; ahí está el porqué y esa es la mejor forma de aprender.'),
  bullet('Usá el diccionario cuando no entiendas un término. Es veloz y útil.'),
  bullet('Usá el repaso después de terminar una unidad: te ayuda a fijar lo aprendido.'),
  bullet('Configurá tu nombre visible desde el perfil para que te reconozcan en la Liga de Honor.'),
  bullet('Si llegás a una lección difícil, no la saltees: la dificultad aumenta gradualmente, y las intruducciones guían el camino.'),
  spacer(120),

  h1('15. Glosario mínimo'),
  tabla({
    headers: ['Término', 'Significado'],
    rows: [
      ['variable', 'Espacio con nombre donde se guarda un valor.'],
      ['constante', 'Valor que no cambia una vez definido.'],
      ['función', 'Bloque de código reutilizable que realiza una tarea.'],
      ['condición', 'Expresión que se evalúa como verdadera o falsa.'],
      ['bucle', 'Instrucción que repite un bloque de código varias veces.'],
      ['array', 'Colección ordenada de valores del mismo tipo.'],
      ['objeto', 'Conjunto de propiedades nombre/valor agrupadas.'],
      ['XP', 'Experiencia acumulada al aprobar lecciones.'],
      ['racha', 'Días consecutivos entrando y aprobando al menos una lección.'],
      ['ExpoTécnica', 'Evento oficial de Kodigo: cuestionario puntual + Core Defender.'],
    ],
    widths: [1.8, 7.8],
  }),
  spacer(120),

  h1('16. Capturas reales de Kodigo (evidencia visual)'),
  p('Todas las imágenes de este manual se tomaron directamente de la aplicación publicada (Chrome sobre el build actual del 16/11/2026). Corresponden a las pantallas reales que ves cuando navegás.'),
  tabla({
    headers: ['Pantalla', 'Imagen de referencia'],
    rows: [
      ['Bienvenida', 'Figura 3.1'],
      ['Perfil (invitado)', 'Figuras 3.2 y 11.1'],
      ['Portal de aprendizaje', 'Figura 4.1'],
      ['Catálogo de cursos', 'Figura 5.1'],
      ['Detalle de curso JavaScript', 'Figura 8.2'],
      ['Unidad (ruta)', 'Figura 6.1'],
      ['Actividad robot (con tutorial)', 'Figura 8.1 / 9.1'],
      ['Comprobación y resultado', 'Figuras 9.1 y 9.2'],
      ['Logros', 'Figura 10.1'],
      ['Diccionario', 'Captura real 15-diccionario.png'],
      ['Repaso', 'Captura real 13-revision.png'],
      ['Amigos', 'Captura real 17-amigos.png'],
      ['Liga de Honor', 'Captura real 19-liga.png'],
      ['Más opciones', 'Figura 12.1 (captura 20-mas.png)'],
      ['ExpoTécnica 2026', 'Captura real 23-expotecnica.png'],
    ],
    widths: [3.0, 5.4],
  }),
  spacer(90),
  ...image(IMG('16-ayuda.png'), 64, 'Figura 16.1 — Pantalla "Ayuda": acceso directo al soporte dentro de la app.'),
  spacer(60),
  ...image(IMG('06-unidad-javascript.png'), 64, 'Figura 16.2 — Ruta de aprendizaje: unidades en zigzag con su línea de conexión.'),
  spacer(60),
  ...image(IMG('23-expotecnica.png'), 64, 'Figura 16.3 — Portada del evento ExpoTécnica 2026: cuestionario de JavaScript + Core Defender.'),
  spacer(100),

  h1('17. Cierre y soporte'),
  p('Cualquier situación en la que no podés avanzar: capturá la pantalla, anotá lo que estabas haciendo y la hora aproximada, y pasásela al docente. Todo avance se guarda en tu perfil, así que podés seguir en otro dispositivo entrando con tu cuenta.'),
  callout('Kodigo es un proyecto abierto de la escuela técnica: lo construyeron estudiantes, con la colaboración del cuerpo docente y de los mismos cursos que jugás. ¡Cada mejora hace a la app mejor para todos!', COLOR.acentoSuave, COLOR.violetaIntenso),
]

const { header, footer } = headerFooter('Manual de usuario — Kodigo')
const doc = buildDocument({
  title: 'Kodigo — Manual de usuario',
  creator: 'Equipo Kodigo',
  children,
  header,
  footer,
})

const len = await saveDocument(doc, join(root, 'docs', 'kodigo-manual de usuario.docx'))
console.log('docs/kodigo-manual de usuario.docx generado,', len, 'bytes')
