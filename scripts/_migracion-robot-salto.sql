-- ===============================================================
-- Migracion robot-salto: agrega el comando saltar al curso
-- Pensamiento Logico (rama robot de comprobar_respuesta) y
-- habilita el salto en los niveles donde pedagogicamente agrega
-- valor. Idempotente (create or replace / updates sobre id).
-- ===============================================================

create or replace function comprobar_respuesta(
    p_pregunta_id uuid,
    p_respuesta jsonb
)
returns table (
    correcta boolean,
    explicacion text
)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_tipo varchar;
    v_datos jsonb;
    v_opcion_correcta uuid;
    v_solucion jsonb;
    v_explicacion text;
    v_respuesta jsonb;
    v_valor jsonb;
    v_correcta boolean := false;
    v_blanco jsonb;
    v_clave text;
    v_esperado text;
    v_estricto boolean;
    v_orden_esperada jsonb;
    v_orden_enviada jsonb;
    v_longitud integer;
    v_total_pares integer;
    v_codigo text;
    v_patron text;
    v_soluciones jsonb;
    v_requeridos jsonb;
    v_prohibidos jsonb;
    v_bloques jsonb;
    v_ids_conocidos integer;
    v_pos integer;
    v_rumbo integer;
    v_meta integer;
    v_muros jsonb;
    v_i integer;
    v_instr text;
    v_expanded jsonb;
    v_fila integer;
    v_columna integer;
    v_siguiente integer;
