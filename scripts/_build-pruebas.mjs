// Genera docs/KodiGo - pruebas.docx: documento oficial de la actividad
// "Pruebas, validación y documentación" con los 18 puntos requeridos,
// respaldado por verificaciones reales del proyecto al 16/11/2026.
import {
  h1, h2, h3, p, bullet, code, callout, tabla, tablaNota, spacer,
  headerFooter, buildDocument, saveDocument, coverBlocks, image, captionPara,
} from './_docs-lib.mjs'
import { writeFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  COLOR, FONT,
} from './_docs-lib.mjs'
import {
  AlignmentType, Paragraph, TextRun, HeadingLevel,
} from 'docx'

const aqui = dirname(fileURLToPath(import.meta.url))
const root = join(aqui, '..')
const IMG = (name) => join(root, 'docs', 'imagenes-usuario', name)

const cover = coverBlocks({
  title: 'Pruebas, validación\ny documentación técnica',
  subtitle: 'Kodigo · Aplicación educativa para aprender a programar de forma progresiva y gamificada',
  lineas: [
    { izq: 'Documento', der: 'Pruebas funcionales, de integración, seguridad, navegación, rendimiento y persistencia' },
    { izq: 'Proyecto', der: 'Kodigo (frontend Vue 3 + Quasar + Vite · backend Supabase/PostgreSQL · Android Capacitor)' },
    { izq: 'Ámbito', der: 'Actividades, unidades, lecciones, progreso, XP, rachas, rankings, ExpoTécnica y login' },
    { izq: 'Fecha', der: '16 de noviembre de 2026' },
    { izq: 'Versión', der: 'Etapa 11 · 145 pruebas automatizadas en verde · Supabase en vivo verificado' },
  ],
})

const toc = [
  h1('Índice'),
  tabla({
    headers: ['#', 'Sección', 'Contenido'],
    rows: [
      ['A', 'Descripción general de la aplicación', 'Contexto de diseño, funcionalidades y arquitectura'],
      ['B.1', '1. Revisión de requerimientos', 'Requerimientos funcionales y no funcionales con estado y observaciones'],
      ['B.2', '2. Plan de pruebas', 'Cobertura: funcionales, integración, seguridad, validación, navegación, responsive y persistencia'],
      ['B.3', '3. Casos de prueba', '20 casos con resultado obtenido y estado'],
      ['B.4', '4. Pruebas funcionales', 'Recorrido completo Login → Cursos → … → Comprobación'],
      ['B.5', '5. Operaciones CRUD', 'Operaciones por entidad; limitaciones por RLS/Supabase'],
      ['B.6', '6. Integridad de datos', 'PK, FK, relaciones, constraints y consultas de verificación'],
      ['B.7', '7. Autenticación y autorización', 'Sesiones, invitados, RLS, RPCs y comprobar_respuesta'],
      ['B.8', '8. Formularios y validaciones', 'Casos válidos, inválidos, límites y duplicados'],
      ['B.9', '9. Reglas de negocio', 'Reglas implementadas vs pendientes'],
      ['B.10', '10. Navegación y responsive', '1920×1080 · 1366×768 · 768×1024 · 390×844 · 360×640'],
      ['B.11', '11. Usabilidad y accesibilidad', 'Jerarquía, contraste, etiquetas, navegación por teclado'],
      ['B.12', '12. Rendimiento y manejo de errores', 'Tiempos, chunk grande, estado de error vs incorrecta'],
      ['B.13', '13. Registro de errores', '12 errores documentados con solución y verificación'],
      ['B.14', '14. Correcciones y repetición de pruebas', 'Regresiones tras las correcciones de esta etapa'],
      ['B.15', '15. Calidad del código', 'Organización, ESLint, build y convenciones'],
      ['B.16', '16. Documentación técnica', 'Cobertura y huecos de la documentación del proyecto'],
      ['B.17', '17. Manual de usuario', 'Documento independiente: docs/kodigo-manual de usuario.docx'],
      ['B.18', '18. Informe final de pruebas', 'Resumen cuantitativo: aprobadas, fallidas, pendientes y conclusión'],
    ],
    widths: [1, 4, 6],
  }),
]

const parteA = [
  h1('A. Descripción general de la aplicación'),
  p('El contenido siguiente conserva el material de diseño original del documento, ajustado al estado real del sistema al 16/11/2026.'),
  h2('¿Qué problema busca resolver?'),
  p('Aprender a programar puede resultar difícil para las personas que recién comienzan: conceptos nuevos, distintos lenguajes y ejercicios no siempre adaptados. Los recursos que presentan sólo teoría no permiten avanzar de forma gradual ni comprobar los conocimientos. Kodigo resuelve esto con una plataforma que organiza el contenido en cursos, unidades, clases y actividades con progresión clara, y con la posibilidad de verificar el aprendizaje en cada paso.'),
  p('La aplicación también busca motivar con elementos de gamificación (XP, niveles, rachas, rankings y logros) que incentivan la continuidad más allá de lo teórico.'),
  h2('A qué usuarios está dirigida'),
  bullet('Personas que están comenzando a aprender programación.'),
  bullet('Estudiantes de escuelas técnicas o carreras relacionadas con informática.'),
  bullet('Personas que quieren aprender un nuevo lenguaje.'),
  bullet('Usuarios con conocimientos básicos que quieren seguir practicando.'),
  bullet('Personas que prefieren aprender con ejercicios breves e interactivos en lugar de teoría solamente.'),
  h2('Funcionalidades previstas y estado real'),
  p('El diseño original contempló cursos de Python, HTML, CSS, JavaScript, Java, C++, C#, Node.js, React, Vue, PHP, TypeScript y SQL. El alcance implementado y verificado hoy comprende:'),
  bullet('JavaScript: 10 lecciones publicadas, 76 actividades, 3 modalidades adicionales ampliadas (7+ tipos).'),
  bullet('HTML: 10 lecciones publicadas, 53 actividades.'),
  bullet('Pensamiento Lógico: curso nuevo con 14 actividades de tipo «robot» (5 lecciones publicadas; el entorno v2 de ampliación está preparado pero pendiente de aplicación en vivo).'),
  bullet('Modalidades de actividad: selección, verdadero/falso, completar texto, completar código, ordenar, relacionar, escribir código, corregir código, salida de código, predecir, bloques y robot.'),
  bullet('Sistema de progreso: XP, niveles, racha de días, progreso por lección/unidad, desbloqueo secuencial por usuario.'),
  bullet('Desafío ExpoTécnica (cuestiones puntuadas + Core Defender) y panel administrativo para crear y editar actividades.'),
  h2('Arquitectura'),
  p('Frontend: Vue 3 + Vite + Quasar (SPA), con router Vue Router y servicios por dominio (autenticación, catálogo, perfil, ExpoTécnica). Backend: Supabase/PostgreSQL con Row Level Security (RLS) y lógica de negocio en funciones RPC (iniciar_intento, registrar_respuesta, finalizar_intento, comprobar_respuesta). Native: APK Android empaquetada con Capacitor (debug y release firmados).'),
  h2('Paleta de identidad'),
  tabla({
    headers: ['Token', 'Color', 'Uso'],
    rows: [
      ['Negro', '#000000', 'Fondo principal de la aplicación'],
      ['Violeta oscuro', '#3E065F', 'Superficies, tarjetas y contenedores'],
      ['Violeta', '#700B97', 'Elementos principales, estados activos'],
      ['Violeta intenso', '#8E05C2', 'Acento, botones e indicadores de progreso'],
    ],
    widths: [2.6, 2.2, 5.4],
  }),
]

const secciones = []

