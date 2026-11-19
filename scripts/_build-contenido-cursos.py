# Reescritura limpia/mensajes de la migración v3:JS/HTML 5x5.
# Formato de pregunta: (leccion_id, orden, enunciado, tipo, opciones, correcta_key, explicacion)
# Un tipo 'completar_texto' ignora opciones y usa el campo correcto (valor).
import hashlib
import json
import uuid

def md5_uuid(texto):
    return str(uuid.UUID(bytes=hashlib.md5(texto.encode()).digest()))

def sql_escape(s):
    return str(s).replace("'", "''")

def datos_json(d):
    return json.dumps(d, ensure_ascii=False).replace("'", "''")

JS_LECCIONES = [
    ('20000000-0000-0000-0000-000000000001', 1, '30000000-0000-0000-0000-000000000011', 'Qué es JavaScript', 'JavaScript es el lenguaje de la web. Permite hacer que las páginas sean interactivas y dinámicas.', 'console.log("¡Hola, mundo!");', 'publicado'),
    ('20000000-0000-0000-0000-000000000001', 2, '30000000-0000-0000-0000-000000000001', 'Variables y tipos de datos', 'Una variable guarda un dato para usarlo después. Con let o const declarás la variable y le asignás un valor.', 'const nombre = "Ana";\nlet edad = 18;\nconst esAlumno = true;', 'publicado'),
    ('20000000-0000-0000-0000-000000000001', 3, '30000000-0000-0000-0000-000000000002', 'Operadores y cálculo', 'Los operadores combinan valores y hacen cálculos. Suma, resta, multiplicación y división son las más comunes.', 'let total = 2 + 3 * 4;\nconsole.log(total);', 'publicado'),
    ('20000000-0000-0000-0000-000000000001', 4, '30000000-0000-0000-0000-000000000012', 'Expresiones y tipos de datos', 'Una expresión es cualquier código que produce un valor: una operación, una comparación o una combinación.', 'const a = 10, b = 4;\nconsole.log(a * b);', 'publicado'),
    ('20000000-0000-0000-0000-000000000001', 5, '30000000-0000-0000-0000-000000000013', 'Repaso integrador 1', 'Repasá lo aprendido: variables, tipos y operadores.', 'let s = "Hola";\nconsole.log(s + ", Kodigo!");', 'publicado'),

    ('20000000-0000-0000-0000-000000000002', 1, '30000000-0000-0000-0000-000000000014', 'Comparaciones y booleanos', 'Una comparación produce un booleano: true o false. Operadores comunes: ==, ===, !=, <, >, <=, >=.', 'console.log(5 > 3);\nconsole.log(2 === 3);', 'publicado'),
    ('20000000-0000-0000-0000-000000000002', 2, '30000000-0000-0000-0000-000000000015', 'Operadores lógicos', 'Los operadores lógicos combinan booleanos: && (and), || (or) y ! (not).', 'console.log(true && false);\nconsole.log(true || false);', 'publicado'),
    ('20000000-0000-0000-0000-000000000002', 3, '30000000-0000-0000-0000-000000000003', 'Condicionales con if', 'if ejecuta un bloque sólo cuando una condición es verdadera. Sirve para tomar decisiones.', 'if (edad >= 18) {\n  console.log("mayor");\n}', 'publicado'),
    ('20000000-0000-0000-0000-000000000002', 4, '30000000-0000-0000-0000-000000000016', 'else if y condiciones anidadas', 'else if permite evaluar varias condiciones en orden; else se ejecuta cuando ninguna se cumple.', 'if (n >= 9) { x = "A"; }\nelse if (n >= 7) { x = "B"; }\nelse { x = "C"; }', 'publicado'),
    ('20000000-0000-0000-0000-000000000002', 5, '30000000-0000-0000-0000-000000000017', 'Repaso integrador 2', 'Condicionales y lógica con múltiples decisiones ordenadas.', 'if (nota >= 9) console.log("A");\nelse if (nota >= 7) console.log("B");', 'publicado'),

    ('20000000-0000-0000-0000-000000000003', 1, '30000000-0000-0000-0000-000000000004', 'Bucles for', 'for repite un bloque de código una cantidad conocida de veces.', 'for (let i = 0; i < 3; i++) {\n  console.log(i);\n}', 'publicado'),
    ('20000000-0000-0000-0000-000000000003', 2, '30000000-0000-0000-0000-000000000005', 'Bucles while', 'while repite mientras la condición sea verdadera; útil cuando no sabés cuántas veces.', 'let i = 0;\nwhile (i < 3) { i = i + 1; }', 'publicado'),
    ('20000000-0000-0000-0000-000000000003', 3, '30000000-0000-0000-0000-000000000018', 'Contadores y acumuladores', 'Un contador lleva la cuenta; un acumulador suma valores.', 'let s = 0;\nfor (let i = 1; i <= 5; i++) s = s + i;\nconsole.log(s);', 'publicado'),
    ('20000000-0000-0000-0000-000000000003', 4, '30000000-0000-0000-0000-000000000019', 'Cuándo terminan los bucles', 'Un bucle necesita una condición que eventualmente sea falsa.', 'let x = 1;\nwhile (x < 100) x = x * 2;', 'publicado'),
    ('20000000-0000-0000-0000-000000000003', 5, '30000000-0000-0000-0000-000000000020', 'Repaso integrador 3', 'Repasá bucles, contadores y acumuladores con ejercicios integradores.', 'let t = 0;\nfor (let i = 0; i < 5; i++) t = t + 2;', 'publicado'),

    ('20000000-0000-0000-0000-000000000004', 1, '30000000-0000-0000-0000-000000000006', 'Funciones', 'Una función es un bloque de código reutilizable con un nombre.', 'function saludar(nombre) {\n  return "Hola, " + nombre;\n}', 'publicado'),
    ('20000000-0000-0000-0000-000000000004', 2, '30000000-0000-0000-0000-000000000021', 'Parámetros y argumentos', 'Parámetros son los nombres en la declaración; argumentos son los valores que enviás.', 'function doble(x) {\n  return x * 2;\n}', 'publicado'),
    ('20000000-0000-0000-0000-000000000004', 3, '30000000-0000-0000-0000-000000000022', 'Retorno de valores', 'return devuelve el valor de la función; sin return la función devuelve undefined.', 'function area(w, h) {\n  return w * h;\n}', 'publicado'),
    ('20000000-0000-0000-0000-000000000004', 4, '30000000-0000-0000-0000-000000000007', 'Arrays', 'Un array es una lista ordenada de valores. Accedés por posición empezando en 0.', 'const n = [10, 20, 30];\nconsole.log(n[0]);', 'publicado'),
    ('20000000-0000-0000-0000-000000000004', 5, '30000000-0000-0000-0000-000000000023', 'Recorridos y manipulación de arrays', 'for recorre los índices de un array; map transforma y filter selecciona.', 'const n = [1, 2, 3];\nconsole.log(n.map(x => x * 2));', 'publicado'),

    ('20000000-0000-0000-0000-000000000005', 1, '30000000-0000-0000-0000-000000000008', 'Objetos', 'Un objeto agrupa propiedades con nombre y valor: datos y comportamiento juntos.', 'const p = { nombre: "Ana", edad: 20 };\nconsole.log(p.edad);', 'publicado'),
    ('20000000-0000-0000-0000-000000000005', 2, '30000000-0000-0000-0000-000000000009', 'Cadenas de texto', 'Las cadenas son textos. JavaScript trae métodos: length, toUpperCase, includes, slice, trim.', 'console.log("Kodigo".length);', 'publicado'),
    ('20000000-0000-0000-0000-000000000005', 3, '30000000-0000-0000-0000-000000000024', 'Propiedades y métodos', 'Las propiedades guardan datos; los métodos son funciones del objeto.', 'const o = { n: 5, d() { return this.n * 2; } };', 'publicado'),
    ('20000000-0000-0000-0000-000000000005', 4, '30000000-0000-0000-0000-000000000025', 'DOM: la página como árbol', 'DOM significa Document Object Model; cada etiqueta HTML es un nodo. JavaScript puede leer y cambiar esos nodos.', 'const b = document.querySelector("#enviar");\nb.addEventListener("click", () => console.log("clic"));', 'publicado'),
    ('20000000-0000-0000-0000-000000000005', 5, '30000000-0000-0000-0000-000000000010', 'Proyecto: notas de clase', 'Proyecto integrador: notas, DOM y eventos. Un mini-proyecto completo con HTML, CSS y JS.', 'const notas = [];\nfunction guardar(n) {\n  notas.push({ id: Date.now(), texto: n });\n  render();\n}', 'publicado'),
]