begin
    select p.tipo, p.datos, s.opcion_correcta_id, s.solucion, s.explicacion
    into v_tipo, v_datos, v_opcion_correcta, v_solucion, v_explicacion
    from preguntas p
    join soluciones s on s.pregunta_id = p.id
    where p.id = p_pregunta_id
      and p.estado_publicacion = 'publicado';

    if v_tipo is null then
        raise exception 'La pregunta no existe o no esta publicada';
    end if;

    if p_respuesta is null then
        return query select false, v_explicacion;
        return;
    end if;

    if jsonb_typeof(p_respuesta) <> 'object' then
        raise exception 'La respuesta debe ser un objeto JSON';
    end if;

    v_datos := coalesce(v_datos, '{}'::jsonb);
    v_solucion := coalesce(v_solucion, '{}'::jsonb);

    if v_tipo in ('seleccion', 'verdadero_falso') then
        v_valor := p_respuesta -> 'opcion_id';

        if v_valor is null then
            raise exception 'La respuesta debe indicar la opcion elegida';
        end if;

        if not exists (
            select 1 from opciones
            where id = (v_valor #>> '{}')::uuid
              and pregunta_id = p_pregunta_id
        ) then
            raise exception 'La opcion no pertenece a la pregunta';
        end if;

        v_correcta := v_opcion_correcta is not null
            and v_opcion_correcta = (v_valor #>> '{}')::uuid;

    elsif v_tipo = 'completar_texto' then
        v_valor := p_respuesta -> 'valor';

        if v_valor is null then
            raise exception 'La respuesta debe indicar el valor escrito';
        end if;

        v_estricto := coalesce(v_datos ->> 'estricta', 'false') = 'true';
        v_correcta := false;

        -- La respuesta vive en soluciones (protegida por RLS). El fallback a
        -- datos mantiene compatibles las actividades viejas del seed.
        if v_solucion ->> 'valor' is not null then
            v_correcta := texto_coincide_respuesta(
                v_valor #>> '{}', v_solucion ->> 'valor', v_estricto
            );
        elsif v_datos ->> 'valor' is not null then
            v_correcta := texto_coincide_respuesta(
                v_valor #>> '{}', v_datos ->> 'valor', v_estricto
            );
        end if;

        if not v_correcta then
            for v_esperado in select jsonb_array_elements_text(coalesce(v_solucion -> 'alternativas', '[]'::jsonb)) loop
                exit when v_correcta;
                v_correcta := texto_coincide_respuesta(v_valor #>> '{}', v_esperado, v_estricto);
            end loop;
        end if;

        if not v_correcta then
            for v_esperado in select jsonb_array_elements_text(coalesce(v_datos -> 'alternativas', '[]'::jsonb)) loop
                exit when v_correcta;
                v_correcta := texto_coincide_respuesta(v_valor #>> '{}', v_esperado, v_estricto);
            end loop;
        end if;

    elsif v_tipo = 'completar_codigo' then
        v_respuesta := p_respuesta -> 'blancos';

        if v_respuesta is null or jsonb_typeof(v_respuesta) <> 'object' then
            raise exception 'La respuesta debe indicar los valores de los blancos';
        end if;

        v_correcta := true;

        for v_blanco in select jsonb_array_elements(
            coalesce(nullif(v_solucion -> 'blancos', 'null'::jsonb), v_datos -> 'blancos', '[]'::jsonb)
        ) loop
            exit when not v_correcta;
            v_clave := v_blanco ->> 'clave';
            v_valor := v_respuesta -> v_clave;
            v_estricto := coalesce(v_blanco ->> 'estricta', 'true') = 'true';

            if v_valor is null or jsonb_typeof(v_valor) <> 'string' then
                v_correcta := false;
            else
                v_correcta := texto_coincide_respuesta(
                    v_valor #>> '{}', v_blanco ->> 'valor', v_estricto
                );
                if not v_correcta then
                    for v_esperado in select jsonb_array_elements_text(coalesce(v_blanco -> 'alternativas', '[]'::jsonb)) loop
                        exit when v_correcta;
                        v_correcta := texto_coincide_respuesta(v_valor #>> '{}', v_esperado, v_estricto);
                    end loop;
                end if;
            end if;
        end loop;

    elsif v_tipo = 'ordenar' then
        v_orden_esperada := v_solucion -> 'orden';
        v_orden_enviada := p_respuesta -> 'orden';

        if v_orden_esperada is null or v_orden_enviada is null
           or jsonb_typeof(v_orden_enviada) <> 'array'
        then
            raise exception 'La respuesta debe indicar el orden de los elementos';
        end if;

        v_longitud := jsonb_array_length(v_orden_esperada);
        v_correcta :=
            v_longitud = jsonb_array_length(v_orden_enviada)
            and v_orden_esperada = v_orden_enviada
            and (
                select count(*)
                from jsonb_array_elements_text(v_orden_enviada) ids
                join opciones o on o.id::text = ids and o.pregunta_id = p_pregunta_id
            ) = v_longitud;

    elsif v_tipo = 'relacionar' then
        v_respuesta := p_respuesta -> 'pares';

        if v_respuesta is null or jsonb_typeof(v_respuesta) <> 'array' then
            raise exception 'La respuesta debe indicar los pares unidos';
        end if;

        v_total_pares := jsonb_array_length(coalesce(v_solucion -> 'pares', '[]'::jsonb));

        v_correcta :=
            v_total_pares > 0
            and v_total_pares = jsonb_array_length(v_respuesta)
            and (select count(distinct value ->> 'id_a') from jsonb_array_elements(v_respuesta)) = v_total_pares
            and not exists (
                select 1
                from jsonb_array_elements(coalesce(v_solucion -> 'pares', '[]'::jsonb)) sp
                where not exists (
                    select 1
                    from jsonb_array_elements(v_respuesta) re
                    where re ->> 'id_a' = sp ->> 'id_a'
                      and re ->> 'id_b' = sp ->> 'id_b'
                )
            );

    elsif v_tipo in ('escribir_codigo', 'corregir_codigo') then
        v_valor := p_respuesta -> 'codigo';

        if v_valor is null or jsonb_typeof(v_valor) <> 'string' then
            raise exception 'La respuesta debe incluir el codigo escrito';
        end if;

        v_codigo := v_valor #>> '{}';
        v_estricto := coalesce(v_solucion ->> 'estricto', 'true') = 'true';
        v_soluciones := coalesce(v_solucion -> 'soluciones', '[]'::jsonb);
        v_requeridos := coalesce(v_solucion -> 'requeridos', '[]'::jsonb);
        v_prohibidos := coalesce(v_solucion -> 'prohibidos', '[]'::jsonb);

        if btrim(v_codigo) = '' then
            v_correcta := false;
        elsif jsonb_array_length(v_soluciones) > 0 then
            for v_esperado in select jsonb_array_elements_text(v_soluciones) loop
                exit when v_correcta;
                v_correcta := codigo_coincide_respuesta(v_codigo, v_esperado, v_estricto);
            end loop;
        else
            -- Sin soluciones exactas se evalua por criterios: todos los
            -- patrones requeridos presentes y ninguno de los prohibidos.
            v_correcta := jsonb_array_length(v_requeridos) > 0;
            if v_correcta then
                for v_patron in select jsonb_array_elements_text(v_requeridos) loop
                    exit when not v_correcta;
                    if v_codigo !~ v_patron then
                        v_correcta := false;
                    end if;
                end loop;
            end if;
            if v_correcta then
                for v_patron in select jsonb_array_elements_text(v_prohibidos) loop
                    exit when not v_correcta;
                    if v_codigo ~ v_patron then
                        v_correcta := false;
                    end if;
                end loop;
            end if;
        end if;

    elsif v_tipo in ('salida_codigo', 'predecir') then
        -- Variante con opciones: se reutiliza la tabla opciones.
        if p_respuesta ? 'opcion_id' then
            if jsonb_typeof(p_respuesta -> 'opcion_id') <> 'string' then
                raise exception 'La opcion elegida no es valida';
            end if;

            if not exists (
                select 1 from opciones
                where id = (p_respuesta ->> 'opcion_id')::uuid
                  and pregunta_id = p_pregunta_id
            ) then
                raise exception 'La opcion no pertenece a la pregunta';
            end if;

            v_correcta := v_opcion_correcta is not null
                and v_opcion_correcta = (p_respuesta ->> 'opcion_id')::uuid;

        -- Variante de texto: se compara contra la solucion y alternativas.
        elsif p_respuesta ? 'valor' then
            if jsonb_typeof(p_respuesta -> 'valor') <> 'string' then
                raise exception 'La respuesta escrita no es valida';
            end if;

            v_estricto := coalesce(v_solucion ->> 'estricta', 'false') = 'true';
            v_correcta := false;

            if v_solucion ->> 'valor' is not null then
                v_correcta := texto_coincide_respuesta(
                    p_respuesta ->> 'valor', v_solucion ->> 'valor', v_estricto
                );
            end if;

            if not v_correcta then
                for v_esperado in select jsonb_array_elements_text(coalesce(v_solucion -> 'alternativas', '[]'::jsonb)) loop
                    exit when v_correcta;
                    v_correcta := texto_coincide_respuesta(
                        p_respuesta ->> 'valor', v_esperado, v_estricto
                    );
                end loop;
            end if;
        else
            raise exception 'La respuesta debe indicar una opcion o un valor';
        end if;

    elsif v_tipo = 'bloques' then
        v_bloques := p_respuesta -> 'bloques';
        v_orden_esperada := v_solucion -> 'orden';

        if v_bloques is null or v_orden_esperada is null
           or jsonb_typeof(v_bloques) <> 'array'
        then
            raise exception 'La respuesta debe indicar los bloques elegidos';
        end if;

        v_longitud := jsonb_array_length(v_orden_esperada);

        select count(*)::integer into v_ids_conocidos
        from jsonb_array_elements_text(v_bloques) ids
        join jsonb_array_elements(coalesce(v_datos -> 'bloques', '[]'::jsonb)) b
          on b ->> 'id' = ids;

        v_correcta :=
            v_longitud = jsonb_array_length(v_bloques)
            and v_ids_conocidos = v_longitud
            and (select count(distinct value) from jsonb_array_elements_text(v_bloques)) = v_longitud
            and v_orden_esperada = v_bloques;

    elsif v_tipo = 'robot' then
        v_respuesta := p_respuesta -> 'robot';

        if v_respuesta is null or jsonb_typeof(v_respuesta) <> 'array'
           or jsonb_array_length(v_respuesta) = 0 then
            raise exception 'La respuesta debe indicar las instrucciones del robot';
        end if;

        if jsonb_array_length(v_respuesta) > 30 then
            raise exception 'La secuencia supera el limite de 30 instrucciones';
        end if;

        v_pos := (v_datos -> 'tablero' ->> 'inicio')::integer;
        v_rumbo := (v_datos -> 'tablero' ->> 'rumbo')::integer;
        v_meta := (v_datos -> 'tablero' ->> 'meta')::integer;
        v_muros := v_datos -> 'tablero' -> 'muros';
        v_longitud := jsonb_array_length(v_respuesta);

        if v_pos is null or v_meta is null then
            raise exception 'El tablero del nivel no esta configurado';
        end if;

        -- Expandir bucles: 'repetir' duplica la instruccion siguiente ×3.
        v_expanded := '[]'::jsonb;
        v_i := 0;
        while v_i < v_longitud loop
            v_instr := v_respuesta ->> v_i;
            if v_instr = 'repetir' and v_i + 1 < v_longitud then
                v_expanded := v_expanded || jsonb_build_array(v_respuesta -> (v_i + 1), v_respuesta -> (v_i + 1), v_respuesta -> (v_i + 1));
                v_i := v_i + 2;
            else
                v_expanded := v_expanded || jsonb_build_array(v_instr);
                v_i := v_i + 1;
            end if;
        end loop;

        v_correcta := false;
        for v_i in 0 .. jsonb_array_length(v_expanded) - 1 loop
            v_instr := v_expanded ->> v_i;

            if v_instr = 'izquierda' then
                v_rumbo := (v_rumbo + 3) % 4;

            elsif v_instr = 'derecha' then
                v_rumbo := (v_rumbo + 1) % 4;

            elsif v_instr = 'avanzar' then
                v_fila := floor(v_pos / 5) + case v_rumbo
                    when 0 then -1
                    when 1 then 0
                    when 2 then 1
                    else 0
                end;
                v_columna := mod(v_pos, 5) + case v_rumbo
                    when 0 then 0
                    when 1 then 1
                    when 2 then 0
                    else -1
                end;

                if v_fila < 0 or v_fila > 4 or v_columna < 0 or v_columna > 4 then
                    exit;
                end if;

                v_siguiente := v_fila * 5 + v_columna;

                if exists (
                    select 1
                    from jsonb_array_elements(coalesce(v_muros, '[]'::jsonb)) m
                    where (m #>> '{}')::integer = v_siguiente
                ) then
                    exit;
                end if;

                v_pos := v_siguiente;

            elsif v_instr = 'saltar' then
                -- A salta 2 casillas en la direccion a la que mira, pasando por encima
                -- de la casilla intermedia aunque sea un obstaculo; la casilla de
                -- aterrizaje debe estar libre y dentro del tablero.
                v_fila := floor(v_pos / 5) + 2 * case v_rumbo
                    when 0 then -1
                    when 1 then 0
                    when 2 then 1
                    else 0
                end;
                v_columna := mod(v_pos, 5) + 2 * case v_rumbo
                    when 0 then 0
                    when 1 then 1
                    when 2 then 0
                    else -1
                end;

                if v_fila < 0 or v_fila > 4 or v_columna < 0 or v_columna > 4 then
                    exit;
                end if;

                v_siguiente := v_fila * 5 + v_columna;

                if exists (
                    select 1
                    from jsonb_array_elements(coalesce(v_muros, '[]'::jsonb)) m
                    where (m #>> '{}')::integer = v_siguiente
                ) then
                    exit;
                end if;

                v_pos := v_siguiente;

            else
                raise exception 'Instruccion no reconocida: %', v_instr;
            end if;
                raise exception 'Instruccion no reconocida: %', v_instr;
            end if;
        end loop;

        v_correcta := v_pos = v_meta;

    else
        raise exception 'Tipo de actividad no reconocido: %', v_tipo;
    end if;

    return query select v_correcta, v_explicacion;
end;
$$;

update preguntas set
       enunciado = 'Un muro bloquea el camino. Usa el salto para superarlo y llegá a la estrella (dos casillas adelante).',
       datos = '{"tablero": {"dimensiones": 5, "inicio": 22, "rumbo": 0, "meta": 2, "muros": [12]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar"], "maxInstrucciones": 5, "objetivo": "Usa el salto para superar el obstáculo.", "tutorial": "tutorial-salto", "modo": "normal", "ejemplo": "Avanzá, saltá por encima del muro y seguí avanzando."}'::jsonb
     where id = 'a6556a96-a6a0-8878-c6d0-583f40dc6a4b';

update lecciones set
       titulo = 'El primer salto',
       explicacion = 'Habrá un bloqueo que jamás podrás rodear: la casilla siguiente está cerrada y no hay espacio de costado. El salto te lleva dos casillas adelante saltando por encima.',
       ejemplo_codigo = 'Salta el muro: Avanzar, Saltar, Avanzar.'
     where id = '50000000-0000-0000-0000-000000000004';

update preguntas
       set datos = jsonb_set(
           jsonb_set(datos, '{instrucciones}', '["avanzar", "izquierda", "derecha", "saltar"]'::jsonb, true),
           '{ejemplo}', '"El salto puede ahorrarte un rodeo entero: miraló desde arriba."')
       where id = 'e36f60a9-6a34-8d26-6034-c95b3029ea3d';

update preguntas
       set datos = jsonb_set(
           jsonb_set(datos, '{instrucciones}', '["avanzar", "izquierda", "derecha", "saltar"]'::jsonb, true),
           '{ejemplo}', '"Si el camino está cerrado, saltá por encima."')
       where id = 'ef09b43d-fb5b-85a1-fdd2-de9e174b2b5d';

update preguntas
       set datos = jsonb_set(
           jsonb_set(datos, '{instrucciones}', '["avanzar", "izquierda", "derecha", "saltar"]'::jsonb, true),
           '{ejemplo}', '"El centro está bloqueado: saltá un muro clave o rodeá por abajo o por arriba."')
       where id = 'b1de3c13-55b4-d8f8-873a-9dac4f97a487';

update preguntas
       set datos = jsonb_set(
           jsonb_set(datos, '{instrucciones}', '["avanzar", "izquierda", "derecha", "saltar", "repetir"]'::jsonb, true),
           '{ejemplo}', '"El camino central está bloqueado; saltá o subí por la derecha y cruzá por arriba."')
       where id = 'e4e9c827-7d64-9c8c-dd14-7acde3806ff6';

update preguntas
       set datos = jsonb_set(
           jsonb_set(datos, '{instrucciones}', '["avanzar", "izquierda", "derecha", "saltar", "repetir"]'::jsonb, true),
           '{ejemplo}', '"Combiná giros, bucles y saltos para superar los tres obstáculos."')
       where id = 'b2085b3e-b6f0-b13e-7780-c864e30047dd';