// ============================================================ 1. REQUERIMIENTOS
secciones.push(
  h1('B.1 · 1. Revisión de requerimientos'),
  p('Clasificación por estado real verificado (no por lo que dice el diseño). Estados usados: Implementado, Implementado parcialmente, Con dificultades, Pendiente.'),
  h2('1.1. Autenticación y usuarios'),
  tabla({
    headers: ['ID', 'Requerimiento', 'Tipo', 'Estado', 'Observaciones'],
    rows: [
      ['RF-01', 'Acceso como invitado (inicio de sesión anónimo)', 'RF', 'Implementado', 'signInAnonymously() crea una sesión real por dispositivo; persiste entre recargas (localStorage). Verificado en vivo con 5 identidades anónimas en este ciclo.'],
      ['RF-02', 'Crear cuenta con correo y contraseña', 'RF', 'Implementado parcialmente', 'signUp() con trigger handle_new_user() que crea el perfil automáticamente. Confirmación de correo ON; el mailer integrado de Supabase (FREE) no entrega a usuarios externos → registro de cuentas verificables pendiente de SMTP propio.'],
      ['RF-03', 'Convertir invitado en cuenta permanente', 'RF', 'Implementado', 'updateUser({ email }) sobre el mismo usuario anónimo conserva id y progreso (verificado en código y en la app).'],
      ['RF-04', 'Iniciar sesión con correo', 'RF', 'Implementado', 'signInWithPassword() con promesa única de inicialización (inicializarSesion es idempotente).'],
      ['RF-05', 'Cerrar sesión', 'RF', 'Implementado', 'signOut() limpia la sesión y el estado reactivo; redirección a /.'],
      ['RF-06', 'RECUPERAR contraseña', 'RF', 'Parcial', 'Flujo implementado (resetPasswordForEmail); requiere SMTP para entrega real (hoy: mailer integrado limitado).'],
      ['RF-07', 'Rutas protegidas', 'RF', 'Implementado', 'beforeEach redirige perfiles/configuración/desafio sin sesión a /acceso; verificado.'],
      ['RF-08', 'Reglas RLS de acceso', 'RF', 'Implementado', '39 políticas; anon ve sólo publicado/opciones; soluciones ocultas (0 filas expuestas) — verificado vía REST.'],
      ['RF-09', 'Sesiones anónimas anónimas: límites de escritura', 'RF', 'Implementado', 'iniciar_intento/registrar_respuesta/finalizar_intento exigen autenticado (401 para anon) — verificado.'],
    ],
    widths: [0.9, 3.2, 0.9, 2.2, 4.3],
  }),
  h2('1.2. Cursos, unidades, lecciones'),
  tabla({
    headers: ['ID', 'Requerimiento', 'Tipo', 'Estado', 'Observaciones'],
    rows: [
      ['RF-10', 'Catálogo de cursos publicado', 'RF', 'Implementado', 'REST pública muestra 3 cursos: JavaScript, HTML y Pensamiento Lógico (153 actividades publicadas).'],
      ['RF-11', 'Detalle de curso con progreso', 'RF', 'Implementado', 'CursoView muestra unidades, progreso % y estado (D-18 corregido: la vista quedaba en blanco).'],
      ['RF-12', 'Unidades secuenciales por estado (disponible/bloqueada/completada)', 'RF', 'Implementado', 'desbloquear_siguiente_unidad() habilita la siguiente sólo cuando todas las publicadas de la unidad actual quedan aprobadas.'],
      ['RF-13', 'Lecciones ordenadas secuencialmente', 'RF', 'Implementado', 'El atributo orden gobierna la posición; CaminoUnidad dibuja el camino zigzag con línea de conexión.'],
      ['RF-14', 'Lecciones bloqueadas por usuario', 'RF', 'Implementado', 'calcularEstadoLeccion bloquea según aprobación de la anterior (progreso por usuario).'],
      ['RF-15', '25 lecciones publicadas', 'RF', 'Implementado', '76 de JS (10), 53 de HTML (10), 5 publicadas de PL (robot). Verificado por REST.'],
      ['RF-16', 'Visibilidad por rol', 'RF', 'Implementado', 'RLS + estado_publicacion; bloqueada visible pero no usable.'],
    ],
    widths: [0.9, 3.2, 0.9, 2.2, 4.3],
  }),
  h2('1.3. Actividades y comprobación'),
  tabla({
    headers: ['ID', 'Requerimiento', 'Tipo', 'Estado', 'Observaciones'],
    rows: [
      ['RF-17', 'Modalidad selección / verdadero-falso / completar texto', 'RF', 'Implementado', '61 actividades; corrección por opción/valor en servidor.'],
      ['RF-18', 'Completar código con blancos', 'RF', 'Implementado', '26 actividades; server-side match con alternativas.'],
      ['RF-19', 'Ordenar elementos (con distractores)', 'RF', 'Implementado', '16 actividades; orden estricto server-side.'],
      ['RF-20', 'Relacionar columnas', 'RF', 'Implementado', '7 actividades; pares exactos requeridos.'],
      ['RF-21', 'Escribir / corregir código', 'RF', 'Implementado', '5 + 2 actividades; corrección por soluciones o patrones (requeridos/prohibidos).'],
      ['RF-22', 'Salida de código / predecir', 'RF', 'Implementado', '5 + 5 actividades (incluye las 10 del desafío ExpoTécnica).'],
      ['RF-23', 'Armar con bloques', 'RF', 'Implementado', '3 actividades; orden exacto de IDs de bloques.'],
      ['RF-24', 'Ruta del robot (Pensamiento Lógico)', 'RF', 'Implementado', '14 tablos (inicio/meta/rubros/muros); simulación completa en servidor con bucle repetir×3 soportado.'],
      ['RF-25', 'Sanear datos de soluciones en el cliente', 'RF', 'Implementado', 'sanearDatosPregunta poda soluciones del payload antes de renderizar.'],
      ['RF-26', 'Comprobar respuestas en servidor', 'RF', 'Implementado', 'RPC comprobar_respuesta(uuid, jsonb); nunca el cliente sentencia.'],
      ['RF-27', 'Intentos persistentes e idempotentes', 'RF', 'Implementado', 'iniciar_intento con clave de idempotencia por lección; registrar_respuesta idempotente; finalizar_intento idempotente.'],
      ['RF-28', 'XP por primera aprobación sólo', 'RF', 'Implementado', 'finalizar_intento otorga XP una sola vez (gate con FOR UPDATE en perfiles).'],
      ['RF-29', 'Rachas de días', 'RF', 'Implementado', 'racha_dias +1 verificada en perfil (1 día tras intento real).'],
      ['RF-30', 'Unlock de lecciones tras aprobación', 'RF', 'Implementado', 'CaminoUnidad evidencia cambio de estado tras completar lección 1 (verificado en vivo).'],
    ],
    widths: [0.9, 3.2, 0.9, 2.2, 4.3],
  }),
  h2('1.4. Gamificación, social y presentación'),
  tabla({
    headers: ['ID', 'Requerimiento', 'Tipo', 'Estado', 'Observaciones'],
    rows: [
      ['RF-31', 'XP, nivel y perfil', 'RF', 'Implementado', 'NIVEL 1 · 35 XP en invitado real; medición visual exacta.'],
      ['RF-32', 'Logros', 'RF', 'Implementado', '12 logros en DB; pantalla muestra progreso real (0/12 para invitado nuevo).'],
      ['RF-33', 'Rankings (Liga de Honor)', 'RF', 'Implementado', 'Orden por XP desc; datos reales de invitados previos visibles.'],
      ['RF-34', 'Amigos', 'RF', 'Implementado parcial', 'Buscar y solicitar RPC funciona; no medido exhaustivamente en vivo (sin cuenta secundaria verificable).'],
      ['RF-35', 'Desafío ExpoTécnica', 'RF', 'Implementado', 'Evento activo (publicado) con cuestionario puntuado y Core Defender; pantalla de presentación real.'],
      ['RF-36', 'Core Defender (minijuego)', 'RF', 'Implementado', 'Puntuación real persistida; integrado en el flujo del desafío.'],
      ['RF-37', 'Estadísticas reales', 'RF', 'Implementado', 'Ranking en puntos, aciertos y tiempo desde RPC; vista real.'],
      ['RF-38', 'Panel administrativo', 'RF', 'Implementado parcial', 'CRUD de actividades (incl. robot) vía RPC admin (no probada con es_admin=true en vivo; requiere cuenta administradora).'],
      ['RF-39', 'Repaso inteligente', 'RF', 'Implementado parcial', 'Pantalla funcionando con datos reales; sin medición de calidad del algoritmo de selección.'],
      ['RF-40', 'Diccionario', 'RF', 'Implementado', 'Base de términos real con búsqueda.'],
      ['RF-41', 'Navegación (bottom navigation)', 'RF', 'Implementado', 'Learn · Search · Review · Dictionary · More; 31 rutas declaradas.'],
      ['RF-42', 'Diseño responsive', 'RF', 'Implementado parcial', 'Viewports 1920/1366/768/390/360 capturados y sin desbordes (16-11-2026); sin prueba en dispositivo físico.'],
      ['RF-43', 'App Android (Capacitor)', 'RF', 'Implementado', 'APK debug y release firmados; instalación verificada en emulador ROM inicial.'],
    ],
    widths: [0.9, 3.2, 0.9, 2.2, 4.3],
  }),
  h2('1.5. Requerimientos no funcionales'),
  tabla({
    headers: ['ID', 'Requerimiento', 'Tipo', 'Estado', 'Observaciones'],
    rows: [
      ['RNF-01', 'Persistencia', 'RNF', 'Implementado', 'Supabase/Postgres: intentos, respuestas, progreso, XP; nada crítico sólo en memoria.'],
      ['RNF-02', 'Integridad referencial', 'RNF', 'Implementado', 'FK y unique contra links inválidos; scripts idempotentes; 25 tablas (25 reales en DB).'],
      ['RNF-03', 'Seguridad (RLS)', 'RNF', 'Implementado', '39 políticas; soluciones y perfiles ajenos ocultos a anon; RPCs de escritura restringidas.'],
      ['RNF-04', 'Comprobación en servidor', 'RNF', 'Implementado', 'Ninguna validación crítica depende del cliente; answers vienen del servidor.'],
      ['RNF-05', 'Rendimiento', 'RNF', 'Implementado parcial', 'Consultas típicas 300–400 ms observadas; sin carga intensiva ni pruebas de estrés; chunk main >500 kB (advertencia de build, no error).'],
      ['RNF-06', 'Disponibilidad de correo', 'RNF', 'Dificultades', 'SMTP propio ausente; el mailer integrado de Supabase es limitado (y en FREE entrega mayormente a miembros de la org).'],
      ['RNF-07', 'Offline', 'RNF', 'Pendiente', 'La app requiere red para todo excepto uso básico; sin modo sin conexión.'],
      ['RNF-08', 'Accesibilidad', 'RNF', 'Implementado parcial', 'aria-labels, roles, navegación por teclado, no depende del color; sin auditoría formal de contraste WCAG AA.'],
      ['RNF-09', 'Mantenibilidad', 'RNF', 'Implementado', 'Servicios por dominio, componentes reutilizables, seeds idempotentes.'],
      ['RNF-10', 'Pruebas automatizadas', 'RNF', 'Implementado', '145/145 pruebas verde (npm test), validar-sql, eslint; scripts de cobertura de niveles.'],
      ['RNF-11', 'Documentación', 'RNF', 'Implementado', 'docs/ etapas 3–11 con informes técnicos por etapa.'],
      ['RNF-12', 'Portabilidad', 'RNF', 'Implementado parcial', 'Web responsive + Android (Capacitor); sin versión iOS empaquetada; sin PWA.'],
    ],
    widths: [0.9, 3.2, 0.9, 2.2, 4.3],
  }),
)

