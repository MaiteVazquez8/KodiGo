# Genera el seed actualizado (y una migracion incremental) del curso
# Pensamiento Logico con 15 lecciones robot (5 por unidad).
# - El seed completo reemplaza la seccion 22 de kodigo-completo.sql.
# - La migracion incremental actualiza el universo de actividades en vivo.
import hashlib
import json
import uuid

curso_id = '10000000-0000-0000-0000-000000000003'

# (unidad_idx, id, titulo, explicacion, ejemplo, orden, estado)
lecciones = [
    (1, '50000000-0000-0000-0000-000000000001', 'Despegue', 'Hoy arranca tu primera mision: llevar al robot desde el inicio hasta la estrella. Avanza hacia donde mira hasta salir del tablero.', 'Cada avance cuenta como una instrucción en la secuencia.', 1, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000002', 'Primeros giros', 'Girar no te mueve de la casilla: sólo cambia hacia dónde mira el robot. Orientá primero y después avanzá.', 'Girá a la izquierda para mirar hacia arriba.', 2, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000003', 'Recorrido clásico', 'Combiná giros y avances: avanzá cuatro casillas, girá a la derecha y avanzá hasta la estrella.', 'Orientá el robot primero, después avanzá paso a paso.', 3, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000004', 'El rodeo', 'Las casillas con × son obstáculos: el robot no puede atravesarlas. Buscá una ruta alternativa.', 'Si un obstáculo te bloquea, girá hacia el espacio libre.', 4, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000005', 'Tres bloqueos', 'Tres obstáculos te separan de la estrella. Analizá el tablero antes de escribir tu secuencia.', 'Pensá el recorrido completo antes de tocar las instrucciones.', 5, 'publicado'),

    (2, '50000000-0000-0000-0000-000000000006', 'El atajo tapado', 'El camino directo está bloqueado. Mirá dos veces el mapa: hay una ruta por la derecha que evita los obstáculos.', 'Cuando un camino se cierra, buscá el rodeo.', 1, 'publicado'),
    (2, '50000000-0000-0000-0000-000000000007', 'Rodeo obligatorio', 'No hay atajo: la única ruta posible rodea el bloqueo por arriba. Este es el nivel con más giros de la unidad.', 'Cada giro también cuenta como una instrucción.', 2, 'publicado'),
    (2, '50000000-0000-0000-0000-000000000008', 'Corregí el algoritmo', 'Este algoritmo está incompleto: avanza sólo tres casillas y se detiene antes de la estrella. Corregilo agregando el avance que falta.', 'Editá la secuencia hasta que el robot llegue a la estrella.', 3, 'publicado'),
    (2, '50000000-0000-0000-0000-000000000009', 'Precisión milimétrica', 'La ruta correcta se resuelve con 10 instrucciones mínimas si cada giro está bien pensado. Cada giro cuenta también como una instrucción.', 'Contá las casillas y los giros antes de ejecutar.', 4, 'publicado'),
    (2, '50000000-0000-0000-0000-00000000000f', 'Jefe de la unidad 2', 'El desafío definitivo de la unidad: un tablero con cinco obstáculos y sólo 12 instrucciones como límite. Pensá, planificá y ejecutá.', 'Los mejores recorridos se planean antes de pulsar Ejecutar.', 5, 'publicado'),

    (3, '50000000-0000-0000-0000-00000000000a', 'Repetir instrucciones', 'Escribir una instrucción muchas veces es un trabajo aburrido; usá un bucle para repetir avances.', 'Un bucle de 4 avances ocupa 2 instrucciones, no 4.', 1, 'publicado'),
    (3, '50000000-0000-0000-0000-00000000000b', 'Secuencias eficientes', 'Reemplazá una secuencia larga por un solo bucle. Cada bucle se ejecuta el número de veces indicado.', 'Cuatro avances equivalen a: bucle ×4 avances.', 2, 'publicado'),
    (3, '50000000-0000-0000-0000-00000000000c', 'Tomar decisiones', 'Mirá la orientación del robot: aunque no entienda condiciones, podés decidir qué giro conviene según tu posición.', 'Mirando a la izquierda o a la derecha podés decidir el próximo giro.', 3, 'publicado'),
    (3, '50000000-0000-0000-0000-00000000000d', 'Si sucede esto...', 'Antícipate: si un camino no está libre, girá antes de avanzar. Tu secuencia debe adaptarse al mapa.', 'Elegí qué instrucción agregar según la orientación.', 4, 'publicado'),
    (3, '50000000-0000-0000-0000-00000000000e', 'Desafío final', 'Combiná avances, giros y obstáculos para resolver el tablero completo con el menor número de instrucciones.', 'Cada instrucción importa. Optimizá, no recorras dos veces el mismo camino.', 5, 'publicado'),
]