HTML_LECCIONES = [
    ('65223173-50c1-47fc-6123-b5b094d85a34', 1, '70000000-0000-0000-0000-000000000001', '¿Qué es HTML?', 'HTML es el lenguaje de marcado de la web. No es un lenguaje de programación: es una descripción de la estructura del contenido.', '<h1>Hola</h1>', 'publicado'),
    ('65223173-50c1-47fc-6123-b5b094d85a34', 2, '707e84f0-fc33-bb22-2e7c-97bf32d4c0ed', 'El documento HTML', 'Un documento HTML tiene una cabecera (head) con metadatos y un cuerpo (body) con el contenido visible.', '<!DOCTYPE html>\n<html lang="es">\n<head></head>\n<body></body>\n</html>', 'publicado'),
    ('65223173-50c1-47fc-6123-b5b094d85a34', 3, '4bfdf59b-4b84-10c9-20f0-f095ce26f405', 'Etiquetas y elementos', 'Las etiquetas son marcas como <p> y </p>. Cada elemento tiene apertura y cierre (salvo etiquetas vacías como <img> o <input>).', '<p>Párrafo</p>', 'publicado'),
    ('65223173-50c1-47fc-6123-b5b094d85a34', 4, '70000000-0000-0000-0000-000000000002', 'Encabezados y estructura', 'Los encabezados h1-h6 organizan y jerarquizan el contenido; los p son contenedores de bloques de texto.', '<h1>Título</h1>\n<h2>Subtítulo</h2>\n<p>Contenido</p>', 'publicado'),
    ('65223173-50c1-47fc-6123-b5b094d85a34', 5, '70000000-0000-0000-0000-000000000003', 'Repaso integrador 1', 'Repasá lo aprendido: estructura, etiquetas, encabezados y elementos.', '<h1>Kodigo</h1>', 'publicado'),

    ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 1, '3e8ffb80-ab9d-66e0-47e1-fd1eb7948f66', 'Listas y enlaces', 'Las listas ul y ol estructuran elementos en serie. Los enlaces (<a>) navegan entre páginas.', '<ul>\n  <li>Opción 1</li>\n</ul>', 'publicado'),
    ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 2, '70000000-0000-0000-0000-000000000004', 'Enlaces y rutas relativas', 'Las rutas relativas indican dónde encontrar el archivo desde el documento actual; las absolutas usan la URL completa.', '<a href="contacto.html">Contacto</a>', 'publicado'),
    ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 3, '92153c83-c8e8-3f06-ca75-2d205d4eea72', 'Imágenes', 'La etiqueta <img> incrusta imágenes con atributos src y alt.', '<img src="foto.jpg" alt="Descripción">', 'publicado'),
    ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 4, '70000000-0000-0000-0000-000000000005', 'Listas ordenadas y organización', 'Las listas anidan y organizan contenidos similares; sirven para menús y pasos de procesos.', '<ol>\n  <li>Paso 1</li>\n</ol>', 'publicado'),
    ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 5, '70000000-0000-0000-0000-000000000006', 'Repaso integrador 2', 'Repasá listas, enlaces e imágenes con ejercicios integradores.', '<a href="menu.html">Menú</a>', 'publicado'),

    ('185cf7ac-af6f-4daf-11da-41ac2b744411', 1, '70000000-0000-0000-0000-000000000007', 'Contenedores y agrupación', 'Las etiquetas block agrupan contenido; los div son contenedores genéricos.', '<div>\n  <p>Bloque</p>\n</div>', 'publicado'),
    ('185cf7ac-af6f-4daf-11da-41ac2b744411', 2, '70000000-0000-0000-0000-000000000008', 'Header, main y footer', 'header es el encabezado; main es el contenido principal; footer es el pie.', '<header>Kodigo</header>\n<main>Contenido</main>\n<footer>2026</footer>', 'publicado'),
    ('185cf7ac-af6f-4daf-11da-41ac2b744411', 3, '70000000-0000-0000-0000-000000000009', 'Secciones y artículos', 'section agrupa contenidos temáticos; article es contenido independiente.', '<article>\n  <h2>Artículo</h2>\n</article>', 'publicado'),
    ('185cf7ac-af6f-4daf-11da-41ac2b744411', 4, 'd14606e6-b4bb-8499-e4c8-dffb7b31170f', 'Etiquetas semánticas', 'HTML5 introdujo etiquetas con significado semántico: nav, aside, section, article, figure.', '<nav>Menú</nav>', 'publicado'),
    ('185cf7ac-af6f-4daf-11da-41ac2b744411', 5, '70000000-0000-0000-0000-00000000000a', 'Repaso integrador 3', 'Repasá organización y semántica con ejercicios integradores.', '<main><article>Texto</article></main>', 'publicado'),

    ('70000000-0000-0000-0000-000000000100', 1, 'bf446ed2-3603-f4cf-71a3-4c3975379935', 'Formularios e inputs', 'Los formularios recopilan datos del usuario con <form> y campos como <input>, <label> y <button>.', '<form>\n  <label>Nombre:</label>\n  <input type="text" name="nombre">\n</form>', 'publicado'),
    ('70000000-0000-0000-0000-000000000100', 2, '70000000-0000-0000-0000-00000000000b', 'Labels y accesibilidad', '<label> vincula un texto con un campo; mejora la usabilidad y la accesibilidad.', '<label for="nombre">Nombre</label>\n<input id="nombre" name="nombre">', 'publicado'),
    ('70000000-0000-0000-0000-000000000100', 3, '70000000-0000-0000-0000-00000000000c', 'Botones y tipos de campo', '<button> y <input type="text|email|password|number|checkbox|radio|submit"> cubren distintos tipos de datos.', '<input type="email" name="correo" required>', 'publicado'),
    ('70000000-0000-0000-0000-000000000100', 4, '256fb823-7c87-b186-8820-43dd4c2734c9', 'Formularios avanzados', 'Los formularios admiten validación HTML5 (required, pattern, type) y múltiples tipos de campo.', '<input type="email" pattern=".+@.+\\..+" required>', 'publicado'),
    ('70000000-0000-0000-0000-000000000100', 5, '70000000-0000-0000-0000-00000000000d', 'Repaso integrador 4', 'Repasá formularios, labels y accesibilidad con ejercicios integradores.', '<form></form>', 'publicado'),

    ('70000000-0000-0000-0000-000000000101', 1, '1011b119-e854-cbc3-9561-0afe891a11eb', 'Tablas', 'Las tablas organizan datos en filas y columnas: <table>, <tr>, <td>, <th>.', '<table>\n  <tr><th>Nombre</th></tr>\n</table>', 'publicado'),
    ('70000000-0000-0000-0000-000000000101', 2, '9745df43-9522-1db7-395b-1fd810c05c28', 'Atributos y clases', 'class vincula una etiqueta con estilos CSS; id a uno único en la página.', '<p class="destaca">Texto</p>', 'publicado'),
    ('70000000-0000-0000-0000-000000000101', 3, '70000000-0000-0000-0000-00000000000e', 'Multimedia básica', '<audio> y <video> incrustan multimedia con sus atributos controls y src.', '<audio controls><source src="a.mp3" type="audio/mpeg"></audio>', 'publicado'),
    ('70000000-0000-0000-0000-000000000101', 4, '70000000-0000-0000-0000-00000000000f', 'Accesibilidad básica', 'HTML semántico mejora el acceso: jerarquía de headings, alt descriptivo, labels y roles ARIA.', '<img src="mapa.png" alt="Mapa del campus">', 'publicado'),
    ('70000000-0000-0000-0000-000000000101', 5, '8caf4505-8287-cc71-c800-dcf8c454cf22', 'Proyecto integrador final', 'Proyecto integral: armá una página completa con encabezado, contenido, formulario, tabla e imágenes.', '<main><article>…</article></main>', 'publicado'),
]

# Preguntas para JS y HTML nuevas (15 lecciones JS + 10 lecciones HTML que son NUEVAS)
# Formato: (leccion_id, orden, enunciado, tipo, opciones, correcta_key_o_valor, explicacion)
# tipo: 'seleccion' | 'verdadero_falso' | 'predecir' | 'completar_texto'