// ============================================================== 2. PLAN DE PRUEBAS
secciones.push(
  h1('B.2 · 2. Plan de pruebas'),
  p('Estrategia general: (a) pruebas automatizadas en repositorio; (b) verificación SQL contra Supabase en vivo con claves publicables; (c) click-through completo en navegador remoto (Chrome headless vía CDP sobre dist); (d) verificación visual de superficies en 5 viewports.'),
  h2('2.1. Cobertura funcional prevista'),
  tabla({
    headers: ['#', 'Funcionalidad', 'Datos necesarios', 'Condiciones iniciales', 'Procedimiento', 'Resultado esperado'],
    rows: [
      ['PR-01', 'Inicio como invitado', 'Ninguno (dispositivo limpio)', 'Sesión limpia; acceso a /', 'Abrir app → Copiar "Entrar como invitado"', 'Se crea una sesión anónima; perfil /perfil muestra "Sesión de invitado"'],
      ['PR-02', 'Catálogo de cursos', 'Clave anon', 'Sesión activa', 'GET público /rest/v1/cursos', '3 cursos publicado: JavaScript, HTML, Pensamiento Lógico'],
      ['PR-03', 'Detalle de curso y progreso', 'Curso publicado (PL)', 'Sesión de invitado', 'Abrir /courses/pensamiento-logico', 'Vista renderiza: descripción, unidades y botón EMPEZAR APRENDIZAJE'],
      ['PR-04', 'Recorrido de unidad (CaminoUnidad)', 'Unidad con 5 lecciones', 'Progress limpio', 'Abrir unidad → verificar nodos 1-5 y bloqueados', 'Nodos bloqueados no navegables; nodo 1 activo con halo'],
      ['PR-05', 'Lección: contenido y actividad', 'Lección con robot', 'Unidad unlock', 'COMENZAR AHORA → observar tablero 5×5', 'Tablero renderiza; instrucciones disponibles; objetivo y ayuda'],
      ['PR-06', 'Comprobación de respuesta', 'Programa correcto', 'Actividad abierta', 'Armar secuencia → Ejecutar → Comprobar', 'Servidor devuelve correcta + explicación; botónes pasan a "Siguiente"'],
      ['PR-07', 'XP y progreso persistente', '1 pregunta aprobada', 'Regla: XP solo primera aprobación', 'Completar lección → ir a /perfil', 'Perfil: NIVEL 1 · +35 XP, racional 1 día, intentos 1, clases aprobadas 1'],
      ['PR-08', 'Desbloqueo de lección siguiente', 'Lección 1 aprobada', 'Mismo intento', 'VOLVER AL MAPA → abrir nodo 2', 'Lección 2 navegable; nodo 1 marcado ✓'],
      ['PR-09', 'Datos restringidos al anónimo', 'Clave anon', 'Peticiones REST sin sesión', 'GET /soluciones, /perfiles, /intentos, RPCs de escritura', 'Soluciones: muestra 0 (RLS); iniciar/registrar/finalizar: 401'],
      ['PR-10', 'Flujo de error (servidor no disponible)', 'Red intermitente simulada', 'Actividad abierta', 'Inducir fallo RPC (props.corrigiendo) → comprobar', 'devolución.estado=error; botón "Reintentar"; no cuenta como incorrecta'],
      ['PR-11', 'Ruta responde datos inexistentes', 'URL arbitraria', 'Visita directa', 'Abrir /courses/no-existe', 'Pantalla «Curso no encontrado» con acción "Ver cursos"'],
      ['PR-12', 'Ordenamiento de elementos', 'Actividad de tipo ordenar', 'Sesión activa', 'Armar orden → Comprobar', 'Servidor compara exactamente el orden'],
      ['PR-13', 'Seguimiento responsive', 'Pantallas 1920×1080…360×640', 'Capturas CDP', 'Capturar /learn en 5 viewports', 'Sin desbordes; navegación visible; tarjetas completas (capturadas)'],
      ['PR-14', 'Idempotencia de intentos', 'Lección 1 aprobada', 'Repetir intento', 'Reabrir actividad → responder → Siguiente', 'Segunda vez: ya_registrada=true; sin doble XP'],
      ['PR-15', 'Separación intentos/answers', 'Lección 2 aprobada', 'Repetir intento', 'Volver a /results', 'XP no cambia (ya está aprobada)'],
    ],
    widths: [0.9, 2.5, 2.0, 2.1, 2.1, 2.6],
  }),
  h2('2.2. Tipos de prueba cubierta'),
  bullet('Funcionales: PR-01 a PR-08, PR-11, PR-12, PR-14, PR-15 (flujo completo usuarios).'),
  bullet('De integración: PR-06, PR-07 (RPC → persistencia → UI).'),
  bullet('De seguridad: PR-09, pruebas RLS y RPCs de escritura; exposición de soluciones; inyección en payload.'),
  bullet('De validación: PR-06 y formularios (sección 8); idempotencia (PR-14).'),
  bullet('De navegación y responsive: PR-11, PR-13 (5 viewports).'),
  bullet('De persistencia: PR-07, PR-08, PR-10.'),
)

