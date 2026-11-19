-- ===============================================================
-- Migracion robot-proc-loop: bucles de bloque (bucle2..bucle5) y
-- procedimientos (robotProc + llamar F) en comprobar_respuesta.
-- Idempotente: create or replace + updates por id.
-- ===============================================================

-- Helper: expande un programa de robot en una secuencia plana de instrucciones.
--   repetir  → la instrucción siguiente ×3
--   llamar   → el cuerpo completo del procedimiento F (una vez por llamada)
--   bucleN   → el bloque entre bucleN y 'fin', ejecutado N veces
--   fin      → cierra el bucle más interno (error si no hay bucle abierto)
create or replace function _robot_expandir_recursivo(
    p_tokens jsonb,
    p_proc jsonb,
    p_depth int
)
returns jsonb
language plpgsql
immutable
as $$
declare
    v_out jsonb := '[]'::jsonb;
    v_n integer;
    v_i integer := 0;
    v_inst text;
    v_count integer;
    v_ini integer;
    v_fin integer;
    v_balance integer;
    v_body jsonb;
    k integer;
begin
    if p_depth > 2 then
        raise exception 'Demasiado anidamiento en el programa';
    end if;

    if p_tokens is null or jsonb_typeof(p_tokens) <> 'array' then
        raise exception 'El programa debe ser un array de instrucciones';
    end if;

    v_n := jsonb_array_length(p_tokens);

    while v_i < v_n loop
        v_inst := p_tokens ->> v_i;

        if v_inst = 'repetir' then
            if v_i + 1 >= v_n then
                raise exception 'repetir sin instruccion siguiente';
            end if;
            v_out := v_out
                || jsonb_build_array(
                    p_tokens -> (v_i + 1),
                    p_tokens -> (v_i + 1),
                    p_tokens -> (v_i + 1)
                );
            v_i := v_i + 2;

        elsif v_inst = 'llamar' then
            if p_depth >= 1 then
                raise exception 'Los procedimientos no pueden llamar a otros procedimientos';
            end if;
            if p_proc is null or jsonb_array_length(p_proc) = 0 then
                raise exception 'llamar requiere un procedimiento F no vacio';
            end if;
            v_out := v_out || _robot_expandir_recursivo(p_proc, p_proc, p_depth + 1);
            v_i := v_i + 1;

        elsif v_inst ~ '^bucle[0-9]+$' then
            v_count := substring(v_inst from 6)::integer;
            if v_count < 2 or v_count > 5 then
                raise exception 'bucle debe indicar 2..5 repeticiones';
            end if;

            v_balance := 1;
            v_ini := v_i + 1;
            v_fin := null;
            for j in v_ini .. v_n - 1 loop
                if p_tokens ->> j ~ '^bucle[0-9]+$' then
                    v_balance := v_balance + 1;
                end if;
                if p_tokens ->> j = 'fin' then
                    v_balance := v_balance - 1;
                    if v_balance = 0 then
                        v_fin := j;
                        exit;
                    end if;
                end if;
            end loop;

            if v_fin is null then
                raise exception 'bucle sin fin correspondiente';
            end if;

            select coalesce(jsonb_agg(value), '[]'::jsonb)
            into v_body
            from jsonb_array_elements(p_tokens) with ordinality as t(value, n)
            where t.n >= v_i + 2 and t.n <= v_fin;

            for k in 1 .. v_count loop
                v_out := v_out || _robot_expandir_recursivo(v_body, p_proc, p_depth + 1);
            end loop;
            v_i := v_fin + 1;

        elsif v_inst = 'fin' then
            raise exception 'fin sin bucle que lo abra';

        else
            v_out := v_out || jsonb_build_array(v_inst);
            v_i := v_i + 1;
        end if;
    end loop;

    return v_out;
end;
$$;

create or replace function _robot_expandir(
    p_tokens jsonb,
    p_proc jsonb
)
returns jsonb
language plpgsql
immutable
as $$
begin
    return _robot_expandir_recursivo(
        p_tokens,
        coalesce(p_proc, '[]'::jsonb),
        0
    );
end;
$$;

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
    v_proc jsonb;
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
        v_proc := p_respuesta -> 'robotProc';

        if v_respuesta is null or jsonb_typeof(v_respuesta) <> 'array'
           or jsonb_array_length(v_respuesta) = 0 then
            raise exception 'La respuesta debe indicar las instrucciones del robot';
        end if;

        if jsonb_array_length(v_respuesta) > 30 then
            raise exception 'La secuencia supera el limite de 30 instrucciones';
        end if;

        if v_proc is not null then
            if jsonb_typeof(v_proc) <> 'array' then
                raise exception 'robotProc debe ser un array de instrucciones';
            end if;
            if jsonb_array_length(v_proc) > 12 then
                raise exception 'El procedimiento F supera las 12 instrucciones';
            end if;
            if jsonb_array_length(v_proc) > 0
               and v_proc::text ilike '%llamar%' then
                raise exception 'Los procedimientos no pueden llamar a otros procedimientos';
            end if;
        end if;

        v_pos := (v_datos -> 'tablero' ->> 'inicio')::integer;
        v_rumbo := (v_datos -> 'tablero' ->> 'rumbo')::integer;
        v_meta := (v_datos -> 'tablero' ->> 'meta')::integer;
        v_muros := v_datos -> 'tablero' -> 'muros';
        v_longitud := jsonb_array_length(v_respuesta);

        if v_pos is null or v_meta is null then
            raise exception 'El tablero del nivel no esta configurado';
        end if;

        -- Expandir: repetir ×3, llamar F y bucles de bloque (bucleN..fin).
        v_expanded := _robot_expandir(v_respuesta, v_proc);

        if jsonb_array_length(v_expanded) > 60 then
            raise exception 'La secuencia expandida supera las 60 instrucciones';
        end if;

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

-- Niveles que habilitan bucles y procedimiento F en el panel del juego.
-- Asignación directa del array completo: idempotente y segura sin importar el estado previo.
update preguntas
   set datos = jsonb_set(datos, '{instrucciones}',
       '["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"]'::jsonb,
       true)
 where id in (
     '74f851fb-8567-ac96-cd53-01d96d883425',  -- L5 Tres bloqueos
     'acdb920b-7e50-965d-a0b3-b491a14acb33',  -- L11 Repetir instrucciones
     'c1df8d57-3806-6140-2442-4927dfeb3710',  -- L12 Secuencias eficientes
     'e00bbbb9-5c28-3998-0cf1-835fe4c84412',  -- L13 Tomar decisiones
     'e4e9c827-7d64-9c8c-dd14-7acde3806ff6',  -- L14 Si sucede esto...
     'b2085b3e-b6f0-b13e-7780-c864e30047dd'   -- L15 Desafio final
 );