JS_PREGUNTAS = [
    ('30000000-0000-0000-0000-000000000011', 1, '¿Para qué sirve JavaScript?', 'seleccion',
     [('a', 'Para darle interactividad a las páginas web.'), ('b', 'Para diseñar logotipos.'), ('c', 'Para programar impresoras 3-D.')],
     'a', 'JavaScript es el lenguaje que da dinamismo y comportamiento a las páginas web.'),
    ('30000000-0000-0000-0000-000000000011', 2, 'JavaScript es un lenguaje de programación.', 'verdadero_falso',
     [('v', 'JavaScript es el lenguaje web del comportamiento.'), ('f', 'No, no es un lenguaje de programación.')],
     'v', 'JS permite hacer páginas interactivas y se usa en el navegador y en el servidor (Node.js).'),
    ('30000000-0000-0000-0000-000000000011', 3, '¿Quién creó JavaScript?', 'seleccion',
     [('a', 'Brendan Eich, en Netscape, en 1995.'), ('b', 'Microsoft, en 2001.'), ('c', 'Google, en 2009.')],
     'a', 'JavaScript fue creado por Brendan Eich en Netscape en 1995.'),
    ('30000000-0000-0000-0000-000000000011', 4, '¿Dónde se puede ejecutar JavaScript?', 'seleccion',
     [('a', 'En navegadores y en servidores con Node.js.'), ('b', 'Sólo en navegadores.'), ('c', 'Sólo en servidores.')],
     'a', 'JS corre en navegadores (Chrome, Firefox, Edge) y también en servidores (Node.js).'),

    ('30000000-0000-0000-0000-000000000012', 1, '¿Qué imprime este código? console.log(4 + 3);', 'seleccion',
     [('a', '7'), ('b', '43'), ('c', 'undefined')], 'a', 'Es una operación con números: 4 + 3 = 7.'),
    ('30000000-0000-0000-0000-000000000012', 2, '¿Qué tipo es la variable en: const x = "42"?', 'seleccion',
     [('a', 'string'), ('b', 'number'), ('c', 'boolean')], 'a', '"42" está entre comillas: es un string.'),
    ('30000000-0000-0000-0000-000000000012', 3, '¿Qué imprime este código? const a = [1, 2, 3]; console.log(a.length);', 'seleccion',
     [('a', '3'), ('b', '2'), ('c', 'undefined')], 'a', 'length devuelve la cantidad de elementos del array: 3.'),
    ('30000000-0000-0000-0000-000000000012', 4, 'typeof 3.14 devuelve:', 'seleccion',
     [('a', '"number"'), ('b', '"float"'), ('c', '"double"'), ('d', '"decimal"')], 'a', 'JavaScript tiene un único tipo numérico: number.'),

    ('30000000-0000-0000-0000-000000000013', 1, '¿Qué imprime este código? let x = 5; let y = 2; console.log(x + y);', 'seleccion',
     [('a', '7'), ('b', '52'), ('c', 'undefined')], 'a', 'Suma de números: 5 + 2 = 7.'),
    ('30000000-0000-0000-0000-000000000013', 2, 'La declaración de una función con const es válida en JavaScript.', 'verdadero_falso',
     [('v', 'const f = () => 42;'), ('f', 'Sólo la palabra function.')], 'v', 'La función puede ser asignación a const o declaración con function.'),
    ('30000000-0000-0000-0000-000000000013', 3, '¿Qué imprime este código? const a = 10, b = 4; console.log(a * b);', 'seleccion',
     [('a', '40'), ('b', '14'), ('c', '104')], 'a', 'Multiplicación: 10 * 4 = 40.'),
    ('30000000-0000-0000-0000-000000000013', 4, '¿Qué imprime este código? const saludo = "Hola"; console.log(saludo + ", Kodigo!");', 'seleccion',
     [('a', 'Hola, Kodigo!'), ('b', 'HolaKodigo!'), ('c', 'Hola, Kodigo')], 'a', 'La concatenación agrega el texto a la cadena.'),
    ('30000000-0000-0000-0000-000000000013', 5, '¿Qué imprime este código? console.log("JavaScri".length);', 'seleccion',
     [('a', '7'), ('b', '8'), ('c', '6'), ('d', '9')], 'b', '"JavaScri" son 8 caracteres (J-a-v-a-S-c-r-i).'),

    ('30000000-0000-0000-0000-000000000014', 1, '¿Qué es un booleano en JavaScript?', 'seleccion',
     [('a', 'Un valor que es verdadero o falso (true/false).'), ('b', 'Un tipo de número decimal.'), ('c', 'Un texto entre comillas.')],
     'a', 'boolean = true o false.'),
    ('30000000-0000-0000-0000-000000000014', 2, '5 == "5" devuelve true en JavaScript.', 'verdadero_falso',
     [('v', '== compara sólo el valor, no el tipo.'), ('f', '== compara también el tipo.')], 'v', '== compara valor; === compara valor y tipo.'),
    ('30000000-0000-0000-0000-000000000014', 3, '¿Qué operador compara valor y tipo al mismo tiempo?', 'seleccion',
     [('a', '==='), ('b', '=='), ('c', '!='), ('d', '==!')], 'a', '=== compara valor y tipo.'),
    ('30000000-0000-0000-0000-000000000014', 4, '¿Qué imprime este código? console.log(4 > 3);', 'seleccion',
     [('a', 'true'), ('b', 'false'), ('c', 'undefined')], 'a', '4 es mayor que 3.'),

    ('30000000-0000-0000-0000-000000000015', 1, '¿Qué imprime este código? console.log(true && false);', 'seleccion',
     [('a', 'false'), ('b', 'true'), ('c', 'undefined')], 'a', '&& sólo es verdadero si ambos operandos lo son.'),
    ('30000000-0000-0000-0000-000000000015', 2, '¿Qué imprime este código? console.log(true || false);', 'seleccion',
     [('a', 'true'), ('b', 'false'), ('c', 'undefined')], 'a', '|| es verdadero si al menos uno es verdadero.'),
    ('30000000-0000-0000-0000-000000000015', 3, '¿Qué imprime este código? console.log(!true);', 'seleccion',
     [('a', 'false'), ('b', 'true'), ('c', 'undefined')], 'a', '! invierte el booleano.'),
    ('30000000-0000-0000-0000-000000000015', 4, 'La expresión x || y devuelve el primer valor truthy.', 'verdadero_falso',
     [('v', 'O evalúa x y devuelve y si x es falsy.'), ('f', 'Siempre devuelve y.')], 'v', '|| usa cortocircuito: devuelve el primer truthy.'),

    ('30000000-0000-0000-0000-000000000016', 1, '¿Qué imprime este código? let nota = 8; if (nota >= 9) console.log("A"); else if (nota >= 7) console.log("B"); else console.log("C");', 'seleccion',
     [('a', 'B'), ('b', 'A'), ('c', 'C')], 'a', 'La primera condición que se cumple se ejecuta: nota >= 7 da B.'),
    ('30000000-0000-0000-0000-000000000016', 2, '¿Cuál rama se ejecuta si n = -3?', 'seleccion',
     [('a', 'else if (n < 0)'), ('b', 'if (n > 0)'), ('c', 'else')], 'a', '-3 no es mayor que 0, pero sí menor que 0.'),
    ('30000000-0000-0000-0000-000000000016', 3, 'else if se evalúa en orden.', 'verdadero_falso',
     [('v', 'De arriba hacia abajo hasta que alguna se cumpla.'), ('f', 'En cualquier orden.')], 'v', 'Siempre se evalúan de arriba hacia abajo.'),
    ('30000000-0000-0000-0000-000000000016', 4, '¿Qué imprime este código? const x = 10; if (x > 5) { if (x > 8) { console.log("alto") } else { console.log("medio") } }', 'seleccion',
     [('a', 'alto'), ('b', 'medio'), ('c', 'undefined')], 'a', '10 > 5 y 10 > 8: imprime alto.'),
    ('30000000-0000-0000-0000-000000000016', 5, '¿Qué ejecutaría si x = 4?', 'seleccion',
     [('a', 'else if (x <= 5)'), ('b', 'if (x > 5)'), ('c', 'else { }')], 'a', '4 no es mayor que 5, pero sí menor o igual.'),

    ('30000000-0000-0000-0000-000000000017', 1, '¿Cuándo se ejecuta else?', 'seleccion',
     [('a', 'Cuando todas las condiciones previas fueron falsas.'), ('b', 'Siempre.'), ('c', 'Nunca.')], 'a', 'else es el "si no se cumplió ninguna de las anteriores".'),
    ('30000000-0000-0000-0000-000000000017', 2, '¿Qué imprime este código? const valor = 30; if (valor > 50) console.log("alto"); else if (valor > 10) console.log("medio"); else console.log("bajo");', 'seleccion',
     [('a', 'medio'), ('b', 'alto'), ('c', 'bajo')], 'a', '30 > 10 y no > 50: medio.'),
    ('30000000-0000-0000-0000-000000000017', 3, 'Una condición falsa termina el while.', 'verdadero_falso',
     [('v', 'Mientras haya verdad hay repetición; cuando es falsa, termina.'), ('f', 'while siempre ejecuta una vez.')], 'v', 'while evalúa antes de cada iteración.'),
    ('30000000-0000-0000-0000-000000000017', 4, '¿Qué imprime este código? const x = 0; if (x) console.log("si"); else console.log("no");', 'seleccion',
     [('a', 'no'), ('b', 'si'), ('c', 'undefined')], 'a', '0 es falsy en JavaScript.'),
    ('30000000-0000-0000-0000-000000000017', 5, 'En else if, el orden importa.', 'verdadero_falso',
     [('v', 'Las primeras condiciones se evalúan primero.'), ('f', 'No importa el orden.')], 'v', 'Siempre se evalúan de arriba hacia abajo.'),

    ('30000000-0000-0000-0000-000000000018', 1, '¿Qué imprime este código? let suma = 0; for (let i = 1; i <= 4; i++) suma = suma + i; console.log(suma);', 'seleccion',
     [('a', '10'), ('b', '4'), ('c', 'undefined')], 'a', '1+2+3+4 = 10.'),
    ('30000000-0000-0000-0000-000000000018', 2, 'Un acumulador guarda:', 'seleccion',
     [('a', 'Un total que crece en cada iteración.'), ('b', 'Un contador 0/1.'), ('c', 'El índice actual.')], 'a', 'Un acumulador suma sobre sí mismo en cada paso.'),
    ('30000000-0000-0000-0000-000000000018', 3, '¿Qué imprime este código? let c = 0; for (let i = 0; i < 7; i++) { if (i % 2 === 0) c = c + 1; } console.log(c);', 'seleccion',
     [('a', '4'), ('b', '3'), ('c', '7')], 'a', 'i en 0, 2, 4, 6: 4 valores pares.'),
    ('30000000-0000-0000-0000-000000000018', 4, '¿Qué rol tiene i en for?', 'seleccion',
     [('a', 'Contador que aumenta en cada iteración.'), ('b', 'No cambia.'), ('c', 'Es un acumulador.')], 'a', 'i es el contador clásico del for.'),

    ('30000000-0000-0000-0000-000000000019', 1, 'Un bucle infinito produce:', 'seleccion',
     [('a', 'Un bloqueo temporal típico.'), ('b', 'Una excepción inmediata.'), ('c', 'Un error de sintaxis.')], 'a', 'while(true) nunca termina por sí solo.'),
    ('30000000-0000-0000-0000-000000000019', 2, '¿Qué termina primero? while (n < 100) n = n + 10; donde n empieza en 0.', 'seleccion',
     [('a', 'Cuando n llega a 100.'), ('b', 'Nunca.'), ('c', 'Cuando n llega a 1000.')], 'a', '0+10+10+…=100 ⇒ termina cuando n=100.'),
    ('30000000-0000-0000-0000-000000000019', 3, '¿Qué pasa si la condición de while es falsa desde el inicio?', 'seleccion',
     [('a', 'No se ejecuta; sigue con la siguiente instrucción.'), ('b', 'Ejecuta una vez igual.'), ('c', 'Produce error.')], 'a', 'El cuerpo puede no ejecutarse nunca.'),
    ('30000000-0000-0000-0000-000000000019', 4, 'Un for necesita que la condición sea falsa para terminar.', 'verdadero_falso',
     [('v', 'i <= 5 detiene en 5; i >= 0 con i++ nunca se detiene.'), ('f', 'Termina por tiempo por sí solo.')], 'v', 'Termina cuando la condición es falsa.'),

    ('30000000-0000-0000-0000-000000000020', 1, '¿Qué imprime este código? let sum = 0; for (let i = 0; i < 3; i++) sum = sum + 10; console.log(sum);', 'seleccion',
     [('a', '30'), ('b', '10'), ('c', '0')], 'a', 'En cada vuelta sum = sum + 10: 10, 20, 30.'),
    ('30000000-0000-0000-0000-000000000020', 2, '¿Qué imprime este código? let c = 0; for (let i = 0; i < 6; i++) c = c + (i % 2); console.log(c);', 'seleccion',
     [('a', '3'), ('b', '6'), ('c', '9')], 'a', 'i en 0,1,2,3,4,5: pares 0+0+0 (3), impares 1+1+1 (3) — total 3.'),
    ('30000000-0000-0000-0000-000000000020', 3, '¿Cuántas veces se repite este bucle para que x llegue a 50? x = 2; while (x < 50) x = x * 2;', 'seleccion',
     [('a', 'Cinco veces (2→4→8→16→32→64).'), ('b', 'Diez veces.'), ('c', 'Infinitamente.')], 'a', '2,4,8,16,32,64: 5 pasos.'),
    ('30000000-0000-0000-0000-000000000020', 4, 'Una condición falsa termina el while.', 'verdadero_falso',
     [('v', 'Mientras la condición sea verdadera, repite.'), ('f', 'while siempre ejecuta una vez.')], 'v', 'while evalúa antes de cada iteración.'),
    ('30000000-0000-0000-0000-000000000020', 5, '¿Qué imprime este código? let sum = 0; for (let i = 0; i < 4; i++) sum = sum + 5; console.log(sum);', 'seleccion',
     [('a', '20'), ('b', '15'), ('c', '25')], 'a', '0+5+5+5+5 = 20.'),

    ('30000000-0000-0000-0000-000000000021', 1, '¿Cuál es la diferencia entre parámetro y argumento?', 'seleccion',
     [('a', 'Parámetro es el nombre en la declaración; argumento el valor enviado.'), ('b', 'Son lo mismo.'), ('c', 'Argumento es el nombre; parámetro el valor.')],
     'a', 'Parámetro = variable, argumento = valor enviado.'),
    ('30000000-0000-0000-0000-000000000021', 2, '¿Qué imprime este código? function saludar(nombre) { console.log("Hola " + nombre); } saludar("Ana");', 'seleccion',
     [('a', 'Hola Ana'), ('b', 'Hola nombre'), ('c', 'Hola')], 'a', 'El argumento "Ana" entra como parámetro nombre.'),
    ('30000000-0000-0000-0000-000000000021', 3, '¿Qué imprime este código? function suma(a, b) { return a + b; } console.log(suma(2, 3));', 'seleccion',
     [('a', '5'), ('b', '23'), ('c', 'undefined')], 'a', 'a=2, b=3, devuelve 5.'),
    ('30000000-0000-0000-0000-000000000021', 4, '¿Qué valen a y b en suma(2, 3)?', 'seleccion',
     [('a', 'a=2, b=3'), ('b', 'a=3, b=2'), ('c', 'a="2", b="3"')], 'a', 'Los argumentos se asignan por orden.'),

    ('30000000-0000-0000-0000-000000000022', 1, '¿Qué pasa si una función no tiene return?', 'seleccion',
     [('a', 'Devuelve undefined.'), ('b', 'Devuelve null.'), ('c', 'Lanza una excepción.')], 'a', 'Toda función devuelve algo: undefined por defecto.'),
    ('30000000-0000-0000-0000-000000000022', 2, 'Escribí el valor que falta para que la función devuelva w * h: return ___;', 'completar_texto',
     [('x', 'w * h')], 'w * h', 'return w * h; devuelve el área.'),
    ('30000000-0000-0000-0000-000000000022', 3, '¿Qué imprime este código? function uno() { return 10; } console.log(uno() + uno());', 'seleccion',
     [('a', '20'), ('b', '10'), ('c', 'undefined')], 'a', '10 + 10 = 20.'),
    ('30000000-0000-0000-0000-000000000022', 4, '¿Qué imprime? function doble(x) { return x * 2; } console.log(doble(8));', 'seleccion',
     [('a', '16'), ('b', '8'), ('c', 'undefined')], 'a', 'doble(8) devuelve 16.'),

    ('30000000-0000-0000-0000-000000000023', 1, '¿Qué devuelve map en el código anterior?', 'seleccion',
     [('a', 'Un nuevo array con valores modificados.'), ('b', 'Un array vacío.'), ('c', 'El array original.')], 'a', 'map transforma y devuelve un nuevo array.'),
    ('30000000-0000-0000-0000-000000000023', 2, '¿Qué imprime este código? const nums = [1, 2, 3]; console.log(nums.map(n => n + 1));', 'seleccion',
     [('a', '[2, 3, 4]'), ('b', '[1, 2, 3]'), ('c', '[2, 4, 6]')], 'a', 'n + 1 sobre cada elemento.'),
    ('30000000-0000-0000-0000-000000000023', 3, '¿Qué hace filter?', 'seleccion',
     [('a', 'Devuelve los elementos que cumplen la condición.'), ('b', 'Devuelve el primero que coincide.'), ('c', 'Modifica el array original.')], 'a', 'filter es selectiva, no destructiva.'),
    ('30000000-0000-0000-0000-000000000023', 4, '¿Qué imprime? const nums = [1, 2, 3, 4]; console.log(nums.filter(n => n > 2));', 'seleccion',
     [('a', '[3, 4]'), ('b', '[1, 2]'), ('c', '[2, 3, 4]')], 'a', 'n > 2: queda 3 y 4.'),
    ('30000000-0000-0000-0000-000000000023', 5, 'map crea un nuevo array; filter selecciona.', 'verdadero_falso',
     [('v', 'Map transforma 1 a 1; filter reduce por condicion.'), ('f', 'Concatenan.')], 'v', 'Map transforma 1:1; filter selecciona.'),

    ('30000000-0000-0000-0000-000000000024', 1, '¿Qué diferencia a una propiedad de un método?', 'seleccion',
     [('a', 'Propiedad guarda dato; método es función del objeto.'), ('b', 'No hay diferencia.'), ('c', 'Un método es propiedad de un array.')],
     'a', 'propiedad = dato; método = función.'),
    ('30000000-0000-0000-0000-000000000024', 2, '¿Qué imprime este código? const o = { n: 5, d() { return this.n * 2; } }; console.log(o.d());', 'seleccion',
     [('a', '10'), ('b', '25'), ('c', 'undefined')], 'a', 'd() devuelve 5 * 2 = 10.'),
    ('30000000-0000-0000-0000-000000000024', 3, 'Escribí qué falta para que o.mostrar() llame al método mostrar: const o = { ___: function mostrar() { console.log("hola"); } };', 'completar_texto',
     [('x', 'mostrar')], 'mostrar', 'El nombre de la propiedad es el nombre del método.'),
    ('30000000-0000-0000-0000-000000000024', 4, '¿Qué imprime este código? const o = { x: 1 }; console.log(o.x);', 'seleccion',
     [('a', '1'), ('b', 'undefined'), ('c', 'o.x')], 'a', 'Se accede con el punto.'),

    ('30000000-0000-0000-0000-000000000025', 1, '¿Qué es el DOM?', 'seleccion',
     [('a', 'Document Object Model: la representación en árbol de la página.'), ('b', 'Un lenguaje de programación.'), ('c', 'Una base de datos.')],
     'a', 'El DOM es el árbol de la página.'),
    ('30000000-0000-0000-0000-000000000025', 2, '¿Qué hace document.querySelector?', 'seleccion',
     [('a', 'Devuelve el primer elemento que coincide con el selector.'), ('b', 'Devuelve todos los elementos.'), ('c', 'No hace nada.')],
     'a', 'Primer match según selector CSS.'),
    ('30000000-0000-0000-0000-000000000025', 3, 'El DOM es una API.', 'verdadero_falso',
     [('v', 'El navegador expone el DOM como API.'), ('f', 'No es una API.')], 'v', 'document, window, console son partes del DOM.'),
    ('30000000-0000-0000-0000-000000000025', 4, '¿Qué hace el código siguiente? document.querySelector("#btn").addEventListener("click", () => console.log("clic"));', 'seleccion',
     [('a', 'Imprime "clic" cuando se presiona el botón con id btn.'), ('b', 'Imprime "clic" al cargar la página.'), ('c', 'Cambia el texto del botón.')],
     'a', 'addEventListener suscribe a eventos del elemento.'),

    ('30000000-0000-0000-0000-000000000010', 1, 'En tu proyecto, ¿qué hace function guardar?', 'seleccion',
     [('a', 'Guarda la nota y actualiza la vista.'), ('b', 'Borra todo.'), ('c', 'Nada.')], 'a', 'La función guardar administra las notas del proyecto.'),
    ('30000000-0000-0000-0000-000000000010', 2, 'Ordenar 1 vs 2: ¿Qué va primero?', 'verdadero_falso',
     [('v', 'Primero declarás, después usás.'), ('f', 'Primero console.log, después declaráis.')], 'v', 'Declarar, después usar.'),
    ('30000000-0000-0000-0000-000000000010', 3, '¿Qué imprime este código? const notas = [{id: 1, texto: "a"}, {id: 2, texto: "b"}]; console.log(notas.length);', 'seleccion',
     [('a', '2'), ('b', '1'), ('c', 'undefined')], 'a', 'Hay 2 notas en el array.'),
    ('30000000-0000-0000-0000-000000000010', 4, 'Los eventos permiten reaccionar a acciones del usuario.', 'verdadero_falso',
     [('v', 'click, submit, keydown son eventos.'), ('f', 'No existen eventos.')], 'v', 'addEventListener es un método de los elementos del DOM.'),
    ('30000000-0000-0000-0000-000000000010', 5, '¿Qué hace .push en un array?', 'seleccion',
     [('a', 'Agrega un elemento al final.'), ('b', 'Quita el último.'), ('c', 'Lo vacía.')], 'a', 'push agrega al final.'),
    ('30000000-0000-0000-0000-000000000010', 6, '¿Qué hace Date.now()?', 'seleccion',
     [('a', 'Devuelve un número único para usar como id.'), ('b', 'Muestra la hora.'), ('c', 'Devuelve una fecha legible.')], 'a', 'Date.now() milisegundos únicos desde la época.'),
    ('30000000-0000-0000-0000-000000000010', 7, '¿Qué imprime este código? let notas = []; notas.push("A"); console.log(notas);', 'seleccion',
     [('a', '["A"]'), ('b', 'A'), ('c', '[]')], 'a', 'push agrega y devuelve el array.'),
    ('30000000-0000-0000-0000-000000000010', 8, 'El DOM permite modificar la página dinámicamente.', 'verdadero_falso',
     [('v', 'Cada etiqueta es un nodo que se puede cambiar.'), ('f', 'El HTML es estático.')], 'v', 'JavaScript puede cambiar el DOM en vivo.'),
    ('30000000-0000-0000-0000-000000000010', 9, 'El proyecto integrador combina todas las habilidades.', 'verdadero_falso',
     [('v', 'Integrar: HTML, CSS, JS, eventos y arrays.'), ('f', 'Seguidamente.')], 'v', 'El proyecto exige aplicar todos los conceptos.'),
]