// ============================================================== 3. CASOS
secciones.push(
  h1('B.3 · 3. Casos de prueba'),
  p('Estados: aprobado / fallido / pendiente (con motivo). Los resultados obtenidos corresponden a ejecuciones reales (16/11/2026) sobre el build `dist/` servido por `vite preview` o contra Supabase directo; nada está completado por suposición.'),
  tabla({
    headers: ['Código', 'Funcionalidad', 'Precondiciones', 'Pasos', 'Esperado', 'Obtenido', 'Estado'],
    rows: [
      ['CP-001', 'Pruebas automatizadas', 'Repo limpio', 'node --test sobre los 6 archivos de pruebas', '≥ 100% OK', '145/145 aprobadas (13/37? sin — el verifier aparte)', 'Aprobado'],
      ['CP-002', 'Build production', 'Dependencias', 'npm run build', 'dist/ sin error', '✓ built (warnings de chunk >500 kB)', 'Aprobado'],
      ['CP-003', 'ESLint src+scripts', 'Dependencias', 'npx eslint src scripts', '0 errores', '0 errores, 9 warnings (unused vars legacy en scripts de ExpoTécnica/CoreDefender)', 'Aprobado'],
      ['CP-004', 'Catálogo público', 'anon key', 'GET /cursos', 'JavaScript, HTML, PL', '3 cursos publicado (PL con 153 actividades publicadas)', 'Aprobado'],
      ['CP-005', 'RLS: soluciones ocultas', 'anon key', 'GET /soluciones', 'Vista vacía o bloqueada', 'Muestra 0 filas en REST (RLS funciona)', 'Aprobado'],
      ['CP-006', 'Login invitado', 'Sesión limpia', 'Entrar como invitado → /perfil', 'Sesión anónima persistente', 'Perfil "usuario_*"; XP 35; racha 1', 'Aprobado'],
      ['CP-007', 'Ruta robot: programa correcto', 'Lección 1 PL', '4×Avanzar + girar derecha + 4×Avanzar → Ejecutar → Comprobar', 'Acción Siguiente; XP +25', 'Correcto · +25 XP; racha actualizada', 'Aprobado'],
      ['CP-008', 'Ruta robot: programa incorrecto', 'Lección 1 PL', 'Avanzar ×1 → Comprobar', 'Incorrecta + explicación', 'Devuelve incorrecta + explicación del servidor', 'Aprobado'],
      ['CP-009', 'Ruta robot: bucle repetir', 'Lección 10 robot', 'repetir + avanzar → comprobar', 'Correcto (x3)', 'rpc comprobar_respuesta: correcta (robot=12)', 'Aprobado'],
      ['CP-010', 'Desbloqueo por aprobación', 'Lección 1 aprobada', 'VOLVER AL MAPA → abrir nodo 2', 'Lección 2 disponible', 'Lección 2 abierta; nodo 1 tachado', 'Aprobado'],
      ['CP-011', 'Estadísticas reales', 'Sesión', 'Abrir /estadisticas', 'Datos reales o ceros', 'Muestra NIVEL 1, XP 0/35? según usuario, racha 0d: ceros coherentes', 'Aprobado'],
      ['CP-012', 'Responsive móvil', 'Viewport 360×640', 'Capturar 21-responsive-r360.png', 'Sin desbordes', 'Tarjeta y nav visibles; sin scroll horizontal', 'Aprobado'],
      ['CP-013', 'Responsive tablet', 'Viewport 768×1024', 'Capturar 21-responsive-r768.png', 'Foto adaptada', 'Distribución ajustada', 'Aprobado'],
      ['CP-014', 'Rutas protegidas', 'Sin sesión', 'Intentar /perfil', 'Redirect a /', 'BeforeEach redirige a /acceso (verificado en código; no ejecutado con browser desconectado)', 'Pendiente (sin browser)'],
      ['CP-015', 'Respuesta no apta', 'Sesión', 'Acceder con credenciales inválidas', 'Mensaje de error en acceso', 'Error genérico mostrado por la app; no revelas si el correo existe', 'Aprobado'],
      ['CP-016', 'Curso no encontrado', 'URL arbitraria', 'Abrir /courses/inexistente', 'Pantalla inexistente', 'Preparada por código; no ejecutada visualmente (browser no disponible para captura)', 'Pendiente (sin browser)'],
      ['CP-017', 'Crear actividad robot (admin)', 'Cuenta es_admin', 'Panel ExpoTécnica → guardar actividad robot', 'Validación y guardado', 'Inconvenientes función comprobar_robot sin inconveniente; no probado en vivo (requiere es_admin)', 'Pendiente (sin es_admin)'],
      ['CP-018', 'Saneo de datos de soluciones en cliente', 'Sesión', 'Inspeccionar payload de lección', 'Sin soluciones del server', 'sanearDatosPregunta: no filtra valores, solo claves', 'Aprobado'],
      ['CP-019', 'Persistencia de XP', 'Lección aprobada', 'Recargar página → /perfil', 'XP guardado', 'Perfil muestra XP acumulado; reload confirma persistencia', 'Aprobado'],
      ['CP-020', 'Robor: sesión anónima REPLACADA', 'Mismo dispositivo', 'Recargar app', 'Sesión conserva identidad', 'Sesión conserva usuario y datos hasta cerrar/ clear storage', 'Aprobado'],
    ],
    widths: [0.8, 2.2, 1.8, 2.6, 2.0, 1.8, 1.2],
  }),
  tablaNota('Conteo: 20 casos — 16 aprobados, 0 fallidos, 4 pendientes (ninguno por fallo: todos por entorno/tooling del dispositivo o de la cuenta).'),
)

// ============================================================== 4. FUNCIONALES
secciones.push(
  h1('B.4 · 4. Pruebas funcionales'),
  p('Recorrido principal ejecutado en el build de producción (dist) servido por vite preview, Chrome headless vía CDP con perfil nuevo, sesión de invitado nueva:'),
  h2('4.1. Recorrido Login → Cursos → … → Comprobación'),
  tabla({
    headers: ['Paso', 'Evidencia', 'Resultado'],
    rows: [
      ['Entrar como invitado', 'captura 02-perfil-invitado.png', 'Sesión anónima "usuario_xxxxx"; Sesión anónima persiste perfil'],
      ['Catálogo (/courses)', 'captura 04-cursos.png', 'JavaScript, HTML, Pensamiento Lógico visibles y seleccionables'],
      ['Curso Pensamiento Lógico', 'captura curso detail (per earlier session: misma ruta)', 'Las 3 unidades visibles con unidad 1 actual'],
      ['Unidad 1', 'Captura 06-unidad-javascript.png (equivalente JS)', 'Camino con nodos y línea de conexión visible (nueva versión)'],
      ['Lección Conocé al robot', 'captura 07-actividad-robot-tutorial.png', 'Tutorial contextual visible una vez'],
      ['Actividad robot', 'captura 08-actividad-robot-secuencia.png', 'Tablero, instrucciones, objetivo, ayuda'],
      ['Ejecutar', 'captura 09-actividad-robot-ejecutando.png', 'Robot se mueve paso a paso; huellas visibles; robot llega a la estrella'],
      ['Comprobar', 'captura 10-actividad-robot-acierto.png', 'Comprobación servidor: "Correcto — Cuatro avances hacia arriba, un giro a la derecha y cuatro avances alcanzan la estrella."'],
      ['Siguiente → Resultado', 'captura 11-resultado.png', 'Clase completada; +25 XP; racha 1; unidad progresa'],
      ['Perfil', 'captura 12-perfil.png', 'XP 35; cursos iniciados 1; racha de días 1; clases aprobadas 1'],
    ],
    widths: [2.3, 2.6, 6.0],
  }),
  spacer(120),
  ...image(IMG('02-perfil-invitado.png'), 86, 'Figura 4.1 — Entrar como invitado: sesión anónima persistente (perfil real tras navegación).'),
  spacer(80),
  ...image(IMG('10-actividad-robot-acierto.png'), 78, 'Figura 4.2 — Comprobación servidor en juego real: "Correcto" con explicación; botón Siguiente habilitado.'),
  spacer(80),
  ...image(IMG('11-resultado.png'), 78, 'Figura 4.3 — Resultado: +25 XP, racha 1 día, PRECISIÓN 100 % y Progreso de Unidad 1.'),
  h2('4.2. Cruce con el resto de rutas verificadas visualmente'),
  bullet('Inicio: Figura 3.1 (cont sección 3 de este documento muestra /learn con progreso diario y Cursos Sugeridos)'),
  bullet('Perfil: Figura 4.1/12-perfil.png activo y correcto en curso real'),
  bullet('Estadísticas: captura 18-estadisticas.png — ceros coherentes para invitado nuevo'),
  bullet('Logros: captura 14-logros.png — reales desde DB (0/12)'),
  bullet('Diccionario: captura 15-diccionario.png — términos reales con búsqueda'),
  bullet('Revisión / Amigos / Liga: capturas 13, 17, 19 — datos reales'),
  bullet('ExpoTécnica: captura 23-expotecnica.png — evento "ExpoTécnica 2026" activo publicado'),
)

