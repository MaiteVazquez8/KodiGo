-- Patch v3-1: corregir la respuesta de la pregunta "¿Qué imprime este código? console.log("JavaScri".length);"
-- La respuesta correcta es 8 ("JavaScri" son 8 caracteres: J-a-v-a-S-c-r-i).
-- Idempotente.

update soluciones
set opcion_correcta_id = '151b9de1-4886-0c64-4b51-311035206798',
    explicacion = '"JavaScri" son 8 caracteres (J-a-v-a-S-c-r-i).'
where id = '8adc4abe-e87c-1285-63cc-1481428c088f';

-- Verificación: debe devolver la opción '8' en texto y la explicación corregida.
select s.id as sol_id, o.texto as opcion_correcta, s.explicacion, p.enunciado
from soluciones s
join preguntas p on p.id = s.pregunta_id
join opciones o on o.id = s.opcion_correcta_id
where s.pregunta_id = 'ebc59715-3e88-f344-9352-5651bae7c6f3';