HTML_PREGUNTAS = [
    ('70000000-0000-0000-0000-000000000001', 1, '¿Qué significa HTML?', 'seleccion',
     [('a', 'HyperText Markup Language.'), ('b', 'High Text Manipulation Language.'), ('c', 'Hyperlink and Text Markup Language.')], 'a', 'HTML es HyperText Markup Language.'),
    ('70000000-0000-0000-0000-000000000001', 2, 'HTML es un lenguaje de programación.', 'verdadero_falso',
     [('v', 'No, es un lenguaje de marcado; no ejecuta instrucciones.'), ('f', 'Ejecuta sentencias.')], 'v', 'HTML describe estructura; no ejecuta sentencias (eso lo hace JavaScript).'),
    ('70000000-0000-0000-0000-000000000001', 3, '¿Cuál es el propósito principal de HTML?', 'seleccion',
     [('a', 'Estructurar el contenido de las páginas web.'), ('b', 'Diseñar imágenes y logotipos.'), ('c', 'Servir datos a aplicaciones móviles.')], 'a', 'HTML define la estructura del documento.'),
    ('70000000-0000-0000-0000-000000000001', 4, '¿Qué hace una declaración <!DOCTYPE html>?', 'seleccion',
     [('a', 'Le dice al navegador que el documento es HTML5.'), ('b', 'Crea el primer párrafo.'), ('c', 'No hace nada.')], 'a', 'DOCTYPE declara el tipo de documento al navegador.'),

    ('70000000-0000-0000-0000-000000000002', 1, '¿Cuál es un título de segundo nivel?', 'seleccion',
     [('a', '<h2>'), ('b', '<h1>'), ('c', '<h3>')], 'a', 'h1-h6 jerarquía según importancia.'),
    ('70000000-0000-0000-0000-000000000002', 2, '¿Cuál es el orden correcto de anidamiento?', 'seleccion',
     [('a', '<h1><h2>Texto</h2></h1>'), ('b', '<h2><h1>Texto</h1></h2>'), ('c', 'No importa.')], 'a', 'Las etiquetas deben abrirse y cerrarse en orden inverso.'),
    ('70000000-0000-0000-0000-000000000002', 3, '¿Qué hace el comentario <!-- comentario -->?', 'seleccion',
     [('a', 'Se ignora al renderizar; sirve para anotar.'), ('b', 'Muestra el comentario en la página.'), ('c', 'Lanza un error.')], 'a', 'Los comentarios son para el autor.'),
    ('70000000-0000-0000-0000-000000000002', 4, 'La etiqueta <br> necesita cierre.', 'verdadero_falso',
     [('v', 'br es un salto de línea sin contenido; no lleva cierre.'), ('f', 'Va <br></br>.')], 'v', 'br, hr, img, input son etiquetas vacías.'),

    ('70000000-0000-0000-0000-000000000003', 1, '¿Qué etiqueta envuelve al cuerpo?', 'seleccion',
     [('a', '<body>'), ('b', '<html>'), ('c', '<head>')], 'a', 'body es el contenido visible.'),
    ('70000000-0000-0000-0000-000000000003', 2, 'El <title> de un documento HTML aparece en la pestaña del navegador.', 'verdadero_falso',
     [('v', 'El contenido de title se muestra en la pestaña.'), ('f', 'Los títulos no van en ningún lado.')], 'v', '<title> está dentro de <head> y define el título de la pestaña.'),
    ('70000000-0000-0000-0000-000000000003', 3, '¿Qué etiqueta jerárquica es la más importante?', 'seleccion',
     [('a', '<h1>'), ('b', '<h2>'), ('c', '<h6>')], 'a', 'h1 es el encabezado de mayor jerarquía.'),
    ('70000000-0000-0000-0000-000000000003', 4, '¿Qué contiene <head>?', 'seleccion',
     [('a', 'Metadatos como charset, title, enlaces CSS.'), ('b', 'El contenido visible.'), ('c', 'Las imágenes.')], 'a', 'head NO se renderiza directamente.'),
    ('70000000-0000-0000-0000-000000000003', 5, 'Los elementos void como <img> o <input> no tienen etiqueta de cierre.', 'verdadero_falso',
     [('v', 'Son etiquetas vacías por definición.'), ('f', 'Siempre llevan cierre.')], 'v', 'img, input, br, hr, meta son void elements.'),

    ('70000000-0000-0000-0000-000000000004', 1, '¿Qué etiqueta se usa para rutas relativas?', 'seleccion',
     [('a', '<a href="contacto.html">'), ('b', '<a src="contacto.html">'), ('c', '<href="contacto.html">')], 'a', 'href es el destino de navegación.'),
    ('70000000-0000-0000-0000-000000000004', 2, 'Una ruta absoluta comienza con:', 'seleccion',
     [('a', 'https://'), ('b', '/'), ('c', './')], 'a', 'Las rutas absolutas empiezan con protocolo.'),
    ('70000000-0000-0000-0000-000000000004', 3, 'Un enlace relativo desde index.html a carpeta/archivo.html es:', 'seleccion',
     [('a', '<a href="carpeta/archivo.html">'), ('b', '<a href="archivo.html">'), ('c', '<a href="../archivo.html">')], 'a', 'Las rutas relativas incluyen la carpeta desde el documento.'),
    ('70000000-0000-0000-0000-000000000004', 4, 'Un enlace puede abrirse en nueva pestaña con:', 'seleccion',
     [('a', 'target="_blank"'), ('b', 'newtab="true"'), ('c', 'target="new"')], 'a', 'target="_blank" abre en pestaña nueva.'),

    ('70000000-0000-0000-0000-000000000005', 1, '¿Qué etiqueta se usa para elementos de lista?', 'seleccion',
     [('a', '<li>'), ('b', '<ol>'), ('c', '<ul>')], 'a', 'li = list item.'),
    ('70000000-0000-0000-0000-000000000005', 2, '¿Cuál lista muestra números por defecto?', 'seleccion',
     [('a', '<ol>'), ('b', '<ul>'), ('c', '<li>')], 'a', 'ol = números; ul = viñetas.'),
    ('70000000-0000-0000-0000-000000000005', 3, '¿Qué crea anidadas?', 'seleccion',
     [('a', 'Poner un <ul>/<ol> dentro de un <li>.'), ('b', 'Anidar etiquetas libremente.'), ('c', 'Usar <dir>.')], 'a', 'Anidá listas dentro de li.'),
    ('70000000-0000-0000-0000-000000000005', 4, 'La etiqueta <li> requiere cierre.', 'verdadero_falso',
     [('v', '<li>…</li> siempre lleva cierre.'), ('f', 'Es auto-cerrada.')], 'v', 'li requiere cierre.'),

    ('70000000-0000-0000-0000-000000000006', 1, 'Un documento válido tiene DOCTYPE como primer elemento.', 'verdadero_falso',
     [('v', 'DOCTYPE es el primer tag del archivo.'), ('f', 'Es el <title>.')], 'v', '<!DOCTYPE html> debe ser el primer nodo.'),
    ('70000000-0000-0000-0000-000000000006', 2, 'Una imagen sin alt pierde accesibilidad.', 'verdadero_falso',
     [('v', 'src + alt cubrirían el caso completo.'), ('f', 'alt siempre soporta.')], 'v', 'alt obligatorio para accesibilidad.'),
    ('70000000-0000-0000-0000-000000000006', 3, 'Ordenar un artículo simple: el orden correcto es:', 'seleccion',
     [('a', '<p>Primero</p><p>Segundo</p>'), ('b', '</p><p>Texto</p>'), ('c', '<p>Texto</p></p>')], 'a', 'Abrir, contenido, cerrar correctamente.'),
    ('70000000-0000-0000-0000-000000000006', 4, '¿Qué etiqueta envuelve al cuerpo?', 'seleccion',
     [('a', '<body>'), ('b', '<html>'), ('c', '<head>')], 'a', 'body envuelve todo lo visible.'),
    ('70000000-0000-0000-0000-000000000006', 5, 'Las listas HTML usan <ul>/<ol> + <li>.', 'verdadero_falso',
     [('v', '<ul> y <ol> son contenedores; <li> los ítems.'), ('f', 'Li es contenedor.')], 'v', 'ul/ol vs li.'),

    ('70000000-0000-0000-0000-000000000007', 1, '¿Qué es una etiqueta block?', 'seleccion',
     [('a', 'Una etiqueta que ocupa todo el ancho disponible.'), ('b', 'Una etiqueta inline.'), ('c', 'Un input.')], 'a', 'Los block elements rompen la línea y ocupan todo el ancho.'),
    ('70000000-0000-0000-0000-000000000007', 2, '<div> es un contenedor genérico.', 'verdadero_falso',
     [('v', 'div = division, contenedor sin significado.'), ('f', 'div es semántico.')], 'v', 'div es no-semántico; preferí section/article cuando aplique.'),
    ('70000000-0000-0000-0000-000000000007', 3, '¿Qué contiene semánticamente un artículo?', 'seleccion',
     [('a', 'Contenido independiente que puede extraerse.'), ('b', 'El pie de página.'), ('c', 'La navegación.')], 'a', 'article es contenido autónomo.'),
    ('70000000-0000-0000-0000-000000000007', 4, '¿Qué etiqueta contiene una cabecera principal?', 'seleccion',
     [('a', '<header>'), ('b', '<footer>'), ('c', '<main>')], 'a', 'header = encabezado de página o de sección.'),
    ('70000000-0000-0000-0000-000000000007', 5, 'Una etiqueta <section> distingue por tema, no por contenido.', 'verdadero_falso',
     [('v', 'section agrupa contenidos temáticos.'), ('f', 'Es similar a div.')], 'v', 'section es una agrupación temática.'),

    ('70000000-0000-0000-0000-000000000008', 1, '¿Qué etiqueta envuelve el contenido principal?', 'seleccion',
     [('a', '<main>'), ('b', '<body>'), ('c', '<content>')], 'a', 'main es único por página.'),
    ('70000000-0000-0000-0000-000000000008', 2, '¿Qué va en <footer>?', 'seleccion',
     [('a', 'Fin de página: autor, copyright, enlaces legales.'), ('b', 'La barra de navegación.'), ('c', 'El título principal.')], 'a', 'footer es el cierre del documento o de una sección.'),
    ('70000000-0000-0000-0000-000000000008', 3, '¿Qué etiqueta envuelve la navegación principal?', 'seleccion',
     [('a', '<nav>'), ('b', '<menu>'), ('c', '<links>')], 'a', 'nav = navigator.'),
    ('70000000-0000-0000-0000-000000000008', 4, '¿Qué debería contener <header>?', 'seleccion',
     [('a', 'Logo, título y navegación del sitio.'), ('b', 'El contenido más largo.'), ('c', 'Sólo imágenes.')], 'a', 'header = encabezado del sitio o sección.'),

    ('70000000-0000-0000-0000-000000000009', 1, '¿Qué hace <article>?', 'seleccion',
     [('a', 'Contenido independiente y auto-contenido.'), ('b', 'Agrupa párrafos juntos.'), ('c', 'Es un contenedor genérico.')], 'a', 'article = contenido que se puede extraer y entender solo.'),
    ('70000000-0000-0000-0000-000000000009', 2, '¿Qué hace <section>?', 'seleccion',
     [('a', 'Agrupa contenido relacionado temáticamente.'), ('b', 'Es el container principal.'), ('c', 'Es una etiqueta vacía.')], 'a', 'section agrupa información relacionada.'),
    ('70000000-0000-0000-0000-000000000009', 3, 'article necesita siempre encabezado h2/h3.', 'verdadero_falso',
     [('v', 'Buenas prácticas: article comienza con encabezado.'), ('f', 'No.')], 'v', 'article con encabezado es un patrón accesible.'),
    ('70000000-0000-0000-0000-000000000009', 4, '¿Qué etiqueta tiene significado semántico?', 'seleccion',
     [('a', '<aside>'), ('b', '<div>'), ('c', '<span>')], 'a', 'aside = contenido complementario.'),

    ('70000000-0000-0000-0000-00000000000a', 1, 'El elemento <br> crea:', 'seleccion',
     [('a', 'Un salto de línea.'), ('b', 'Una línea horizontal.'), ('c', 'Un párrafo.')], 'a', 'br = line break.'),
    ('70000000-0000-0000-0000-00000000000a', 2, 'El elemento <hr> crea:', 'seleccion',
     [('a', 'Una línea horizontal.'), ('b', 'Un salto de línea.'), ('c', 'Un separador visual sin significado.')], 'a', 'hr = horizontal rule.'),
    ('70000000-0000-0000-0000-00000000000a', 3, 'Un bloque con <hr> indica separación temática.', 'verdadero_falso',
     [('v', 'hr marca cambio de tema o escena.'), ('f', 'Es sólo estético.')], 'v', 'hr es semántica: cambio de sección temática.'),
    ('70000000-0000-0000-0000-00000000000a', 4, '¿Qué debería contener una página bien estructurada?', 'seleccion',
     [('a', 'header, main y footer con contenido relacionado.'), ('b', 'Sólo body.'), ('c', 'Sólo divs.')], 'a', 'Estructura típica y semántica: header+main+footer.'),
    ('70000000-0000-0000-0000-00000000000a', 5, 'HTML semántico mejora la accesibilidad y el SEO.', 'verdadero_falso',
     [('v', 'nav, header, main, footer, article mejoran lectura.'), ('f', 'Es indiferente.')], 'v', 'Semántica beneficia a lectores y buscadores.'),

    ('70000000-0000-0000-0000-00000000000b', 1, '¿Por qué usar <label>?', 'seleccion',
     [('a', 'El clic en el label enfoca el campo; mejora accesibilidad.'), ('b', 'Es sólo estético.'), ('c', 'No tiene ventajas.')], 'a', 'label mejora la usabilidad y la accesibilidad.'),
    ('70000000-0000-0000-0000-00000000000b', 2, '¿Qué atributo vincula label con input?', 'seleccion',
     [('a', 'for'), ('b', 'id'), ('c', 'to')], 'a', 'for + id: label for → input id.'),
    ('70000000-0000-0000-0000-00000000000b', 3, 'El texto del label debe explicar el campo.', 'verdadero_falso',
     [('v', '"Nombre" para el campo nombre completo.'), ('f', 'No importa el texto.')], 'v', 'Los labels deben ser claros y descriptivos.'),
    ('70000000-0000-0000-0000-00000000000b', 4, 'Un sitio accesible usa <label> en sus formularios.', 'verdadero_falso',
     [('v', 'Screen readers dependen de label.'), ('f', 'No importa.')], 'v', 'Los lectores de pantalla anuncian label al enfocar.'),

    ('70000000-0000-0000-0000-00000000000c', 1, '¿Qué tipo de input crea un botón de envío?', 'seleccion',
     [('a', 'submit'), ('b', 'button'), ('c', 'send')], 'a', '<input type="submit"> envía el formulario.'),
    ('70000000-0000-0000-0000-00000000000c', 2, '¿Qué tipo de input crea un campo numérico?', 'seleccion',
     [('a', 'number'), ('b', 'text'), ('c', 'int')], 'a', '<input type="number">.'),
    ('70000000-0000-0000-0000-00000000000c', 3, '¿Qué tipo de input crea un checkbox?', 'seleccion',
     [('a', 'checkbox'), ('b', 'check'), ('c', 'bool')], 'a', '<input type="checkbox">.'),
    ('70000000-0000-0000-0000-00000000000c', 4, 'Los radio buttons se agrupan con el mismo atributo name.', 'verdadero_falso',
     [('v', 'Mismo name → selección única.'), ('f', 'Necesitan id distinto.')], 'v', 'Agrupá radio buttons con name compartido.'),

    ('70000000-0000-0000-0000-00000000000d', 1, 'Un formulario puede tener varios tipos de input.', 'verdadero_falso',
     [('v', 'Text, email, number, checkbox, radio…'), ('f', 'Sólo uno por formulario.')], 'v', 'Los formularios combinan campos de tipos diferentes.'),
    ('70000000-0000-0000-0000-00000000000d', 2, 'El atributo name es el identificador del campo.', 'verdadero_falso',
     [('v', 'name es la clave que recibe el servidor.'), ('f', 'id es lo mismo.')], 'v', 'name es lo que viaja al servidor.'),
    ('70000000-0000-0000-0000-00000000000d', 3, 'Ordenar un formulario válido: el orden correcto es:', 'seleccion',
     [('a', '<form><label>…</label><input></form>'), ('b', '</form><form><input>'), ('c', '<input></input>')], 'a', 'Form, label, input, cierre.'),
    ('70000000-0000-0000-0000-00000000000d', 4, 'Los formularios son la puerta de entrada de datos.', 'verdadero_falso',
     [('v', 'Cada dato viaja con su name asociado.'), ('f', 'Los formularios no recopilan datos.')], 'v', 'name es esencial para recibir datos.'),
    ('70000000-0000-0000-0000-00000000000d', 5, 'El type del input determina el control visual.', 'verdadero_falso',
     [('v', 'Text, email, number, checkbox, radio…'), ('f', 'Siempre luce igual.')], 'v', 'El type produce controles diferentes.'),

    ('70000000-0000-0000-0000-00000000000e', 1, '¿Qué etiqueta incrusta audio?', 'seleccion',
     [('a', '<audio>'), ('b', '<sound>'), ('c', '<music>')], 'a', 'audio = sonido.'),
    ('70000000-0000-0000-0000-00000000000e', 2, '¿Qué atributo muestra los controles?', 'seleccion',
     [('a', 'controls'), ('b', 'panel'), ('c', 'buttons')], 'a', 'controls activa UI de play/pausa y volumen.'),
    ('70000000-0000-0000-0000-00000000000e', 3, '¿Qué atributo indica el archivo?', 'seleccion',
     [('a', 'src'), ('b', 'href'), ('c', 'file')], 'a', 'src = origen.'),
    ('70000000-0000-0000-0000-00000000000e', 4, 'Declarar <audio> sin controls lo hace invisible.', 'verdadero_falso',
     [('v', 'Sin controls no hay UI reproducible.'), ('f', 'Siempre se ven controles.')], 'v', 'controls muestra la interfaz de reproducción.'),

    ('70000000-0000-0000-0000-00000000000f', 1, '¿Qué es aria-label?', 'seleccion',
     [('a', 'Atributo ARIA que describe el propósito a lectores de pantalla.'), ('b', 'Una etiqueta visual oculta.'), ('c', 'Nada.')],
     'a', 'ARIA = Accessible Rich Internet Applications.'),
    ('70000000-0000-0000-0000-00000000000f', 2, 'El alt de una imagen informativa debe describirla.', 'verdadero_falso',
     [('v', '"Foto del campus" es correcto; "" para imágenes decorativas.'), ('f', 'alt = texto alternativo obligatorio en todas.')],
     'v', 'Decorativa: alt=""; informativa: alt="descripción".'),
    ('70000000-0000-0000-0000-00000000000f', 3, 'Un HTML accesible usa h1-h6 en orden de jerarquía.', 'verdadero_falso',
     [('v', 'h1 > h2 > h3 …'), ('f', 'Se elige aleatorio.')], 'v', 'La jerarquía facilita navegación asistida.'),
    ('70000000-0000-0000-0000-00000000000f', 4, '¿Qué hace prefers-reduced-motion?', 'seleccion',
     [('a', 'Respetar que el usuario prefiere menos animación.'), ('b', 'Activar contraste alto.'), ('c', 'Nada.')], 'a', 'Los usuarios con sensibilidad vestibular prefieren menos movimiento.'),
]