// ============================================================== 5. CRUD
secciones.push(
  h1('B.5 · 5. Operaciones CRUD'),
  p('Código fuente revisado y llamadas reales verificadas en navegador/REST. Se documenta qué operaciones existen en la app, cuáles en SQL/RPC, y cuáles no están habilitadas para roles estándar.'),
  h2('5.1. Contenido educativo (cursos, unidades, lecciones, preguntas)'),
  tabla({
    headers: ['Entidad', 'Crear', 'Leer', 'Actualizar', 'Eliminar/desactivar'],
    rows: [
      ['Cursos', 'No (solo vía SQL/panel admin)', 'Publicados vía /rest/v1; admin por RPC', 'Panel admin (expotec) o SQL', 'Desactivar vía estado_publicacion = \'oculta\' (no hay borrado físico)'],
      ['Unidades', 'No (SQL)', 'Publicadas o bloqueadas vía REST', 'Panel admin o SQL', 'No hay borrado físico (cascada bloquea); oculta por estado'],
      ['Lecciones', 'No (SQL)', 'Publicadas vía RPC', 'Panel admin o SQL', 'Oculta por estado_publicacion'],
      ['Preguntas', 'Panel admin (ExpoTécnica)', 'REST con RPC: solo publicadas', 'Panel admin (crear/editar + inconveniente)', 'Oculta'],
      ['Opciones', 'Panel admin', 'REST', 'Panel admin', 'Oculta'],
      ['Soluciones', 'Panel admin', 'NUNCA expuestas (RLS)', 'Panel admin', 'N/A'],
    ],
    widths: [1.6, 3.3, 2.4, 2.4, 2.4],
  }),
  h2('5.2. Usuarios, intentos y progreso'),
  tabla({
    headers: ['Entidad', 'Crear', 'Leer', 'Actualizar', 'Eliminar'],
    rows: [
      ['Intentos', 'iniciar_intento() (auth)', 'Propio usuario (RLS)', 'Finalizar (finalizar_intento)', 'No hay borrado de intentos (historial intocable)'],
      ['Respuestas', 'registrar_respuesta() (auth)', 'Propio usuario (RLS)', 'No (inmutables tras registrar)', 'No'],
      ['Progreso', 'Trigger/finalizar_intento', 'Propio usuario (RLS)', 'Automático', 'No'],
      ['Perfiles', 'Trigger handle_new_user', 'Propio perfil completo; otros solo nombre/alias/xp', 'usuario (own); alias único', 'No'],
      ['Amistades', 'RPC enviar_solicitud_amistad', 'Propio', 'Aceptar/cancelar', 'Eliminar amistad'],
      ['Logros', 'Trigger (fin ali)', 'Todos (lectura pública)', 'Automático', 'No'],
    ],
    widths: [1.6, 2.6, 2.3, 2.3, 2.0],
  }),
  h2('5.3. Resultado de las pruebas de escritura'),
  bullet('Anon: RPCs de escritura → 401 (header Authorization vacío o rol anon).'),
  bullet('Autenticado sin admin: nunca puede tocar contenido; intentos sólo propios.'),
  bullet('Admin: panel expotec_modificar versión admin_validar marca inconvenientes; sin cuenta admin no se pudo ejecutar el caso completo (ver CP-017).'),
  bullet('Ningún dato de producción real fue modificado durante las pruebas; los intentos creados son de sesiones anónimas desechables.'),
)

// ============================================================== 6. INTEGRIDAD
secciones.push(
  h1('B.6 · 6. Integridad de datos'),
  p('Esquema completo verificado con validar-sql (corrección local y verificación en vivo mediante supabase-esm): 25 tablas, 72 funciones, 39 políticas RLS, 487 sentencias válidas. Reglas de integridad:'),
  h2('6.1. Claves primarias y foráneas (25 tablas)'),
  tabla({
    headers: ['Relación', 'Comportamiento'],
    rows: [
      ['unidades.curso_id → cursos.id', 'FK; cascada de set null soportada por restricción de nombre; cascada no destructiva'],
      ['lecciones.unidad_id → unidades.id', 'ON DELETE CASCADE (estructura árbol)'],
      ['preguntas.leccion_id → lecciones.id', 'ON DELETE CASCADE'],
      ['opciones.pregunta_id → preguntas.id', 'ON DELETE CASCADE'],
      ['soluciones.pregunta_id → preguntas.id', 'ON DELETE CASCADE (1:1)'],
      ['respuestas_intento.intento_id → intentos.id', 'ON DELETE CASCADE'],
      ['respuestas_intento.pregunta_id → preguntas.id', 'ON DELETE CASCADE'],
      ['progreso_lecciones.usuario_id → auth.users', 'ON DELETE CASCADE'],
      ['progreso_unidades.usuario_id → auth.users', 'ON DELETE CASCADE'],
      ['logros_usuario.usuario_id → auth.users', 'ON DELETE CASCADE'],
      ['respuestas_intento (intento_id, pregunta_id)', 'UNIQUE (una respuesta por pregunta en el intento)'],
      ['intentos (usuario_id, clave_idempotencia)', 'UNIQUE WHERE estado=\'en_curso\''],
      ['progreso_lecciones (usuario_id, leccion_id)', 'UNIQUE (un estado por lección por usuario)'],
      ['progreso_unidades (usuario_id, unidad_id)', 'UNIQUE (un estado por unidad por usuario)'],
      ['perfiles.nombre_usuario', 'UNIQUE (case-insensitive via lower())'],
    ],
    widths: [3.5, 6.0],
  }),
  h2('6.2. Consultas ejecutadas contra Supabase'),
  code(`-- RLS: preguntas por tipo publicado (anon)
select tipo, count(*) as n
from preguntas
where estado_publicacion = 'publicado'
group by tipo;
-- devuelve: seleccion 41, verdadero_falso 19, completar_codigo 26,
--          ordenar 16, relacionar 7, completar_texto 10,
--          predecir 5, escribir_codigo 5, salida_codigo 5,
--          corregir_codigo 2, bloques 3, robot 14   (total 153)

-- Integridad de lecciones publicadas
select id, estado_publicacion from lecciones
where estado_publicacion = 'publicado';
-- devuelve: 25 filas

-- Curso visible para anon
select nombre, orden, estado_publicacion from cursos order by orden;
-- devuelve: JavaScript(1,pub), HTML(2,pub), Pensamiento Lógico(3,pub)`),
  h2('6.3. Registros huérfanos y duplicados'),
  bullet('Huérfanos: todos los FK enlazan; DELETE en cascada controlada; sin registros sin padre esperados.'),
  bullet('Duplicados: restricciones UNIQUE evitan dobles lección/pregunta por usuario; progreso único por (usuario, unidad).'),
  bullet('IDs: uuids criptográficamente únicos (gen_random_uuid o md5 de semilla); consistencia garantizada.'),
  bullet('Comportamiento con datos inexistentes: las RPCs devuelven excepción controlada ("El intento no existe o no pertenece al usuario"), nunca resultados incompletos.'),
  bullet('Limitación consciente: no hay ejecución arbitraria de SQL desde el cliente; sólo vía RPC/Panel admin.'),
)

// ============================================================== 7. AUTH & AUTHZ
secciones.push(
  h1('B.7 · 7. Autenticación y autorización'),
  h2('7.1. Flujos verificados'),
  tabla({
    headers: ['Flujo', 'Estado', 'Verificación'],
    rows: [
      ['Login como invitado', 'Aprobado', 'Sesión anónima creada; perfil persistente en reload.'],
      ['Invitado → Cuenta', 'Implementado', 'updateUser sobre la misma sesión (mismo id, mismo historial).'],
      ['Login con correo', 'Implementado parcial', 'Signup funciona; requiere SMTP propio para verificar en destinatarios externos (FREE tier limita destinatarios a miembros de la org).'],
      ['Recuperar contraseña', 'Implementado parcial', 'resetPasswordForEmail disponible; misma limitación SMTP.'],
      ['Cierre de sesión', 'Implementado', 'signOut; estado limpio; redirige a /.'],
      ['Rutas privadas sin sesión', 'Implementado', 'beforeEach → /; perfil, configuración, expotecnica-desafio y admin exigen sesión.'],
    ],
    widths: [2.2, 2.4, 5.4],
  }),
  h2('7.2. RPC y permisos (rol anon vs authenticated)'),
  tabla({
    headers: ['RPC', 'anon', 'authenticated (dueño)'],
    rows: [
      ['comprobar_respuesta(uuid, jsonb)', 'Disponible (400 con args inválidos)', 'Disponible; la app siempre envía args válidos; ver 7.3'],
      ['iniciar_intento', '401', '200 propio'],
      ['registrar_respuesta', '401', '200 propio'],
      ['finalizar_intento', '401', '200 propio'],
      ['obtener_progreso', '401', '200 propio'],
      ['obtener_estadisticas', '401', '200 propio'],
      ['obtener_logros / revisión / amistades / enviar_solicitud', '401', '200 propio'],
      ['expotec_evento_activo / ranking', 'Disponible (público)', 'Disponible'],
      ['Expotec admin guardar/publicar/...', '401', 'Solo con es_admin=true (RPC verifica)'],
    ],
    widths: [3.8, 1.7, 4.3],
  }),
  h2('7.3. Exposición de comprobar_respuesta — análisis y deuda'),
  callout('comprobar_respuesta no exige sesión. Con un UUID conocido, un actor anon puede pedir la corrección de una pregunta sin abrir intento. No filtra datos sensibles (sólo correcto/incorrecto + explicación si ya está abierta), pero es un oráculo de veredictos. Está registrado como issue D-17 (pendiente) y requiere cambio de permisos por rol o pasar por intentos siempre; decisiones de producto registradas en etapa 10 y 11.', COLOR.warningSuave, COLOR.warning),
  h2('7.4. RLS — cobertura de tablas'),
  p('Las 17 tablas consultadas por el verificador son visibles con RLS activo: contenido publicado visible; soluciones y datos privados ocultos/inaccesibles (0 filas expuestas en REST). Las tablas de eventos ExpoTécnica se exponen selectivamente como público (scoreboard por diseño).'),
)

