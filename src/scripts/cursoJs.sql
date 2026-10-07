-- Seed: curso JavaScript + 5 unidades para Kodigo.
-- La unidad "Variables y datos" es la unica con contenido completo (2 lecciones
-- publicadas y 6 preguntas de opcion multiple). Las demas unidades existen en la
-- base y quedan marcadas como 'bloqueada' hasta que se desarrolle su contenido.
--
-- Orden de ejecucion: primero db.sql y despues este archivo.
-- Los ids fijos con ceros son legibles y estables para relacionar los datos.

insert into cursos (
    id,
    nombre,
    descripcion,
    lema,
    monograma,
    logo,
    color_acento,
    orden,
    estado_publicacion
)
values (
    '10000000-0000-0000-0000-000000000001',
    'JavaScript',
    'Creá tus primeros programas en el lenguaje más usado del mundo.',
    'El lenguaje de la web',
    'JS',
    'javascriptLogo',
    '#f7df1e',
    1,
    'publicado'
);

insert into unidades (
    id,
    curso_id,
    nombre,
    descripcion,
    orden,
    estado_publicacion
)
values
(
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Variables y datos',
    'Guardá información y conocé los tipos de datos básicos de JavaScript.',
    1,
    'publicado'
),
(
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Operadores',
    'Calculá con números y compará valores usando operadores.',
    2,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'Condicionales',
    'Tomá decisiones en tu código con if y else.',
    3,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    'Bucles',
    'Repetí tareas automáticamente con for y while.',
    4,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    'Funciones',
    'Organizá tu código en bloques reutilizables.',
    5,
    'bloqueada'
);

insert into lecciones (
    id,
    unidad_id,
    titulo,
    explicacion,
    ejemplo_codigo,
    orden,
    estado_publicacion
)
values
(
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Variables y asignación',
    'Una variable guarda un valor para reutilizarlo después. En JavaScript usamos let para declarar una variable y luego le asignamos un valor.',
    'let nombre = "Ana";\nlet edad = 18;\nconsole.log(nombre);\nconsole.log(edad);',
    1,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'Operadores y cálculo',
    'Los operadores permiten combinar valores y hacer cálculos. La suma, resta, multiplicación y división son las operaciones más comunes.',
    'let precio = 10;\nlet cantidad = 3;\nlet total = precio * cantidad;\nconsole.log(total);',
    2,
    'publicado'
);

insert into preguntas (
    id,
    leccion_id,
    enunciado,
    tipo,
    orden,
    estado_publicacion
)
values
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '¿Cuál de estas líneas declara correctamente una variable llamada edad con el valor 18?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '¿Qué valor completa la sentencia para guardar el nombre de una persona?\nlet nombre = ___;',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    '¿Qué opción representa una asignación válida de una constante?',
    'multiple_choice',
    3,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000002',
    '¿Qué resultado devuelve 12 + 5?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000002',
    '¿Qué operador completa la sentencia para calcular el resto de la división?\nlet resto = 10 ___ 3;',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000002',
    '¿Cuál de estas expresiones calcula correctamente el total de 4 × 3?',
    'multiple_choice',
    3,
    'publicado'
);

insert into opciones (
    id,
    pregunta_id,
    texto,
    orden
)
values
(
    '50000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    'let edad = 18;',
    1
),
(
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    'let 18 = edad;',
    2
),
(
    '50000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000001',
    'const edad;',
    3
),
(
    '50000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000001',
    'edad = 18;',
    4
),

(
    '50000000-0000-0000-0000-000000000005',
    '40000000-0000-0000-0000-000000000002',
    '"Ana"',
    1
),
(
    '50000000-0000-0000-0000-000000000006',
    '40000000-0000-0000-0000-000000000002',
    'Ana',
    2
),
(
    '50000000-0000-0000-0000-000000000007',
    '40000000-0000-0000-0000-000000000002',
    '18',
    3
),
(
    '50000000-0000-0000-0000-000000000008',
    '40000000-0000-0000-0000-000000000002',
    'let',
    4
),

(
    '50000000-0000-0000-0000-000000000009',
    '40000000-0000-0000-0000-000000000003',
    'const apellido = "Pérez";',
    1
),
(
    '50000000-0000-0000-0000-000000000010',
    '40000000-0000-0000-0000-000000000003',
    'const = "Pérez";',
    2
),
(
    '50000000-0000-0000-0000-000000000011',
    '40000000-0000-0000-0000-000000000003',
    'let const = "Pérez";',
    3
),
(
    '50000000-0000-0000-0000-000000000012',
    '40000000-0000-0000-0000-000000000003',
    'apellido = const;',
    4
),

(
    '50000000-0000-0000-0000-000000000013',
    '40000000-0000-0000-0000-000000000004',
    '17',
    1
),
(
    '50000000-0000-0000-0000-000000000014',
    '40000000-0000-0000-0000-000000000004',
    '7',
    2
),
(
    '50000000-0000-0000-0000-000000000015',
    '40000000-0000-0000-0000-000000000004',
    '60',
    3
),
(
    '50000000-0000-0000-0000-000000000016',
    '40000000-0000-0000-0000-000000000004',
    '125',
    4
),

(
    '50000000-0000-0000-0000-000000000017',
    '40000000-0000-0000-0000-000000000005',
    '%',
    1
),
(
    '50000000-0000-0000-0000-000000000018',
    '40000000-0000-0000-0000-000000000005',
    '/',
    2
),
(
    '50000000-0000-0000-0000-000000000019',
    '40000000-0000-0000-0000-000000000005',
    '+',
    3
),
(
    '50000000-0000-0000-0000-000000000020',
    '40000000-0000-0000-0000-000000000005',
    '*',
    4
),

(
    '50000000-0000-0000-0000-000000000021',
    '40000000-0000-0000-0000-000000000006',
    '4 * 3',
    1
),
(
    '50000000-0000-0000-0000-000000000022',
    '40000000-0000-0000-0000-000000000006',
    '4 + 3',
    2
),
(
    '50000000-0000-0000-0000-000000000023',
    '40000000-0000-0000-0000-000000000006',
    '4 / 3',
    3
),
(
    '50000000-0000-0000-0000-000000000024',
    '40000000-0000-0000-0000-000000000006',
    '4 % 3',
    4
);

-- Cada pregunta tiene exactamente una opcion correcta y su explicacion.
insert into soluciones (
    pregunta_id,
    opcion_correcta_id,
    explicacion
)
values
(
    '40000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    'La sintaxis correcta es declarar la variable con let, poner el nombre y luego asignarle el valor con =.'
),
(
    '40000000-0000-0000-0000-000000000002',
    '50000000-0000-0000-0000-000000000005',
    'Los textos en JavaScript deben ir entre comillas. Por eso el valor correcto es "Ana".'
),
(
    '40000000-0000-0000-0000-000000000003',
    '50000000-0000-0000-0000-000000000009',
    'const se usa para declarar una constante, seguida del nombre y el valor. La sintaxis es const nombre = valor;'
),
(
    '40000000-0000-0000-0000-000000000004',
    '50000000-0000-0000-0000-000000000013',
    'La suma combina ambos valores numéricos y da 17.'
),
(
    '40000000-0000-0000-0000-000000000005',
    '50000000-0000-0000-0000-000000000017',
    'El operador % devuelve el resto de la división: 10 % 3 da 1.'
),
(
    '40000000-0000-0000-0000-000000000006',
    '50000000-0000-0000-0000-000000000021',
    'La multiplicación usa el operador *. 4 * 3 equivale a 12.'
);