LECCIONES_JS_EXISTENTES = {
    '30000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000008',
    '30000000-0000-0000-0000-000000000009', '30000000-0000-0000-0000-000000000010',
}
LECCIONES_HTML_EXISTENTES = {
    '707e84f0-fc33-bb22-2e7c-97bf32d4c0ed',
    '4bfdf59b-4b84-10c9-20f0-f095ce26f405',
    '3e8ffb80-ab9d-66e0-47e1-fd1eb7948f66',
    '92153c83-c8e8-3f06-ca75-2d205d4eea72',
    'd14606e6-b4bb-8499-e4c8-dffb7b31170f',
    'bf446ed2-3603-f4cf-71a3-4c3975379935',
    '256fb823-7c87-b186-8820-43dd4c2734c9',
    '1011b119-e854-cbc3-9561-0afe891a11eb',
    '9745df43-9522-1db7-395b-1fd810c05c28',
    '8caf4505-8287-cc71-c800-dcf8c454cf22',
}
JS_PREGUNTAS = [q for q in JS_PREGUNTAS if q[0] not in LECCIONES_JS_EXISTENTES]
HTML_PREGUNTAS = [q for q in HTML_PREGUNTAS if q[0] not in LECCIONES_HTML_EXISTENTES]
print('JS preguntas:', len(JS_PREGUNTAS), '| HTML preguntas:', len(HTML_PREGUNTAS))