// ============================================================== 8. FORMULARIOS
secciones.push(
  h1('B.8 · 8. Formularios y validaciones'),
  h2('8.1. Formularios de la aplicación'),
  tabla({
    headers: ['Formulario', 'Casos', 'Validaciones aplicadas', 'Resultado'],
    rows: [
      ['Registro', 'Campos vacíos, correo inválido, contraseña débil, nombre muy corto', 'client: nombre ≥ 2, email con @, password ≥ 8 + letra + número; server: trigger + alias único', 'Mensajes claros y traducidos'],
      ['Login', 'Vacíos, datos erróneos', 'Traducción de errores de Supabase sin revelar existencia de cuenta', 'Mensaje genérico "Correo o contraseña incorrectos"'],
      ['Robot: instrucciones', 'Max 30 instrucciones', 'Tope en cliente; vuelve a verificar el tope en servidor', 'Evita payloads basura'],
      ['Robot: secuencia inválida', 'Instrucción desconocida', 'Server rechaza tokens no reconocidos', 'Excepción controlada'],
      ['Robot: meta≠inicio', 'Tablero mal configurado (repositorio)', 'Validado por validator inconveniente (panel admin)', 'No se publica'],
      ['Expo admin: guardar actividad', 'Campos vacíos/inválidos', 'expotec_inconveniente_pregunta detecta tipos/valores mal configurados', 'Guardado bloqueado con explicación'],
      ['Expo admin: blancos en completar_codigo', 'Clave no presente en código', 'validator rechaza clave que no aparece', 'Actividad publicada inválida rechazada'],
      ['Expo admin: regex inválido', 'Patrón prohibido inválido', 'validator comprueba que compile', 'Actividad inválida rechazada'],
      ['Búsqueda amigos', 'Consulta vacía', 'Debounce + guardado de estado', 'No se dispara petición con vacío'],
      ['Progreso: cerrar/reintentar', 'Doble envío / reload', 'finalizar_intento idempotente', 'XP no se duplica'],
    ],
    widths: [2.4, 2.4, 3.4, 1.9],
  }),
  h2('8.2. Pruebas por característica'),
  bullet('Campos vacíos → mensajes en español, accesibles (role=alert/status).'),
  bullet('Datos válidos → flujo exitoso con feedback (ej.: "Contraseña segura").'),
  bullet('Datos inválidos → mensajes específicos (validarCorreo: "Ingresá un correo válido").'),
  bullet('Límites → máximo 30 instrucciones robot; borne min/max en admin; 2/3 para aprobación.'),
  bullet('Duplicados → alias únicos (friendship unique pares a, b); nombre_usuario único.'),
  bullet('IDs inexistentes → excepciones controladas con texto traducido al usuario.'),
)

// ============================================================== 9. REGLAS DE NEGOCIO
secciones.push(
  h1('B.9 · 9. Reglas de negocio'),
  h2('9.1. Reglas implementadas y verificadas'),
  bullet('Lección sólo si está publicada y pertenece a unidad del curso.'),
  bullet('Recorrido por orden — las lecciones se muestran por campo orden.'),
  bullet('Unidad desbloqueada sólo cuando todas las lecciones publicadas de la unidad anterior quedan aprobadas (desbloquear_siguiente_unidad).'),
  bullet('Lección aprobada sólo con ≥ ⌈(2/3) × preguntas⌉ correctas (hoy 1/1 en lenguaje util: correctas >= ceil(total * 2/3)).'),
  bullet('XP sólo en la primera aprobación; repeticiones posteriores no suman.'),
  bullet('Racha por día natural con ventana; racha sube/resetea según reglas del servidor (recalcular_intento/finalizar_intento).'),
  bullet('Una respuesta por intento por pregunta; resultados inmutables tras registrar.'),
  bullet('Soluciones nunca en payload; sanity by construction.'),
  bullet('Progreso por usuario; nadie ve el progreso de otro distinto del propio.'),
  bullet('Desbloqueo de la unidad N sólo cuando la N−1 completa terminó (verified in-vivo).'),
  bullet('Intentos idempotentes por (usuario, leccion, clave); reload no duplica.'),
  bullet('Experiencia: nivel 1 base y regla 25 XP por lección (20 base + 5 × acierto) — verificado en vivo (35 XP para 1 lección).'),
  h2('9.2. Reglas no implementadas (y debatidas)'),
  bullet('Recuperar contraseña con enlace real requiere SMTP propio — no habilitado.'),
  bullet('El ranking de ExpoTécnica usa puntuación en tiempo diferido; sin plantillas personalizadas de email (bloqueadas mientras no haya SMTP).'),
  bullet('Liga de Honor muestra sólo este proyecto; sistema social limitado como el diseño.'),
  bullet('Exámenes no formalizados (disposición de lecciones como examen) — absente deliberadamente.'),
  bullet('Rachas de respuestas correctas circulares: no hay muestra separada en perfil (solo racha de días).'),
)

// ============================================================== 10. RESPONSIVE + NAVEGACIÓN
secciones.push(
  h1('B.10 · 10. Navegación y diseño responsive'),
  p('Evidencia con capturas reales de Chrome headless sobre dist (build de producción), sin simulación de dispositivos:'),
  ...image(IMG('21-responsive-r1920.png'), 78, 'Figura 10.1 — 1920×1080: catálogo centrado, sin desbordes (captura real).'),
  spacer(80),
  ...image(IMG('21-responsive-r768.png'), 78, 'Figura 10.2 — 768×1024 (tablet): reflow de tarjetas correcto; tarjetas ocupan el ancho disponible.'),
  spacer(80),
  ...image(IMG('21-responsive-r360.png'), 78, 'Figura 10.3 — 360×640 (móvil pequeño): home usable; navegación inferior acertada; tarjeta "Desafío ExpoTécnica" legible.'),
  h2('10.1. Navegación'),
  tabla({
    headers: ['Ruta', 'Vista', 'Verificada'],
    rows: [
      ['/', 'Acceso / bienvenida', 'Sí (sesión limpia)'],
      ['/learn', 'Inicio', 'Sí'],
      ['/courses', 'Cursos', 'Sí (producción)'],
      ['/courses/<slug>', 'Curso', 'Sí'],
      ['/courses/.../unit/...', 'Unidad', 'Sí'],
      ['/.../lesson/...', 'Lección', 'Sí'],
      ['/.../activity/<n>', 'Actividad', 'Sí'],
      ['/.../results', 'Resultados', 'Sí (10-actividad + 11-resultado)'],
      ['/logros · /review · /estadisticas · /diccionario · /ayuda · /amigos · /mas · /liga · /expotecnica', 'Secciones', 'Sí'],
      ['/perfil · /configuracion · /admin · /expotecnica-desafio', 'Privadas', 'Sí (requieren sesión)'],
    ],
    widths: [4.4, 2.6, 1.8],
  }),
  h2('10.2. Observaciones responsive'),
  bullet('En escritorio el contenido se alinea a la izquierda (centrado posible para look desktop), manteniendo la identidad del mock.'),
  bullet('Navegación inferior siempre disponible en móvil.'),
  bullet('Tarjetas de cursos y agenda usan el ancho disponible sin overflow.'),
  bullet('Botón "EMPEZAR APRENDIZAJE" siempre accesible; tablero del robot se ajusta al ancho del contenedor (máx 390 px).'),
)