ASIGNAR_PID_LECCION = {
    '50000000-0000-0000-0000-000000000001': '5fe4d9b4-d9cf-8864-d9a9-6a0949750a00',
    '50000000-0000-0000-0000-000000000002': '55a41b1d-fdaa-9b02-5b91-cf6f749cd707',
    '50000000-0000-0000-0000-000000000003': 'fb4ebd1c-4723-4baa-fe8c-d25bdb6554bc',
    '50000000-0000-0000-0000-000000000004': 'a6556a96-a6a0-8878-c6d0-583f40dc6a4b',
    '50000000-0000-0000-0000-000000000005': '74f851fb-8567-ac96-cd53-01d96d883425',
    '50000000-0000-0000-0000-000000000006': 'e36f60a9-6a34-8d26-6034-c95b3029ea3d',
    '50000000-0000-0000-0000-000000000007': 'ef09b43d-fb5b-85a1-fdd2-de9e174b2b5d',
    '50000000-0000-0000-0000-000000000008': '1fd72277-543a-a0fb-fb97-1923b229c24b',
    '50000000-0000-0000-0000-000000000009': 'f670f5d2-7e64-ad42-e6e7-7af8f0c54619',
    # Jefe de la unidad 2: id nuevo determinista.
    '50000000-0000-0000-0000-00000000000f': str(uuid.UUID(bytes=hashlib.md5(b'kodigo:robot:15:1').digest())),
    '50000000-0000-0000-0000-00000000000a': 'acdb920b-7e50-965d-a0b3-b491a14acb33',
    '50000000-0000-0000-0000-00000000000b': 'c1df8d57-3806-6140-2442-4927dfeb3710',
    '50000000-0000-0000-0000-00000000000c': 'e00bbbb9-5c28-3998-0cf1-835fe4c84412',
    '50000000-0000-0000-0000-00000000000d': 'e4e9c827-7d64-9c8c-dd14-7acde3806ff6',
    '50000000-0000-0000-0000-00000000000e': 'b2085b3e-b6f0-b13e-7780-c864e30047dd',
}