def sql_esc(s):
    return str(s).replace("'", "''")

def build():
    out = ['-- ===============================================================',
           '-- migracion-v3: ampliar JS y HTML a 5 unidades x 5 lecciones',
           '-- Idempotente: sólo inserta/actualiza; no borra nada.',
           '-- ===============================================================\n']

    # ------------------------------------------------------------------
    # 0) PASO OBLIGATORIO: corrido previo de los orden existentes.
    #    El unique (unidad_id, orden) se aplica por fila; si no se mueven
    #    las lecciones sembradas antes de insertar/renumerar, los upserts
    #    chocan con las filas viejas que aun ocupan orden 1..5.
    #    Sólo corre sobre filas con orden < 1000 → idempotente.
    # ------------------------------------------------------------------
    unidades_reescritas = [
        '20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000004',
        '20000000-0000-0000-0000-000000000005',
        '65223173-50c1-47fc-6123-b5b094d85a34', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa',
        '185cf7ac-af6f-4daf-11da-41ac2b744411', '70000000-0000-0000-0000-000000000100',
        '70000000-0000-0000-0000-000000000101',
    ]
    out.append('-- Paso 0: corrido temporal de los orden (idempotente)')
    out.append(f"update lecciones set orden = orden + 1000 where unidad_id in ({', '.join(chr(39)+u+chr(39) for u in unidades_reescritas)}) and orden < 1000;")

    nuevas_unidades = [
        ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'Funciones y estructuras', 'Organizá tu código en bloques reutilizables: funciones, parámetros, retornos y arrays.', 4, 'bloqueada'),
        ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'Objetos y aplicaciones', 'Objetos, cadenas, métodos y un proyecto completo con DOM y eventos.', 5, 'bloqueada'),
        ('70000000-0000-0000-0000-000000000100', '10000000-0000-0000-0000-000000000002', 'Formularios', 'Armá formularios funcionales con inputs, labels y botones.', 4, 'bloqueada'),
        ('70000000-0000-0000-0000-000000000101', '10000000-0000-0000-0000-000000000002', 'Integración y buenas prácticas', 'Tablas, multimedia, accesibilidad y un proyecto final.', 5, 'bloqueada'),
    ]
    for uid, cid, nombre, desc, orden, estado in nuevas_unidades:
        out.append(f"insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('{uid}', '{cid}', '{sql_esc(nombre)}', '{sql_esc(desc)}', {orden}, '{estado}') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;")

    renombres = [
        ('20000000-0000-0000-0000-000000000001', 'Introducción a JavaScript', 'Conocé qué es, variables, tipos, operadores y tu primer Hola mundo.', 1, 'publicado'),
        ('20000000-0000-0000-0000-000000000002', 'Condicionales y lógica', 'Elegí qué camino sigue tu programa con if, else if, else y booleanos.', 2, 'bloqueada'),
        ('20000000-0000-0000-0000-000000000003', 'Repeticiones', 'Hacé que la computadora repita con for y while.', 3, 'bloqueada'),
        ('65223173-50c1-47fc-6123-b5b094d85a34', 'Primeros pasos con HTML', 'Estructura, etiquetas y elementos para empezar con las páginas web.', 1, 'publicado'),
        ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 'Contenido y enlaces', 'Listas, enlaces, rutas e imágenes para organizar contenido.', 2, 'bloqueada'),
        ('185cf7ac-af6f-4daf-11da-41ac2b744411', 'Organización de páginas', 'Contenedores, semántica y estructuras completas.', 3, 'bloqueada'),
    ]
    for uid, nombre, desc, orden, estado in renombres:
        out.append(f"insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('{uid}', (select curso_id from unidades where id = '{uid}'), '{sql_esc(nombre)}', '{sql_esc(desc)}', {orden}, '{estado}') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;")

    for unidad_id, orden, lid, titulo, explicacion, ejemplo, estado in JS_LECCIONES + HTML_LECCIONES:
        out.append(f"insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('{lid}', '{unidad_id}', '{sql_esc(titulo)}', '{sql_esc(explicacion)}', '{sql_esc(ejemplo)}', {orden}, '{estado}') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;")

    for leccion_id, orden, enunciado, tipo, opciones, correcta, explicacion in JS_PREGUNTAS + HTML_PREGUNTAS:
        pid = md5_uuid(f'pq:{leccion_id}:{orden}')
        sol_id = md5_uuid(f'sol:{pid}')
        if tipo in ('seleccion', 'verdadero_falso', 'predecir'):
            out.append(f"insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('{pid}', '{leccion_id}', '{sql_esc(enunciado)}', '{tipo}', {orden}, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;")
            order_n = 1
            for key, txt in opciones:
                oid = md5_uuid(f'opt:{pid}:{key}')
                out.append(f"insert into opciones (id, pregunta_id, texto, orden) values ('{oid}', '{pid}', '{sql_esc(txt)}', {order_n}) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;")
                order_n += 1
            correcta_id = md5_uuid(f'opt:{pid}:{correcta}')
            out.append(f"insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('{sol_id}', '{pid}', '{correcta_id}', '{sql_esc(explicacion)}') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;")
        elif tipo == 'completar_texto':
            datos = datos_json({'alternativas': [], 'valor': correcta})
            out.append(f"insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('{pid}', '{leccion_id}', '{sql_esc(enunciado)}', 'completar_texto', '{datos}'::jsonb, {orden}, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, datos = excluded.datos, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;")
            sol = datos_json({'valor': correcta})
            out.append(f"insert into soluciones (id, pregunta_id, solucion, explicacion) values ('{sol_id}', '{pid}', '{sol}'::jsonb, '{sql_esc(explicacion)}') on conflict (pregunta_id) do update set solucion = excluded.solucion, explicacion = excluded.explicacion;")

    print(f'\nMigración generada: {len(out)} sentencias')
    with open('_migracion-v3.sql', 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out) + '\n')

build()