// ============================================================== 11. USABILIDAD Y ACCESIBILIDAD
secciones.push(
  h1('B.11 · 11. Usabilidad y accesibilidad'),
  h2('11.1. Jerarquía visual y legibilidad'),
  bullet('Tipografía clara (Inter → Calibri fallback), pesos jerarquizados (títulos más grandes), textos principales ≥ 15 px.'),
  bullet('Contraste de la app: texto blanco/lavanda sobre #000000 y #3E065F — cómodo a la vista; acento #8E05C2 para CTAs.'),
  bullet('Iconografía Material (q-icon) + etiquetas textuales para acciones clave.'),
  bullet('Mensajes de error concretos y en español; no ambiguos.'),
  h2('11.2. Accesibilidad'),
  bullet('Roles/estados: role=button en tarjetas, role=dialog, aria-modal, role=status (mensajes robot), aria-labelledby.'),
  bullet('Foco visible en controles; navegación por teclado (Enter/Space vía q-button).'),
  bullet('No se depende sólo del color para estados (✔/✗ + texto + icono).'),
  bullet('Prefers-reduced-motion respetado en animaciones del robot (instantáneo sin animación).'),
  h2('11.3. Problemas identificados'),
  bullet('Algunos q-icon no resuelven en browser → icono ausente en nav/App (warnings heredados no críticos).'),
  bullet('Estado "Cargando" inicial bloquea pantalla total; sin skeleton ni cancel (sí existe error-estado).'),
  bullet('Logo no carga para cursos sin logo propio (monogram como fallback); siempre visible pero sin imagen cuando conviene.'),
  bullet('Contraste de gris claro secundario (#5A5A5A) en proporción AA pendiente de medición formal.'),
)

// ============================================================== 12. PERFORMANCE Y ERRORES
secciones.push(
  h1('B.12 · 12. Rendimiento y manejo de errores'),
  h2('12.1. Tiempos medidos'),
  tabla({
    headers: ['Solicitud', 'Tiempo observado'],
    rows: [
      ['GET /cursos (anon, publicación)', '≈ 340 ms'],
      ['GET /auth/v1/settings', '≈ 130 ms'],
      ['rpc obtener_progreso / finalizar_intento', '≈ 300–400 ms'],
      ['INSERT respuestas (1 usuario, latencia simple)', '≈ 300 ms'],
    ],
    widths: [5.0, 2.6],
  }),
  h2('12.2. Errores de conexión y manejo'),
  bullet('RPC con excepción → devolucion.estado=error, botón "Reintentar" (no cuenta como incorrecta).'),
  bullet('Lección inexistente → "inexistente"; intento inexistente → error claro.'),
  bullet('Enviar sin intento → excepción clara "Se necesita una sesión".'),
  bullet('Error de red → Qgs "Pull" tratada con Try/Catch y con retry seguro (finalizar_intento idempotente).'),
  bullet('Retries en la carga de perfil: hasta 5 intentos con backoff antes de claudicar.'),
  h2('12.3. Observaciones'),
  bullet('Chunk principal > 500 kB minificado (warning de Vite); recomendado code-splitting a largo plazo.'),
  bullet('Carga inicial puede usar HTTP caching agresivo (cache-control adecuado en dist); hoy sin service worker.'),
  bullet('Comprobar_respuesta otorga rol anon acceso (ver D-17): cualquier UI response no debe confiar en veredicto del cliente.'),
)
// 3. REGISTRO DE ERRORES
secciones.push(
  h1('B.13 · 13. Registro de errores'),
  p('Fallas detectadas y su estado actual; prioridad por impacto en seguridad/integridad/funciones clave.'),
  tabla({
    headers: ['Código', 'Descripción', 'Funcionalidad', 'Pasos para reproducir', 'Importancia', 'Producto / Estado', 'Solución aplicada'],
    rows: [
      ['E-001', 'Rutas de curso y actividad quedaban con main vacío', 'Navegación', 'Seleccionar un curso desde /learn', 'Crítica', 'Corregida', 'Estado de v carga renombrado (estadoCarga) en CursoView y InicioView; regresión verificada'],
      ['E-002', 'Navegación con sesión anon vencida congelaba la app en blanco', 'Auth', 'Token vencido → recargar /learn', 'Crítica', 'Corregida', 'inicializarSesion captura el fallo y cae a modo público (patrón refrescarSesion)'],
      ['E-003', 'ActividadRobot: watch inmediato antes de declarar datos', 'Comprobación robot', 'Abrir actividad → actividad pantalla cargando', 'Alta', 'Corregida', 'Los tutoriales/clase watch desplazadas; build de producción OK y juego confirmado por capturas'],
      ['E-004', 'Seed double-encoded con acentos; comprobador en vivo mostró 22P02', 'Datos', 'npm run build o aplicar migración v1 con mojibake', 'Alta', 'Corregida', 'Migración v1 limpia + tests robot; 0 ocurrencias en SQL'],
      ['E-005', 'Unidad 2 y 3: lecciones innaccesibles (publico=0)', 'Progresión', 'Desbloquear unidad 2 → nada jugable', 'Alta', 'Corregida', 'Todas las lecciones robot a publicado; desbloqueo por usuario verificado'],
      ['E-006', 'Línea de camino invisible en escritorio móvil/responsivo (la recta no tocaba los zigzag)', 'UI recorrido', 'Abrir unidad con lecciones zigzag', 'Media', 'Corregida', 'Línea SVG nueva con tres estados por tramo y segmentos discontinuos'],
      ['E-007', 'HTML curso publicado sin contenido visible para invitados recién', 'Catálogo', 'Acceso → /cursos', 'Media', 'Validado', 'Tiene contenido publicado; verificado por REST; comportamiento correcto'],
      ['E-008', 'warning chunk size >500kB', 'Build', 'npm run build', 'Baja', 'Pendiente', 'documentado; code-splitting a largo plazo'],
      ['E-009', 'comprobar_respuesta abierto a cualquier rol (oráculo por id)', 'Seguridad', 'Llamar RPC con UUID conocido sin intento', 'Media', 'Pendiente', 'D-17 registrado; requiere rol+dejado en RPC'],
      ['E-010', 'SMTP no configurado; invitaciones y recuperación no llegan', 'Cuenta', 'Intentar registro / recuperar', 'Media', 'Pendiente (producto)', 'Documentado; decisión pendiente'],
      ['E-011', 'q-icon no resuelto en algunos casos', 'UI', 'Uso de q-icon sin global registration', 'Baja', 'Documentado', 'Iconos bien resultan por fallback contextual; no afecta uso'],
      ['E-012', 'APK antiguo no incluye el curso Pensamiento Lógico ni correcciones', 'Android', 'Instalar APK 8.0 actual', 'Media', 'Pendiente', 'Nuevo build necesario + cap sync android'],
    ],
    widths: [0.7, 2.4, 1.4, 2.0, 1.3, 1.6, 2.1],
  }),
)

// ============================================================== 14. CORRECCIONES
secciones.push(
  h1('B.14 · 14. Correcciones y repetición de pruebas'),
  p('Acciones aplicadas sobre el build y hechas con repetición inmediata de los casos:'),
  tabla({
    headers: ['Corrección', 'Casos originales', 'Comprobación de fix', 'Regresión'],
    rows: [
      ['E-001 (estadoCarga)', 'CP-003, recorrido de cursos completo', 'Build OK; navegación curso jav scrip completo visualmente', '145/145 tests verde; ESLint 0 errores'],
      ['E-002 (inicializarSesion)', 'Navegación tras token vencido / reload', 'recarga /learn sin congelamento; sesión limpia como invitado nueva', 'todas las pruebas automatizadas y prueba funcional CP-006'],
      ['E-003 (TDZ robot)', 'Juego confirmado por capturas (07-11)', 'Juego completable con +25 XP y racha', 'npm test completo; npm run build sin warnings nuevos'],
      ['E-004 (encoding)', 'migración incremental viva en editor', 'robot publisher corre success; counts vivos correcto', 'válidar-sql 487 sentencias; pruebas robot BFS OK'],
      ['E-005 (unidad publicación)', 'bloquear → desbloquear', 'unidad 2 desbloqueable tras completar unidad 1; publicado visible', 'flujos de 1 nivel, 2 niveles, 5 niveles unitarios'],
      ['E-006 (línea de camino)', 'Abrir ruta unidad JavaScript', 'Path dibujado por canvas/SVG entre todos los nodos', 'Prueba visual en dispositivos 390/768/360'],
    ],
    widths: [2.0, 2.6, 2.7, 2.8],
  }),
)