# (leccion_idx, orden, enunciado, datos, explicacion)
preguntas = [
    (0, 1, 'Avanzá en línea recta hasta la estrella. Fácil de ver, fácil de lograr.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 0, 'meta': 0, 'muros': []}, 'instrucciones': ['avanzar'], 'maxInstrucciones': 30, 'objetivo': 'Llegá a la estrella.', 'tutorial': 'tutorial-robot', 'modo': 'normal', 'ejemplo': 'Avanzá cuatro veces.'}, 'Cuatro avances seguidos te llevan directo a la estrella.'),
    (1, 1, 'El robot mira hacia la derecha. Girá y llegá a la estrella.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 1, 'meta': 0, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Girá y llegá a la estrella.', 'tutorial': 'tutorial-giros', 'modo': 'normal', 'ejemplo': 'Un giro a la izquierda deja al robot mirando hacia arriba.'}, 'Un giro a la izquierda y cuatro avances te llevan a la estrella.'),
    (2, 1, 'Combiná avances y giros para salir del inicio y llegar a la estrella.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 0, 'meta': 4, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 20, 'objetivo': 'Alcanzá la estrella con el menor número de pasos.', 'modo': 'normal', 'ejemplo': 'Cuatro avances, un giro derecha y cuatro avances.'}, 'Cuatro avances hacia arriba, un giro a la derecha y cuatro avances alcanzan la estrella.'),
    (3, 1, 'No atravesés los obstáculos (×): buscá una ruta alternativa alrededor.', {'tablero': {'dimensiones': 5, 'inicio': 22, 'rumbo': 1, 'meta': 4, 'muros': [17, 19]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 20, 'objetivo': 'Evitá los obstáculos.', 'tutorial': 'tutorial-obstaculos', 'modo': 'normal', 'ejemplo': 'Subí por la columna derecha y después cruzá por arriba.'}, 'Avanzá hasta 23, girá a la izquierda, subí por la columna y girá a la derecha para entrar en la estrella.'),
    (4, 1, 'Tres obstáculos bloquean el camino directo. Planificá tu recorrido.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 3, 'meta': 0, 'muros': [23, 18, 12]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 25, 'objetivo': 'Rodeá los tres obstáculos.', 'modo': 'normal', 'ejemplo': 'El bloqueo central obliga a rodear por arriba y a cruzar la fila superior.'}, 'Girá a la derecha, subí por la columna derecha y cruzá la fila superior hacia la estrella.'),

    (5, 1, 'El camino directo está tapado. Encontrá el atajo por la derecha.', {'tablero': {'dimensiones': 5, 'inicio': 11, 'rumbo': 1, 'meta': 14, 'muros': [13, 8, 18, 3]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 15, 'objetivo': 'Elegí la ruta correcta.', 'modo': 'normal', 'ejemplo': 'Bajá, entrá por la derecha y cruzá por abajo.'}, 'El atajo: avanzá, bajá por la derecha, doblé a la izquierda y cruzá por abajo.'),
    (6, 1, 'No hay atajos: la única ruta posible rodea el bloqueo por arriba.', {'tablero': {'dimensiones': 5, 'inicio': 16, 'rumbo': 0, 'meta': 24, 'muros': [22, 17, 12, 2]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 15, 'objetivo': 'Encontrá la ruta válida.', 'modo': 'normal', 'ejemplo': 'Subí dos casillas y después cruzá por la derecha.'}, 'Sólo hay una ruta: subir y cruzar por la derecha hacia la estrella.'),
    (7, 1, 'Este algoritmo está incompleto: no alcanza la estrella. Corregilo para que funcione.', {'tablero': {'dimensiones': 5, 'inicio': 15, 'rumbo': 1, 'meta': 19, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Corregí el algoritmo defectuoso.', 'modo': 'corregir', 'errores': ['Avanzar → Avanzar → Avanzar', 'A la secuencia le falta un avance: el robot se detiene una casilla antes de la estrella.'], 'ejemplo': 'Editá la secuencia hasta que el robot llegue a la estrella.'}, 'La secuencia original avanza sólo tres casillas; agregá un cuarto avance para llegar a la estrella.'),
    (8, 1, 'Construí la secuencia exacta: 10 instrucciones mínimas. Cada giro también cuenta.', {'tablero': {'dimensiones': 5, 'inicio': 10, 'rumbo': 2, 'meta': 8, 'muros': [12, 7, 17]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 12, 'objetivo': 'Llegá con precisión.', 'modo': 'normal', 'ejemplo': 'Bajá y hacé un rodeo por la izquierda.'}, 'La solución: avanzar, avanzar, girar izquierda, avanzar, avanzar, avanzar, girar izquierda, avanzar, avanzar y avanzar.'),
    (9, 1, 'Cinco obstáculos y sólo 12 instrucciones. Pensá, planificá y ejecutá.', {'tablero': {'dimensiones': 5, 'inicio': 13, 'rumbo': 1, 'meta': 10, 'muros': [11, 7, 2, 16, 6]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 12, 'objetivo': 'Resolvé el tablero con el menor número de instrucciones.', 'modo': 'normal', 'ejemplo': 'El centro está bloqueado; rodeá por abajo o por arriba.'}, 'La ruta mínima: girá a la derecha, avanzá, avanzá, girá a la izquierda, avanzá, avanzá, avanzá, girá a la derecha, avanzá y avanzá.'),

    (10, 1, 'Usá un bucle para repetir avances en vez de escribir varios en cadena.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 0, 'meta': 9, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 10, 'objetivo': 'Usá un bucle para repetir avances.', 'tutorial': 'tutorial-bucles', 'modo': 'normal', 'ejemplo': 'Repetir + Avanzar ejecuta tres avances de una sola vez.'}, 'Repetir seguido de Avanzar deja al robot exactamente en la estrella (24 → 19 → 14 → 9).'),
    (11, 1, 'Reemplazá una secuencia larga de avances por un solo bucle con número.', {'tablero': {'dimensiones': 5, 'inicio': 22, 'rumbo': 0, 'meta': 7, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 10, 'objetivo': 'Optimizá usando un bucle.', 'modo': 'normal', 'ejemplo': 'Repetir + Avanzar cubre los tres avances que necesitás.'}, 'Repetir seguido de Avanzar ejecuta los tres avances que hacen falta: 22 → 17 → 12 → 7.'),
    (12, 1, 'Tomá decisiones: mirá la orientación antes de definir tu giro.', {'tablero': {'dimensiones': 5, 'inicio': 19, 'rumbo': 1, 'meta': 23, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 10, 'objetivo': 'Tomá decisiones: mirá qué hay antes de girar.', 'tutorial': 'tutorial-decisiones', 'modo': 'normal', 'ejemplo': 'Como no hay condición si, mirar la orientación ya te dice qué giro conviene.'}, 'Girá a la derecha para bajar, avanzá una casilla, girá otra vez a la derecha y avanzá hasta la estrella.'),
    (13, 1, 'Si sucede esto, hacé esto otro: anticipate y corregí tu secuencia.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 3, 'meta': 0, 'muros': [22, 17, 12]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 15, 'objetivo': 'Si hay un obstáculo, girá y seguí.', 'modo': 'normal', 'ejemplo': 'El camino central está bloqueado; subí por la derecha y cruzá por arriba.'}, 'Girá a la derecha y subí por el costado derecho; después girá a la izquierda, cruzá la fila superior y entrá a la estrella.'),
    (14, 1, 'Desafío final: combiná todo lo que ya sabés en un solo recorrido.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 1, 'meta': 0, 'muros': [7, 12, 17]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 20, 'objetivo': 'Resolvé el tablero completo.', 'modo': 'normal', 'ejemplo': 'Combiná giros y bucles para evitar tres obstáculos.'}, 'El camino final combina giros y bucles para evitar los tres obstáculos.'),
]

UNIDADES = [
    ('40000000-0000-0000-0000-000000000001', 'Primer contacto', 'Conocé al robot, respondé a los obstáculos y alcanzá la estrella.', 1, 'publicado'),
    ('40000000-0000-0000-0000-000000000002', 'Pensar antes de actuar', 'Planeá recorridos, encontrando el atajo, rodeos y correcciones sin errores.', 2, 'bloqueada'),
    ('40000000-0000-0000-0000-000000000003', 'Nuevas formas de resolver', 'Repeticiones y tomas de decisiones para resolver desafíos reales.', 3, 'bloqueada'),
]

OUT = ['-- ===========================================================================\n-- 22. Curso Pensamiento Logico (actividades de tipo robot)\n-- ===========================================================================\n\n']
OUT.append("insert into cursos (id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion) values ('10000000-0000-0000-0000-000000000003', 'Pensamiento Lógico', 'Adquirí las habilidades de pensamiento computacional que todo programador necesita: secuencias ordenadas, descomposición de problemas, patrones y algoritmos simples.', 'Razoná antes de actuar', 'PL', 'pensarLogo', '#700b97', 3, 'publicado') on conflict (id) do nothing;")
for uid, nombre, descripcion, orden, estado in UNIDADES:
    OUT.append(f"insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('{uid}', '{curso_id}', '{nombre}', '{descripcion}', {orden}, '{estado}') on conflict (id) do nothing;")
for unidad_idx, lid, titulo, explicacion, ejemplo, orden, estado in lecciones:
    unidad_id = UNIDADES[unidad_idx - 1][0]
    texto = explicacion.replace("'", "''")
    ejemplo = ejemplo.replace("'", "''")
    OUT.append(f"insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('{lid}', '{unidad_id}', '{titulo}', '{texto}', '{ejemplo}', {orden}, '{estado}') on conflict (id) do nothing;")
for li, (li_idx, orden, enunciado, datos, explicacion) in enumerate(preguntas):
    leccion_id = lecciones[li_idx][1]
    pid = ASIGNAR_PID_LECCION[leccion_id]
    enc = enunciado.replace("'", "''")
    datos_json = json.dumps(datos, ensure_ascii=False).replace("'", "''")
    sol = json.dumps({'objetivo': datos.get('objetivo', '')}, ensure_ascii=False).replace("'", "''")
    explicacion_sql = explicacion.replace("'", "''")
    sol_id = str(uuid.UUID(bytes=hashlib.md5(f'sol:{pid}'.encode()).digest()))
    OUT.append(f"insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('{pid}', '{leccion_id}', '{enc}', 'robot', '{datos_json}'::jsonb, {orden}, 'publicado') on conflict (id) do nothing;")
    OUT.append(f"insert into soluciones (id, pregunta_id, solucion, explicacion) values ('{sol_id}', '{pid}', '{sol}'::jsonb, '{explicacion_sql}') on conflict (pregunta_id) do nothing;")

seed = '\n'.join(OUT) + '\n'
with open('_seed-robot-utf8.sql', 'w', encoding='utf-8', newline='\n') as f:
    f.write(seed)

# Migracion incremental para bases con el estado anterior: actualiza o inserta.
m = ['-- =====================================================================',
     '-- Actualizacion incremental: curso Pensamiento Logico (niveles ampliados)',
     '-- Idempotente: no duplica; actualiza titulos/textos/datos/soluciones.',
     '-- =====================================================================',
     '-- 1. Lecciones: contenido y publicacion (unidad 1-3 publicadas para',
     '--    que el desbloqueo por usuario las habilite)']
for unidad_idx, lid, titulo, explicacion, ejemplo, orden, estado in lecciones:
    texto = explicacion.replace("'", "''")
    ejemplo = ejemplo.replace("'", "''")
    m.append(f"insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('{lid}', '{UNIDADES[unidad_idx - 1][0]}', '{titulo}', '{texto}', '{ejemplo}', {orden}, '{estado}') on conflict (id) do update set titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion, unidad_id = excluded.unidad_id;")
m.append('\n-- 2. Preguntas robot: tableros actualizados (update) o nuevas (insert)')
for li, (li_idx, orden, enunciado, datos, explicacion) in enumerate(preguntas):
    leccion_id = lecciones[li_idx][1]
    pid = ASIGNAR_PID_LECCION[leccion_id]
    enc = enunciado.replace("'", "''")
    datos_json = json.dumps(datos, ensure_ascii=False).replace("'", "''")
    sol_id = str(uuid.UUID(bytes=hashlib.md5(f'sol:{pid}'.encode()).digest()))
    sol = json.dumps({'objetivo': datos.get('objetivo', '')}, ensure_ascii=False).replace("'", "''")
    explicacion_sql = explicacion.replace("'", "''")
    m.append(f"insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('{pid}', '{leccion_id}', '{enc}', 'robot', '{datos_json}'::jsonb, {orden}, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, datos = excluded.datos, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;")
    m.append(f"insert into soluciones (id, pregunta_id, solucion, explicacion) values ('{sol_id}', '{pid}', '{sol}'::jsonb, '{explicacion_sql}') on conflict (pregunta_id) do update set solucion = excluded.solucion, explicacion = excluded.explicacion;")
mig = '\n'.join(m) + '\n'
with open('_migracion-robot-v2.sql', 'w', encoding='utf-8', newline='\n') as f:
    f.write(mig)

print('seed:', len(OUT), 'sentencias/inserts; migracion v2:', len(m), 'lineas')
print('pid jefe ude2:', ASIGNAR_PID_LECCION['50000000-0000-0000-0000-00000000000f'])
