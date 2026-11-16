import hashlib
import json
import uuid

curso_id = '10000000-0000-0000-0000-000000000003'

unidades = [
    ('40000000-0000-0000-0000-000000000001', 'Primer contacto', 'Conocé al robot, respondé a los obstáculos y alcanzá la estrella.', 1, 'publicado'),
    ('40000000-0000-0000-0000-000000000002', 'Pensar antes de actuar', 'Planeá recorridos, no te quedes atrapado y corregí algoritmos rotos.', 2, 'bloqueada'),
    ('40000000-0000-0000-0000-000000000003', 'Nuevas formas de resolver', 'Repeticiones y tomas de decisiones para resolver desafíos reales.', 3, 'bloqueada'),
]

lecciones = [
    (1, '50000000-0000-0000-0000-000000000001', 'Conocé al robot', 'El tablero es un 5 × 5. El robot empieza en la I y la estrella indica dónde debe llegar. Construí una secuencia y pulsa Ejecutar.', 'Avanzar mueve al robot una casilla hacia donde mira.', 1, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000002', 'Primer movimiento', 'Construí tu propio recorrido. Probá distintas secuencias y aprendé a ver el tablero antes de pulsar Ejecutar.', 'Cada avance y cada giro cuenta como una instrucción en la secuencia.', 2, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000003', 'Cambiá de dirección', 'Girá a la izquierda o a la derecha para cambiar la orientación sin moverte de la casilla.', 'Girar no te mueve, sólo cambia hacia dónde mirás.', 3, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000004', 'Tu primer recorrido', 'Combiná movimientos y giros para salir del inicio y llegar a la estrella.', 'Orientá el robot primero, después avanzá.', 4, 'publicado'),
    (1, '50000000-0000-0000-0000-000000000005', 'Evitá los obstáculos', 'Las casillas con × son obstáculos que el robot no atravesará. Pensá cómo rodear el bloqueo y llegar a la meta.', 'Si un obstáculo te bloquea, girá hacia el espacio libre.', 5, 'publicado'),

    (2, '50000000-0000-0000-0000-000000000006', 'Planificá tu camino', 'Hay caminos válidos y caminos que te dejan atrapado. Mirá el tablero, identifica el obstáculo y elegí la ruta correcta.', 'Repasá el tablero antes de construir tu secuencia.', 1, 'bloqueada'),
    (2, '50000000-0000-0000-0000-000000000007', 'No todos los caminos sirven', 'Compará las posibles instrucciones y descartá las opciones que no llegan a la estrella.', 'Ninguna secuencia con un número impar de giros llega en pocos pasos.', 2, 'bloqueada'),
    (2, '50000000-0000-0000-0000-000000000008', 'Corregí el algoritmo', 'Este algoritmo probado está mal: arrancá con la secuencia dada, mirá por qué falla y corregilo para llegar a la estrella.', 'Una secuencia incorrecta se ve en el punto en que el robot choca o se desvía.', 3, 'bloqueada'),
    (2, '50000000-0000-0000-0000-000000000009', 'Llegá con precisión', 'Construí exactamente la secuencia correcta. Cada giro y cada avance debe llevar al robot a la estrella paso a paso.', 'Sobrar giros o faltar avances rompe la ruta.', 4, 'bloqueada'),

    (3, '50000000-0000-0000-0000-00000000000a', 'Repetir instrucciones', 'Escribir una instrucción muchas veces es un trabajo aburrido; usá un bucle para repetir avances.', 'Un bucle de 4 avances ocupa 2 instrucciones, no 4.', 1, 'bloqueada'),
    (3, '50000000-0000-0000-0000-00000000000b', 'Secuencias eficientes', 'Reemplazá una secuencia larga por un solo bucle. Cada bucle se ejecuta el número de veces indicado.', 'Cuatro avances equivalen a: bucle ×4 avances.', 2, 'bloqueada'),
    (3, '50000000-0000-0000-0000-00000000000c', 'Tomar decisiones', 'Mirá la orientación del robot: aunque no entienda condiciones, podés decidir qué giro conviene según tu posición.', 'Mirando a la izquierda o a la derecha podés decidir el próximo giro.', 3, 'bloqueada'),
    (3, '50000000-0000-0000-0000-00000000000d', 'Si sucede esto...', 'Antícipate: si un camino no está libre, girá antes de avanzar. Tu secuencia debe adaptarse al mapa.', 'Elegí qué instrucción agregar según la orientación.', 4, 'bloqueada'),
    (3, '50000000-0000-0000-0000-00000000000e', 'Desafío final', 'Combiná avances, giros y obstáculos para resolver el tablero completo con el menor número de instrucciones.', 'Cada instrucción importa. Optimizá, no recorras dos veces el mismo camino.', 5, 'bloqueada'),
]

preguntas = [
    (0, 1, 'Recorre el tablero desde la I hasta la estrella usando solo giros y avances.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 0, 'meta': 4, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Llegá a la estrella.', 'tutorial': 'tutorial-robot', 'modo': 'normal', 'ejemplo': 'Cuatro avances hacia arriba y después cuatro hacia la derecha.'}, 'Cuatro avances hacia arriba, un giro a la derecha y cuatro avances alcanzan la estrella.'),
    (1, 1, 'Repetí el recorrido del primer nivel hasta llegar a la estrella.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 0, 'meta': 4, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Construí tu propio recorrido.', 'modo': 'normal', 'ejemplo': 'Experimentá con la orientación antes de avanzar.'}, 'Un recorrido de 9 instrucciones alcanza la estrella.'),
    (2, 1, 'Practicá giros: girá a la izquierda para cambiar la orientación.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 1, 'meta': 0, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Usá giros para cambiar la orientación del robot.', 'tutorial': 'tutorial-giros', 'modo': 'normal', 'ejemplo': 'Un giro a la izquierda deja al robot mirando hacia arriba.'}, 'Un giro a la izquierda y cuatro avances te llevan a la estrella.'),
    (3, 1, 'Combiná giros y avances para salir del punto I y llegar a la estrella.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 0, 'meta': 4, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Alcanzá la estrella.', 'modo': 'normal', 'ejemplo': 'Orientá primero, después avanzá paso a paso.'}, 'Cuatro avances, un giro derecha y cuatro avances alcanzan la estrella.'),
    (4, 1, 'No atravesés los obstáculos (×). Buscá una ruta alternativa alrededor.', {'tablero': {'dimensiones': 5, 'inicio': 22, 'rumbo': 1, 'meta': 4, 'muros': [17, 19]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Evitá los obstáculos.', 'tutorial': 'tutorial-obstaculos', 'modo': 'normal', 'ejemplo': 'Subí por la columna derecha y después cruzá por arriba.'}, 'Avanzá hasta 23, girá a la izquierda, subí por la columna y después girá a la derecha para entrar en la estrella.'),

    (5, 1, 'Compará las opciones y elegí el camino más corto para llegar a la estrella.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 3, 'meta': 0, 'muros': [23, 18]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 15, 'objetivo': 'Elegí la ruta correcta.', 'modo': 'normal', 'ejemplo': 'Caminos laterales: empieza por el centro o por el costado izquierdo.'}, 'El bloqueo en 23 y 18 fuerza otra ruta: girá a la derecha, subí por la columna derecha y cruzá la fila superior hacia la estrella.'),
    (6, 1, 'Elegí la ruta entre las posibles para llegar a la estrella.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 3, 'meta': 0, 'muros': [22, 17]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 20, 'objetivo': 'Encontrá la ruta válida.', 'modo': 'normal', 'ejemplo': 'Otra ruta posible: girá izquierda, avanzá, girá derecha y seguí avanzando.'}, 'Avanzá hasta 23, girá a la derecha, subí por la columna derecha y cruzá hacia la estrella por la fila superior.'),
    (7, 1, 'Este algoritmo está roto: no alcanza la estrella. Corregilo para que funcione.', {'tablero': {'dimensiones': 5, 'inicio': 15, 'rumbo': 1, 'meta': 19, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 30, 'objetivo': 'Corregí el algoritmo defectuoso.', 'modo': 'corregir', 'errores': ['Avanzar → Avanzar → Avanzar', 'A la secuencia le falta un avance: el robot se detiene una casilla antes de la estrella.'], 'ejemplo': 'Editá la secuencia hasta que el robot llegue a la estrella.'}, 'La secuencia original avanza sólo tres casillas; agregá un cuarto avance para llegar a la estrella.'),
    (8, 1, 'Construí exactamente la secuencia correcta. No sobran ni faltan giros o avances.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 3, 'meta': 0, 'muros': [19]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha'], 'maxInstrucciones': 20, 'objetivo': 'Llegá con precisión.', 'modo': 'normal', 'ejemplo': 'Subí por el costado derecho y cruzá la fila superior.'}, 'Girá a la derecha, subí por la columna derecha y cruzá la fila superior hacia la estrella.'),

    (9, 1, 'Usá un bucle para repetir avances en vez de escribir varios en cadena.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 0, 'meta': 9, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 10, 'objetivo': 'Usá un bucle para repetir avances.', 'tutorial': 'tutorial-bucles', 'modo': 'normal', 'ejemplo': 'Repetir + Avanzar ejecuta tres avances de una sola vez.'}, 'Repetir seguido de Avanzar deja al robot exactamente en la estrella (24 → 19 → 14 → 9).'),
    (10, 1, 'Reemplazá una secuencia larga de avances por un solo bucle con número.', {'tablero': {'dimensiones': 5, 'inicio': 22, 'rumbo': 0, 'meta': 7, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 10, 'objetivo': 'Optimizá usando un bucle.', 'modo': 'normal', 'ejemplo': 'Repetir + Avanzar cubre los tres avances que necesitás.'}, 'Repetir seguido de Avanzar ejecuta los tres avances que hacen falta: 22 → 17 → 12 → 7.'),
    (11, 1, 'Tomá decisiones: mirá la orientación antes de definir tu giro.', {'tablero': {'dimensiones': 5, 'inicio': 19, 'rumbo': 1, 'meta': 23, 'muros': []}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 10, 'objetivo': 'Tomá decisiones: mirá qué hay antes de girar.', 'tutorial': 'tutorial-decisiones', 'modo': 'normal', 'ejemplo': 'Como no hay condición si, mirar la orientación ya te dice qué giro conviene.'}, 'Girá a la derecha para bajar, avanzá una casilla, girá otra vez a la derecha y avanzá hasta la estrella.'),
    (12, 1, 'Si sucede esto, hacé esto otro: anticipate y corregí tu secuencia.', {'tablero': {'dimensiones': 5, 'inicio': 24, 'rumbo': 3, 'meta': 0, 'muros': [22, 17, 12]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 15, 'objetivo': 'Si hay un obstáculo, girá y seguí.', 'modo': 'normal', 'ejemplo': 'El camino central está bloqueado; subí por la derecha y cruzá por arriba.'}, 'Girá a la derecha y subí por el costado derecho; después girá a la izquierda, cruzá la fila superior y entrá a la estrella.'),
    (13, 1, 'Desafío final: combiná todo lo que ya sabés en un solo recorrido.', {'tablero': {'dimensiones': 5, 'inicio': 20, 'rumbo': 1, 'meta': 0, 'muros': [7, 12, 17]}, 'instrucciones': ['avanzar', 'izquierda', 'derecha', 'repetir'], 'maxInstrucciones': 20, 'objetivo': 'Resolvé el tablero completo.', 'modo': 'normal', 'ejemplo': 'Combiná giros y bucles para evitar tres obstáculos.'}, 'El camino final combina giros y bucles para evitar los tres obstáculos.'),
]


def md5_uuid(s):
    return str(uuid.UUID(bytes=hashlib.md5(s.encode()).digest()))


out = []
out.append("insert into cursos (id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion)")
out.append("values")
out.append(f"('{curso_id}', 'Pensamiento Lógico', 'Adquirí las habilidades de pensamiento computacional que todo programador necesita: secuencias ordenadas, descomposición de problemas, patrones y algoritmos simples.', 'Razoná antes de actuar', 'PL', 'pensarLogo', '#700b97', 3, 'publicado')")
out.append("on conflict (id) do nothing;")

for uid, nombre, descripcion, orden, estado in unidades:
    out.append("insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)")
    out.append(f"values ('{uid}', '{curso_id}', '{nombre}', '{descripcion}', {orden}, '{estado}') on conflict (id) do nothing;")

for unidad_idx, lid, titulo, explicacion, ejemplo, orden, estado in lecciones:
    unidad_id = unidades[unidad_idx - 1][0]
    texto = explicacion.replace("'", "''")
    ejemplo = ejemplo.replace("'", "''")
    out.append("insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)")
    out.append(f"values ('{lid}', '{unidad_id}', '{titulo}', '{texto}', '{ejemplo}', {orden}, '{estado}') on conflict (id) do nothing;")

for li, (li_idx, orden, enunciado, datos, explicacion) in enumerate(preguntas):
    pid = md5_uuid(f'kodigo:robot:{li_idx+1}:{orden}')
    enc = enunciado.replace("'", "''")
    datos_json = json.dumps(datos, ensure_ascii=False).replace("'", "''")
    comentario_solucion = explicacion.replace("'", "''")
    sol = json.dumps({'objetivo': datos.get('objetivo', '')}, ensure_ascii=False).replace("'", "''")
    out.append("insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)")
    out.append(f"values ('{pid}', '{lecciones[li_idx][1]}', '{enc}', 'robot', '{datos_json}'::jsonb, {orden}, 'publicado') on conflict (id) do nothing;")
    out.append("insert into soluciones (id, pregunta_id, solucion, explicacion)")
    sol_id = md5_uuid(f'sol:{pid}')
    out.append(f"values ('{sol_id}', '{pid}', '{sol}'::jsonb, '{comentario_solucion}') on conflict (pregunta_id) do nothing;")

with open('_seed-robot-utf8.sql', 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(out))
print('seed escrito: _seed-robot-utf8.sql (', len(out), 'bloques )')
