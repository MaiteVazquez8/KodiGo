-- =====================================================================
-- Migracion incremental: curso Pensamiento Logico + tipo de actividad robot
-- Idempotente: puede aplicarse mas de una vez sin duplicar datos.
-- =====================================================================

-- 1. constraint preguntas_tipo_check (ETAPA 8)
alter table preguntas drop constraint if exists preguntas_tipo_check;
alter table preguntas
add constraint preguntas_tipo_check check (tipo in (
    'seleccion',
    'verdadero_falso',
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
    'escribir_codigo',
    'corregir_codigo',
    'salida_codigo',
    'predecir',
    'bloques',
    'robot'
));

-- 2. comprobar_respuesta con soporte para la modalidad robot (repetir x3)
-- ---------------------------------------------------------------------------
-- 6. Correccion de las doce modalidades
-- ---------------------------------------------------------------------------

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

            else
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

-- Permisos de la sobrecarga jsonb recien creada.
revoke all on function comprobar_respuesta(uuid, jsonb) from public;


-- 3. validacion de la modalidad robot en el panel de administracion
create or replace function expotec_inconveniente_pregunta(p_pregunta_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_pregunta record;
    v_opciones integer;
    v_opciones_distintas integer;
    v_solucion record;
    v_total integer;
begin
    select * into v_pregunta
    from preguntas where id = p_pregunta_id;

    if v_pregunta.id is null then
        return 'La actividad no existe.';
    end if;
    if btrim(coalesce(v_pregunta.enunciado, '')) = '' then
        return 'La actividad necesita un enunciado';
    end if;

    select * into v_solucion
    from soluciones where pregunta_id = p_pregunta_id;

    if v_solucion.id is null then
        return 'La actividad necesita una solucion configurada';
    end if;
    if btrim(coalesce(v_solucion.explicacion, '')) = '' then
        return 'La actividad necesita una explicacion';
    end if;

    select
        count(*)::integer,
        count(distinct btrim(texto))::integer
    into v_opciones, v_opciones_distintas
    from opciones
    where pregunta_id = p_pregunta_id
      and btrim(texto) <> '';

    if v_pregunta.tipo in ('seleccion', 'verdadero_falso') then
        if v_opciones < 2 or v_opciones_distintas < 2 then
            return 'La actividad necesita al menos dos opciones distintas y sin texto vacio.';
        end if;
        if v_pregunta.tipo = 'verdadero_falso' and v_opciones <> 2 then
            return 'La actividad de verdadero o falso necesita exactamente dos opciones.';
        end if;
        if v_solucion.opcion_correcta_id is null or not exists (
            select 1 from opciones
            where id = v_solucion.opcion_correcta_id and pregunta_id = p_pregunta_id
        ) then
            return 'La actividad necesita marcar una opcion correcta.';
        end if;

    elsif v_pregunta.tipo = 'completar_texto' then
        if coalesce(v_pregunta.datos ->> 'valor', '') = ''
           and coalesce(v_solucion.solucion ->> 'valor', '') = ''
           and coalesce(jsonb_array_length(v_pregunta.datos -> 'alternativas'), 0) = 0
           and coalesce(jsonb_array_length(v_solucion.solucion -> 'alternativas'), 0) = 0 then
            return 'La actividad necesita un valor o alternativas para corregir.';
        end if;

    elsif v_pregunta.tipo = 'completar_codigo' then
        if coalesce(v_pregunta.datos ->> 'codigo', '') = '' then
            return 'La actividad necesita el codigo base.';
        end if;
        v_total := coalesce(jsonb_array_length(
            coalesce(nullif(v_solucion.solucion -> 'blancos', 'null'::jsonb), v_pregunta.datos -> 'blancos')
        ), 0);
        if v_total = 0 then
            return 'La actividad necesita al menos un blanco.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements(
                coalesce(nullif(v_solucion.solucion -> 'blancos', 'null'::jsonb), v_pregunta.datos -> 'blancos')
            ) b
            where b ->> 'clave' is null
              or btrim(coalesce(b ->> 'valor', '')) = ''
        ) then
            return 'Cada blanco necesita una respuesta valida.';
        end if;
        if (
            select count(distinct b ->> 'clave')
            from jsonb_array_elements(
                coalesce(nullif(v_solucion.solucion -> 'blancos', 'null'::jsonb), v_pregunta.datos -> 'blancos')
            ) b
        ) <> v_total then
            return 'Las claves de los blancos no pueden repetirse.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements(
                coalesce(nullif(v_solucion.solucion -> 'blancos', 'null'::jsonb), v_pregunta.datos -> 'blancos')
            ) b
            where position('{' || (b ->> 'clave') || '}' in coalesce(v_pregunta.datos ->> 'codigo', '')) = 0
        ) then
            return 'Cada blanco debe aparecer en el codigo como {clave}.';
        end if;

    elsif v_pregunta.tipo = 'ordenar' then
        if v_opciones < 2 then
            return 'La actividad necesita al menos dos elementos para ordenar.';
        end if;
        v_total := coalesce(jsonb_array_length(v_solucion.solucion -> 'orden'), 0);
        if v_total <> v_opciones then
            return 'La solucion de orden debe incluir todos los elementos.';
        end if;
        if jsonb_typeof(v_solucion.solucion -> 'orden') <> 'array' then
            return 'La solucion de orden debe ser una lista.';
        end if;
        if (select count(distinct value) from jsonb_array_elements_text(v_solucion.solucion -> 'orden')) <> v_total then
            return 'La solucion de orden no puede repetir elementos.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements_text(v_solucion.solucion -> 'orden') ids
            where not exists (
                select 1
                from opciones o
                where o.id::text = ids and o.pregunta_id = p_pregunta_id
            )
        ) then
            return 'La solucion de orden incluye elementos que no existen en la actividad.';
        end if;

    elsif v_pregunta.tipo = 'relacionar' then
        if coalesce(jsonb_array_length(v_pregunta.datos -> 'columna_a'), 0) = 0
           or coalesce(jsonb_array_length(v_pregunta.datos -> 'columna_b'), 0) = 0 then
            return 'La actividad necesita las dos columnas.';
        end if;
        if coalesce(jsonb_array_length(v_solucion.solucion -> 'pares'), 0) = 0 then
            return 'La actividad necesita al menos un par correcto.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements(v_solucion.solucion -> 'pares') par
            where not exists (
                select 1
                from jsonb_array_elements(v_pregunta.datos -> 'columna_a') a
                where a ->> 'id' = par ->> 'id_a'
            ) or not exists (
                select 1
                from jsonb_array_elements(v_pregunta.datos -> 'columna_b') b
                where b ->> 'id' = par ->> 'id_b'
            )
        ) then
            return 'Los pares de la solucion deben unir elementos de las dos columnas.';
        end if;
        if (
            select count(distinct par ->> 'id_a') + count(distinct par ->> 'id_b')
            from jsonb_array_elements(v_solucion.solucion -> 'pares') par
        ) <> 2 * jsonb_array_length(v_solucion.solucion -> 'pares') then
            return 'Cada elemento solo puede estar en un par.';
        end if;

    elsif v_pregunta.tipo in ('escribir_codigo', 'corregir_codigo') then
        if v_pregunta.tipo = 'corregir_codigo'
           and coalesce(v_pregunta.datos ->> 'codigo_inicial', '') = '' then
            return 'La actividad necesita el codigo con errores.';
        end if;
        if coalesce(jsonb_array_length(v_solucion.solucion -> 'soluciones'), 0) = 0
           and coalesce(jsonb_array_length(v_solucion.solucion -> 'requeridos'), 0) = 0 then
            return 'La actividad necesita soluciones aceptadas o criterios requeridos.';
        end if;
        -- Los patrones deben ser expresiones regulares validas: un patron
        -- invalido llegaria al corrector y fallaria en plena clase.
        declare
            v_patron text;
        begin
            for v_patron in
                select jsonb_array_elements_text(coalesce(v_solucion.solucion -> 'requeridos', '[]'::jsonb))
                union all
                select jsonb_array_elements_text(coalesce(v_solucion.solucion -> 'prohibidos', '[]'::jsonb))
            loop
                begin
                    perform 'kodigo' ~ v_patron;
                exception when others then
                    return 'Un patron de evaluacion no es una expresion regular valida: '
                        || left(v_patron, 40);
                end;
            end loop;
        end;

    elsif v_pregunta.tipo in ('salida_codigo', 'predecir') then
        if coalesce(v_pregunta.datos ->> 'codigo', '') = '' then
            return 'La actividad necesita el codigo a analizar.';
        end if;
        if coalesce(v_pregunta.datos ->> 'modo', 'texto') = 'opciones' then
            if v_opciones < 2 or v_opciones_distintas < 2 then
                return 'La actividad necesita al menos dos opciones distintas.';
            end if;
            if v_solucion.opcion_correcta_id is null or not exists (
                select 1
                from opciones
                where id = v_solucion.opcion_correcta_id
                  and pregunta_id = p_pregunta_id
            ) then
                return 'La actividad necesita marcar una opcion correcta.';
            end if;
        else
            if coalesce(v_solucion.solucion ->> 'valor', '') = ''
               and coalesce(jsonb_array_length(v_solucion.solucion -> 'alternativas'), 0) = 0 then
                return 'La actividad necesita un valor esperado o alternativas.';
            end if;
        end if;

    elsif v_pregunta.tipo = 'bloques' then
        if coalesce(jsonb_array_length(v_pregunta.datos -> 'bloques'), 0) < 2 then
            return 'La actividad necesita al menos dos bloques disponibles.';
        end if;
        v_total := coalesce(jsonb_array_length(v_solucion.solucion -> 'orden'), 0);
        if v_total < 1 then
            return 'La actividad necesita el orden correcto de los bloques.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements_text(v_solucion.solucion -> 'orden') ids
            where not exists (
                select 1
                from jsonb_array_elements(v_pregunta.datos -> 'bloques') b
                where b ->> 'id' = ids
            )
        ) then
            return 'El orden correcto incluye bloques que no estan disponibles.';
        end if;
        if (select count(distinct value) from jsonb_array_elements_text(v_solucion.solucion -> 'orden')) <> v_total then
            return 'La solucion no puede repetir bloques.';
        end if;
        if (select count(distinct b ->> 'id') from jsonb_array_elements(v_pregunta.datos -> 'bloques') b)
           <> jsonb_array_length(v_pregunta.datos -> 'bloques') then
            return 'Los ids de los bloques no pueden repetirse.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements(v_pregunta.datos -> 'bloques') b
            where btrim(coalesce(b ->> 'id', '')) = '' or btrim(coalesce(b ->> 'texto', '')) = ''
        ) then
            return 'Cada bloque necesita un id y un texto.';
        end if;

    elsif v_pregunta.tipo = 'robot' then
        if v_pregunta.datos -> 'tablero' is null then
            return 'La actividad robot necesita el tablero con inicio, meta y rumbo.';
        end if;
        if (v_pregunta.datos -> 'tablero' ->> 'inicio')::integer is null
           or (v_pregunta.datos -> 'tablero' ->> 'meta')::integer is null
           or (v_pregunta.datos -> 'tablero' ->> 'rumbo')::integer is null then
            return 'El tablero necesita inicio, meta y rumbo.';
        end if;
        if (v_pregunta.datos -> 'tablero' ->> 'inicio')::integer = (v_pregunta.datos -> 'tablero' ->> 'meta')::integer then
            return 'El punto de inicio y la meta no pueden coincidir.';
        end if;
        if exists (
            select 1
            from jsonb_array_elements(coalesce(v_pregunta.datos -> 'tablero' -> 'muros', '[]'::jsonb)) m
            where (m #>> '{}')::integer is null
               or (m #>> '{}')::integer < 0
               or (m #>> '{}')::integer > 24
        ) then
            return 'Los muros deben ser posiciones validas del tablero (0 a 24).';
        end if;
    end if;

    return null;
end;
$$;

revoke all on function expotec_inconveniente_pregunta(uuid) from public;

-- 4. seed: curso Pensamiento Logico (3 unidades, 14 lecciones, 14 actividades robot)
-- ===========================================================================
-- 22. Curso Pensamiento Logico (actividades de tipo robot)
-- ===========================================================================


-- ===========================================================================
-- 22. Curso Pensamiento Logico (actividades de tipo robot)
-- ===========================================================================

insert into cursos (id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion)
values
('10000000-0000-0000-0000-000000000003', 'Pensamiento Lógico', 'Adquirí las habilidades de pensamiento computacional que todo programador necesita: secuencias ordenadas, descomposición de problemas, patrones y algoritmos simples.', 'Razoná antes de actuar', 'PL', 'pensarLogo', '#700b97', 3, 'publicado')
on conflict (id) do nothing;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Primer contacto', 'Conocé al robot, respondé a los obstáculos y alcanzá la estrella.', 1, 'publicado') on conflict (id) do nothing;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', 'Pensar antes de actuar', 'Planeá recorridos, no te quedes atrapado y corregí algoritmos rotos.', 2, 'bloqueada') on conflict (id) do nothing;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Nuevas formas de resolver', 'Repeticiones y tomas de decisiones para resolver desafíos reales.', 3, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'Conocé al robot', 'El tablero es un 5 × 5. El robot empieza en la I y la estrella indica dónde debe llegar. Construí una secuencia y pulsa Ejecutar.', 'Avanzar mueve al robot una casilla hacia donde mira.', 1, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'Primer movimiento', 'Construí tu propio recorrido. Probá distintas secuencias y aprendé a ver el tablero antes de pulsar Ejecutar.', 'Cada avance y cada giro cuenta como una instrucción en la secuencia.', 2, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000001', 'Cambiá de dirección', 'Girá a la izquierda o a la derecha para cambiar la orientación sin moverte de la casilla.', 'Girar no te mueve, sólo cambia hacia dónde mirás.', 3, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000001', 'Tu primer recorrido', 'Combiná movimientos y giros para salir del inicio y llegar a la estrella.', 'Orientá el robot primero, después avanzá.', 4, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000001', 'Evitá los obstáculos', 'Las casillas con × son obstáculos que el robot no atravesará. Pensá cómo rodear el bloqueo y llegar a la meta.', 'Si un obstáculo te bloquea, girá hacia el espacio libre.', 5, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000006', '40000000-0000-0000-0000-000000000002', 'Planificá tu camino', 'Hay caminos válidos y caminos que te dejan atrapado. Mirá el tablero, identifica el obstáculo y elegí la ruta correcta.', 'Repasá el tablero antes de construir tu secuencia.', 1, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000007', '40000000-0000-0000-0000-000000000002', 'No todos los caminos sirven', 'Compará las posibles instrucciones y descartá las opciones que no llegan a la estrella.', 'Ninguna secuencia con un número impar de giros llega en pocos pasos.', 2, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000008', '40000000-0000-0000-0000-000000000002', 'Corregí el algoritmo', 'Este algoritmo probado está mal: arrancá con la secuencia dada, mirá por qué falla y corregilo para llegar a la estrella.', 'Una secuencia incorrecta se ve en el punto en que el robot choca o se desvía.', 3, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-000000000009', '40000000-0000-0000-0000-000000000002', 'Llegá con precisión', 'Construí exactamente la secuencia correcta. Cada giro y cada avance debe llevar al robot a la estrella paso a paso.', 'Sobrar giros o faltar avances rompe la ruta.', 4, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000003', 'Repetir instrucciones', 'Escribir una instrucción muchas veces es un trabajo aburrido; usá un bucle para repetir avances.', 'Un bucle de 4 avances ocupa 2 instrucciones, no 4.', 1, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-00000000000b', '40000000-0000-0000-0000-000000000003', 'Secuencias eficientes', 'Reemplazá una secuencia larga por un solo bucle. Cada bucle se ejecuta el número de veces indicado.', 'Cuatro avances equivalen a: bucle ×4 avances.', 2, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-00000000000c', '40000000-0000-0000-0000-000000000003', 'Tomar decisiones', 'Mirá la orientación del robot: aunque no entienda condiciones, podés decidir qué giro conviene según tu posición.', 'Mirando a la izquierda o a la derecha podés decidir el próximo giro.', 3, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-00000000000d', '40000000-0000-0000-0000-000000000003', 'Si sucede esto...', 'Antícipate: si un camino no está libre, girá antes de avanzar. Tu secuencia debe adaptarse al mapa.', 'Elegí qué instrucción agregar según la orientación.', 4, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values ('50000000-0000-0000-0000-00000000000e', '40000000-0000-0000-0000-000000000003', 'Desafío final', 'Combiná avances, giros y obstáculos para resolver el tablero completo con el menor número de instrucciones.', 'Cada instrucción importa. Optimizá, no recorras dos veces el mismo camino.', 5, 'bloqueada') on conflict (id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('5fe4d9b4-d9cf-8864-d9a9-6a0949750a00', '50000000-0000-0000-0000-000000000001', 'Recorre el tablero desde la I hasta la estrella usando solo giros y avances.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 0, "meta": 4, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Llegá a la estrella.", "tutorial": "tutorial-robot", "modo": "normal", "ejemplo": "Cuatro avances hacia arriba y después cuatro hacia la derecha."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('fb6c2c04-3a3c-3cfd-e755-677eab526d96', '5fe4d9b4-d9cf-8864-d9a9-6a0949750a00', '{"objetivo": "Llegá a la estrella."}'::jsonb, 'Cuatro avances hacia arriba, un giro a la derecha y cuatro avances alcanzan la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('55a41b1d-fdaa-9b02-5b91-cf6f749cd707', '50000000-0000-0000-0000-000000000002', 'Repetí el recorrido del primer nivel hasta llegar a la estrella.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 0, "meta": 4, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Construí tu propio recorrido.", "modo": "normal", "ejemplo": "Experimentá con la orientación antes de avanzar."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('bbde6619-f014-6993-a01d-302769ac4a83', '55a41b1d-fdaa-9b02-5b91-cf6f749cd707', '{"objetivo": "Construí tu propio recorrido."}'::jsonb, 'Un recorrido de 9 instrucciones alcanza la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('fb4ebd1c-4723-4baa-fe8c-d25bdb6554bc', '50000000-0000-0000-0000-000000000003', 'Practicá giros: girá a la izquierda para cambiar la orientación.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 1, "meta": 0, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Usá giros para cambiar la orientación del robot.", "tutorial": "tutorial-giros", "modo": "normal", "ejemplo": "Un giro a la izquierda deja al robot mirando hacia arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('c928c411-b8bf-69b4-a8ae-d2ffce890ca4', 'fb4ebd1c-4723-4baa-fe8c-d25bdb6554bc', '{"objetivo": "Usá giros para cambiar la orientación del robot."}'::jsonb, 'Un giro a la izquierda y cuatro avances te llevan a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('a6556a96-a6a0-8878-c6d0-583f40dc6a4b', '50000000-0000-0000-0000-000000000004', 'Combiná giros y avances para salir del punto I y llegar a la estrella.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 0, "meta": 4, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Alcanzá la estrella.", "modo": "normal", "ejemplo": "Orientá primero, después avanzá paso a paso."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('9c4c3db4-f456-8987-778d-871ff8d90968', 'a6556a96-a6a0-8878-c6d0-583f40dc6a4b', '{"objetivo": "Alcanzá la estrella."}'::jsonb, 'Cuatro avances, un giro derecha y cuatro avances alcanzan la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('74f851fb-8567-ac96-cd53-01d96d883425', '50000000-0000-0000-0000-000000000005', 'No atravesés los obstáculos (×). Buscá una ruta alternativa alrededor.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 22, "rumbo": 1, "meta": 4, "muros": [17, 19]}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Evitá los obstáculos.", "tutorial": "tutorial-obstaculos", "modo": "normal", "ejemplo": "Subí por la columna derecha y después cruzá por arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('8abb72ad-e263-4a86-77e5-24d67bf8308c', '74f851fb-8567-ac96-cd53-01d96d883425', '{"objetivo": "Evitá los obstáculos."}'::jsonb, 'Avanzá hasta 23, girá a la izquierda, subí por la columna y después girá a la derecha para entrar en la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('e36f60a9-6a34-8d26-6034-c95b3029ea3d', '50000000-0000-0000-0000-000000000006', 'Compará las opciones y elegí el camino más corto para llegar a la estrella.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 3, "meta": 0, "muros": [23, 18]}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 15, "objetivo": "Elegí la ruta correcta.", "modo": "normal", "ejemplo": "Caminos laterales: empieza por el centro o por el costado izquierdo."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('1272ae10-bcf5-1d38-c22b-98c5c41601fb', 'e36f60a9-6a34-8d26-6034-c95b3029ea3d', '{"objetivo": "Elegí la ruta correcta."}'::jsonb, 'El bloqueo en 23 y 18 fuerza otra ruta: girá a la derecha, subí por la columna derecha y cruzá la fila superior hacia la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('ef09b43d-fb5b-85a1-fdd2-de9e174b2b5d', '50000000-0000-0000-0000-000000000007', 'Elegí la ruta entre las posibles para llegar a la estrella.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 3, "meta": 0, "muros": [22, 17]}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 20, "objetivo": "Encontrá la ruta válida.", "modo": "normal", "ejemplo": "Otra ruta posible: girá izquierda, avanzá, girá derecha y seguí avanzando."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('c989aa42-4b25-f7ae-51ec-812f19cb254e', 'ef09b43d-fb5b-85a1-fdd2-de9e174b2b5d', '{"objetivo": "Encontrá la ruta válida."}'::jsonb, 'Avanzá hasta 23, girá a la derecha, subí por la columna derecha y cruzá hacia la estrella por la fila superior.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('1fd72277-543a-a0fb-fb97-1923b229c24b', '50000000-0000-0000-0000-000000000008', 'Este algoritmo está roto: no alcanza la estrella. Corregilo para que funcione.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 15, "rumbo": 1, "meta": 19, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Corregí el algoritmo defectuoso.", "modo": "corregir", "errores": ["Avanzar → Avanzar → Avanzar", "A la secuencia le falta un avance: el robot se detiene una casilla antes de la estrella."], "ejemplo": "Editá la secuencia hasta que el robot llegue a la estrella."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('467d463a-e7d7-b4af-b962-37e8d41bef36', '1fd72277-543a-a0fb-fb97-1923b229c24b', '{"objetivo": "Corregí el algoritmo defectuoso."}'::jsonb, 'La secuencia original avanza sólo tres casillas; agregá un cuarto avance para llegar a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('f670f5d2-7e64-ad42-e6e7-7af8f0c54619', '50000000-0000-0000-0000-000000000009', 'Construí exactamente la secuencia correcta. No sobran ni faltan giros o avances.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 3, "meta": 0, "muros": [19]}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 20, "objetivo": "Llegá con precisión.", "modo": "normal", "ejemplo": "Subí por el costado derecho y cruzá la fila superior."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('76e439d3-5806-7516-2e03-198a5bd32553', 'f670f5d2-7e64-ad42-e6e7-7af8f0c54619', '{"objetivo": "Llegá con precisión."}'::jsonb, 'Girá a la derecha, subí por la columna derecha y cruzá la fila superior hacia la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('acdb920b-7e50-965d-a0b3-b491a14acb33', '50000000-0000-0000-0000-00000000000a', 'Usá un bucle para repetir avances en vez de escribir varios en cadena.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 0, "meta": 9, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha", "repetir"], "maxInstrucciones": 10, "objetivo": "Usá un bucle para repetir avances.", "tutorial": "tutorial-bucles", "modo": "normal", "ejemplo": "Repetir + Avanzar ejecuta tres avances de una sola vez."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('4edbe5e4-43d3-bc80-0a20-e7434822f1cc', 'acdb920b-7e50-965d-a0b3-b491a14acb33', '{"objetivo": "Usá un bucle para repetir avances."}'::jsonb, 'Repetir seguido de Avanzar deja al robot exactamente en la estrella (24 → 19 → 14 → 9).') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('c1df8d57-3806-6140-2442-4927dfeb3710', '50000000-0000-0000-0000-00000000000b', 'Reemplazá una secuencia larga de avances por un solo bucle con número.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 22, "rumbo": 0, "meta": 7, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha", "repetir"], "maxInstrucciones": 10, "objetivo": "Optimizá usando un bucle.", "modo": "normal", "ejemplo": "Repetir + Avanzar cubre los tres avances que necesitás."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('64803df1-cab3-ca3d-1b4f-90d41bf77f90', 'c1df8d57-3806-6140-2442-4927dfeb3710', '{"objetivo": "Optimizá usando un bucle."}'::jsonb, 'Repetir seguido de Avanzar ejecuta los tres avances que hacen falta: 22 → 17 → 12 → 7.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('e00bbbb9-5c28-3998-0cf1-835fe4c84412', '50000000-0000-0000-0000-00000000000c', 'Tomá decisiones: mirá la orientación antes de definir tu giro.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 19, "rumbo": 1, "meta": 23, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha", "repetir"], "maxInstrucciones": 10, "objetivo": "Tomá decisiones: mirá qué hay antes de girar.", "tutorial": "tutorial-decisiones", "modo": "normal", "ejemplo": "Como no hay condición si, mirar la orientación ya te dice qué giro conviene."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('5c845949-ca2a-551b-9226-341db986e81d', 'e00bbbb9-5c28-3998-0cf1-835fe4c84412', '{"objetivo": "Tomá decisiones: mirá qué hay antes de girar."}'::jsonb, 'Girá a la derecha para bajar, avanzá una casilla, girá otra vez a la derecha y avanzá hasta la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('e4e9c827-7d64-9c8c-dd14-7acde3806ff6', '50000000-0000-0000-0000-00000000000d', 'Si sucede esto, hacé esto otro: anticipate y corregí tu secuencia.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 3, "meta": 0, "muros": [22, 17, 12]}, "instrucciones": ["avanzar", "izquierda", "derecha", "repetir"], "maxInstrucciones": 15, "objetivo": "Si hay un obstáculo, girá y seguí.", "modo": "normal", "ejemplo": "El camino central está bloqueado; subí por la derecha y cruzá por arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('a4ebc30d-7d29-3d50-d88d-a9ce1e48a7d2', 'e4e9c827-7d64-9c8c-dd14-7acde3806ff6', '{"objetivo": "Si hay un obstáculo, girá y seguí."}'::jsonb, 'Girá a la derecha y subí por el costado derecho; después girá a la izquierda, cruzá la fila superior y entrá a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
values ('b2085b3e-b6f0-b13e-7780-c864e30047dd', '50000000-0000-0000-0000-00000000000e', 'Desafío final: combiná todo lo que ya sabés en un solo recorrido.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 1, "meta": 0, "muros": [7, 12, 17]}, "instrucciones": ["avanzar", "izquierda", "derecha", "repetir"], "maxInstrucciones": 20, "objetivo": "Resolvé el tablero completo.", "modo": "normal", "ejemplo": "Combiná giros y bucles para evitar tres obstáculos."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion)
values ('98a53068-5404-393e-0a32-f45794f7309d', 'b2085b3e-b6f0-b13e-7780-c864e30047dd', '{"objetivo": "Resolvé el tablero completo."}'::jsonb, 'El camino final combina giros y bucles para evitar los tres obstáculos.') on conflict (pregunta_id) do nothing;