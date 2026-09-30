insert into cursos (
    id,
    nombre,
    descripcion,
    orden,
    estado_publicacion
)
values (
    '10000000-0000-0000-0000-000000000001',
    'JavaScript',
    'Aprende los fundamentos de JavaScript desde cero.',
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
    'Introducción a JavaScript',
    'Conceptos básicos y primeros pasos con JavaScript.',
    1,
    'publicado'
),
(
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Variables y datos',
    'Variables, constantes y tipos de datos.',
    2,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'Condicionales',
    'Decisiones y estructuras condicionales.',
    3,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    'Bucles',
    'Repeticiones y ciclos en JavaScript.',
    4,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    'Funciones',
    'Creación y utilización de funciones.',
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
    '¿Qué es JavaScript?',
    'JavaScript es un lenguaje de programación utilizado principalmente para agregar comportamiento e interactividad a las páginas web.',
    'console.log("Hola mundo");',
    1,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'Primeros pasos',
    'En JavaScript podemos escribir instrucciones que se ejecutan una después de otra. Una de las formas más simples de mostrar información es utilizando console.log.',
    'console.log("Hola");\nconsole.log("Bienvenido a Kodigo");',
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
    '¿Para qué se utiliza principalmente JavaScript en una página web?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '¿Cuál de las siguientes opciones es una instrucción válida de JavaScript?',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    '¿Qué función permite mostrar un mensaje en la consola?',
    'multiple_choice',
    3,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000002',
    '¿Qué hace console.log("Hola");?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000002',
    '¿Qué palabra se utiliza para declarar una variable cuyo valor puede cambiar?',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000002',
    '¿Cuál es el resultado de ejecutar console.log(2 + 3);?',
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
    'Agregar interactividad y comportamiento a una página web',
    1
),
(
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    'Crear únicamente imágenes',
    2
),
(
    '50000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000001',
    'Reemplazar HTML',
    3
),
(
    '50000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000001',
    'Crear archivos de texto',
    4
),

(
    '50000000-0000-0000-0000-000000000005',
    '40000000-0000-0000-0000-000000000002',
    'console.log("Hola");',
    1
),
(
    '50000000-0000-0000-0000-000000000006',
    '40000000-0000-0000-0000-000000000002',
    '<console>Hola</console>',
    2
),
(
    '50000000-0000-0000-0000-000000000007',
    '40000000-0000-0000-0000-000000000002',
    'print.console("Hola");',
    3
),
(
    '50000000-0000-0000-0000-000000000008',
    '40000000-0000-0000-0000-000000000002',
    'javascript.console("Hola");',
    4
),

(
    '50000000-0000-0000-0000-000000000009',
    '40000000-0000-0000-0000-000000000003',
    'console.log()',
    1
),
(
    '50000000-0000-0000-0000-000000000010',
    '40000000-0000-0000-0000-000000000003',
    'console.show()',
    2
),
(
    '50000000-0000-0000-0000-000000000011',
    '40000000-0000-0000-0000-000000000003',
    'print()',
    3
),
(
    '50000000-0000-0000-0000-000000000012',
    '40000000-0000-0000-0000-000000000003',
    'show.console()',
    4
),

(
    '50000000-0000-0000-0000-000000000013',
    '40000000-0000-0000-0000-000000000004',
    'Muestra Hola en la consola',
    1
),
(
    '50000000-0000-0000-0000-000000000014',
    '40000000-0000-0000-0000-000000000004',
    'Crea una página HTML',
    2
),
(
    '50000000-0000-0000-0000-000000000015',
    '40000000-0000-0000-0000-000000000004',
    'Elimina la consola',
    3
),
(
    '50000000-0000-0000-0000-000000000016',
    '40000000-0000-0000-0000-000000000004',
    'Cierra JavaScript',
    4
),

(
    '50000000-0000-0000-0000-000000000017',
    '40000000-0000-0000-0000-000000000005',
    'let',
    1
),
(
    '50000000-0000-0000-0000-000000000018',
    '40000000-0000-0000-0000-000000000005',
    'constant',
    2
),
(
    '50000000-0000-0000-0000-000000000019',
    '40000000-0000-0000-0000-000000000005',
    'variable',
    3
),
(
    '50000000-0000-0000-0000-000000000020',
    '40000000-0000-0000-0000-000000000005',
    'change',
    4
),

(
    '50000000-0000-0000-0000-000000000021',
    '40000000-0000-0000-0000-000000000006',
    '5',
    1
),
(
    '50000000-0000-0000-0000-000000000022',
    '40000000-0000-0000-0000-000000000006',
    '23',
    2
),
(
    '50000000-0000-0000-0000-000000000023',
    '40000000-0000-0000-0000-000000000006',
    '6',
    3
),
(
    '50000000-0000-0000-0000-000000000024',
    '40000000-0000-0000-0000-000000000006',
    '2 + 3',
    4
);

insert into soluciones (
    pregunta_id,
    opcion_correcta_id,
    explicacion
)
values
(
    '40000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    'JavaScript permite agregar comportamiento e interactividad a las páginas web.'
),
(
    '40000000-0000-0000-0000-000000000002',
    '50000000-0000-0000-0000-000000000005',
    'console.log es una instrucción válida de JavaScript que permite mostrar información en la consola.'
),
(
    '40000000-0000-0000-0000-000000000003',
    '50000000-0000-0000-0000-000000000009',
    'console.log() permite mostrar información en la consola del navegador.'
),
(
    '40000000-0000-0000-0000-000000000004',
    '50000000-0000-0000-0000-000000000013',
    'console.log("Hola"); muestra el texto Hola en la consola.'
),
(
    '40000000-0000-0000-0000-000000000005',
    '50000000-0000-0000-0000-000000000017',
    'let permite declarar una variable cuyo valor puede modificarse posteriormente.'
),
(
    '40000000-0000-0000-0000-000000000006',
    '50000000-0000-0000-0000-000000000021',
    'La expresión 2 + 3 da como resultado 5.'
);

insert into logros (
    nombre,
    descripcion,
    experiencia_recompensa
)
values
(
    'Primeros pasos',
    'Completa tu primera lección.',
    20
),
(
    'Buen comienzo',
    'Aprueba dos lecciones.',
    40
),
(
    'En racha',
    'Responde correctamente varias actividades consecutivas.',
    50
),
(
    'Primer nivel',
    'Alcanza el nivel 2.',
    100
),
(
    'Aprendiz de código',
    'Completa cinco lecciones.',
    100
);