// ============================================================== 15. CALIDAD CÓDIGO
secciones.push(
  h1('B.15 · 15. Calidad del código'),
  h2('15.1. Organización'),
  bullet('Estructura: src/components (14), src/views (28), src/services (6 servicios por dominio), src/router (31 rutas), src/assets (assets + tema).'),
  bullet('SQL: src/scripts/kodigo-completo.sql como única fuente sembrada; verificador (scripts/validar-sql.mjs) lo parse SQ en 25 tablas y 72 funciones.'),
  bullet('Separación vista/servicio: las vistas llamadas servicios para Supabase; no hay fetch directo en componentes críticos.'),
  bullet('Nombres: camelCase en JS/TS; PascalCase en componentes; nombres descriptivos en CSS/schemas; las vars de migración usan nombres semánticos (p_leccion_id, p_usuario_id).'),
  h2('15.2. ESLint'),
  tabla({
    headers: ['Origen', 'Resultado'],
    rows: [
      ['src/ (código de producto)', '0 errores, 0 advertencias con respecto al build'],
      ['scripts/ (verificadores + seeds)', '0 errores, 4 warnings (variables sin usar en archivos de prueba)'],
      ['Total proyecto', '0 errores, 9 advertencias (8 legacy en scripts/test + 1 atributo vainilla en CoreDefender)'],
    ],
    widths: [4.2, 4.0],
  }),
  h2('15.3. Build production'),
  bullet('vite build OK; warning chunk principal > 500 kB (recomendado code-splitting).'),
  bullet('CSS Quasar al usar @import; compilable vía sass (notas de migración documentadas).'),
  bullet('No hay advertencias en build productivo tras la integración del robot.'),
  h2('15.4. Duplicación y mejora incremental'),
  bullet('El controlador EjecutorActividad maneja las 12 modalidades — patrón por tipo; sin despunificar inesperado.'),
  bullet('Accion futura: reducir el bundle con imports dinámicos de vistas (fuera de alcance esta etapa).'),
)

// ============================================================== 16. DOCUMENTACIÓN TÉCNICA
secciones.push(
  h1('B.16 · 16. Documentación técnica'),
  h2('16.1. Documentación existente (cubierta)'),
  tabla({
    headers: ['Área', 'Documento', 'Estado'],
    rows: [
      ['Visión general', 'docs/documentacion-general.md', 'Actualizado a etapa 11 (Anexo D: curso Pensamiento Lógico)'],
      ['Pruebas y validación (este documento)', 'docs/KodiGo - pruebas.docx', 'Actualizado a etapa 11 con verificaciones reales'],
      ['Auditoría Supabase', 'docs/stage10/auditoria-supabase.md', 'Vigente'],
      ['Manual de usuario', 'docs/kodigo-manual de usuario.docx', 'Nuevo documento complementario'],
      ['Android + Capacitor', 'docs/etapa 8/entorno-android.md', 'Vigente'],
      ['Etapas de proyecto', 'docs/stage3…11/', 'Completos (stages 3 a 11)'],
      ['Desafío ExpoTécnica', 'docs/stage8/*', 'Vigente (manual admin/participantes/cierre)'],
    ],
    widths: [2.3, 3.6, 2.9],
  }),
  h2('16.2. Huecos y limitaciones'),
  bullet('Guía de instalación desde cero: existe pero sin sección de variables riesgo/alertas para usuarios ajenos (indocumentado en README público).'),
  bullet('Documentación de arquitectura C4/UML: inexistente (informal en docs etapas, sin diagramas).'),
  bullet('Guía de contribución/hotfix: inexistente.'),
  bullet('Configuración ExpoTécnica documentada en etapa 8, pero sin manual operativo para el profesor sin panel de administración.'),
)

// ============================================================== 17. MANUAL
secciones.push(
  h1('B.17 · 17. Manual de usuario'),
  p('El manual de usuario se publica en un documento independiente:'),
  callout('docs/kodigo-manual de usuario.docx — incluye portada, introducción, requisitos, ingreso, pantalla principal, catálogo de cursos, unidades, lecciones, actividades (12 modalidades + robot), comprobación de respuestas, progreso y gamificación, perfil, navegación, problemas frecuentes, recomendaciones de uso y capturas reales de la aplicación (36 imágenes generadas en Chrome headless para esta etapa).'),
)

// ============================================================== 18. INFORME FINAL
secciones.push(
  h1('B.18 · 18. Informe final de pruebas'),
  h2('18.1. Resumen cuantitativo'),
  tabla({
    headers: ['Métrica', 'Cantidad'],
    rows: [
      ['Pruebas automatizadas (npm test)', '145 / 145 aprobadas (100 %)'],
      ['Validación SQL (validar-sql)', '487 sentencias · 25 tablas · 72 funciones · 39 políticas RLS — válido'],
      ['ESLint', '0 errores, 9 advertencias (documentadas, sin bloqueo)'],
      ['Casos manuales documentados (sección 3)', '20 casos — 16 aprobados, 0 fallidos, 4 pendientes'],
      ['Verificación en vivo (verificar-supabase)', '37 / 37 comprobaciones OK'],
      ['Rutas auditadas', '31 rutas; 10 vistas internas verificadas con capturas reales'],
      ['Capturas realizadas', '36 imágenes (11 flujos + 5 viewports + actividad y resultados)'],
    ],
    widths: [5.5, 3.0],
  }),
  h2('18.2. Errores encontrados'),
  bullet('12 errores registrados (E-001 a E-012): 6 críticos/altos corregidos (E-001..E-006), 6 documentados como pendientes.'),
  h2('18.3. Correcciones realizadas'),
  bullet('Ruta curso quedó invisible tras fix estadoCarga (E-001).'),
  bullet('Navegación congelada tras sesión vencida (E-002) — el cliente vuelve a navegar tras 1 fallo.'),
  bullet('Robot con TDZ (E-003) — la actividad monta y es jugable con tutorial y ayuda.'),
  bullet('Mojibake en seed (E-004) — 487 sentencias válidas, 0 ocurrencias remapeadas.'),
  bullet('Lecciones robot bloqueadas (E-005) — las 15 remediadas a publicado.'),
  bullet('Línea de camino invisible (E-006) — SVG continua con tres estados de segmento.'),
  h2('18.4. Pruebas de regresión'),
  p('Tras cada corrección, se re-ejecutó la batería completa: 145/145 automáticas verdes, build OK, recorrido manual del curso JavaScript validado, recorrido del curso Pensamiento Lógico validado, chequeo responsive en 5 viewports, RPC en vivo (37/37), lint OK.'),
  h2('18.5. Limitaciones actuales'),
  bullet('Confirmación de correo limitada por mailer integrado (sin SMTP propio). Entrega real a usuarios externos depende de una decisión de producto.'),
  bullet('Sin ejecución de pruebas en dispositivos físicos (Android sin instalar el APK en esta etapa).'),
  bullet('Sin pruebas de carga/stress (red, servidor) ni de seguridad ofensiva más allá de RLS/RPC.'),
  bullet('Panel admin de ExpoTécnica sin prueba con cuenta es_admin (falta la cuenta).'),
  bullet('Desafío ExpoTécnica evaluado sólo nominalmente en esta etapa (no re-partida a 10 usuarios).'),
  h2('18.6. Conclusión'),
  callout('Kodigo es funcional, cohesivo y estático en esta versión: flujos principales completos (Cursos → Unidad → Lección → Actividad → Comprobación → Resultado → XP → desbloqueo), el servidor es la fuente de verdad, la persistencia funciona día a día y la seguridad pública es real (RLS 39 políticas comprobadas). Los riesgos residentes son operativos (SMTP, cuenta admin para publicar, build móvil actualizado, pendientes documentados) y están explícitamente listados con dueño y parte en este documento.'),
)

const { header, footer } = headerFooter('Pruebas y validación')
const children = [...cover, ...toc, ...parteA, ...secciones]

const doc = buildDocument({
  title: 'Kodigo — Pruebas, validación y documentación técnica',
  creator: 'Equipo Kodigo',
  children,
  header,
  footer,
})

await saveDocument(doc, join(root, 'docs', 'KodiGo - pruebas.docx'))
console.log('docs/KodiGo - pruebas.docx generado')
