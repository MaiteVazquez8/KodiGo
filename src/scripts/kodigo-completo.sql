create extension if not exists pgcrypto;

create table if not exists cursos (
    id uuid primary key default gen_random_uuid(),
    nombre varchar(100) not null,
    descripcion text,
    lema varchar(160),
    monograma varchar(10),
    logo varchar(60),
    color_acento varchar(20) default '#8e05c2',
    imagen_url text,
    orden integer not null default 0,
    estado_publicacion varchar(20) not null default 'borrador',
    created_at timestamptz not null default now(),
    constraint cursos_estado_check check (estado_publicacion in ('borrador', 'publicado', 'oculto')),
    constraint cursos_orden_check check (orden >= 0)
);

create table if not exists unidades (
    id uuid primary key default gen_random_uuid(),
    curso_id uuid not null references cursos(id) on delete cascade,
    nombre varchar(100) not null,
    descripcion text,
    orden integer not null default 0,
    estado_publicacion varchar(20) not null default 'bloqueada',
    created_at timestamptz not null default now(),
    constraint unidades_estado_check check (estado_publicacion in ('borrador', 'publicado', 'bloqueada', 'oculta')),
    constraint unidades_orden_check check (orden >= 0),
    constraint unidades_curso_orden_unique unique (curso_id, orden)
);

create table if not exists lecciones (
    id uuid primary key default gen_random_uuid(),
    unidad_id uuid not null references unidades(id) on delete cascade,
    titulo varchar(150) not null,
    explicacion text not null,
    ejemplo_codigo text,
    orden integer not null default 0,
    estado_publicacion varchar(20) not null default 'borrador',
    created_at timestamptz not null default now(),
    constraint lecciones_estado_check check (estado_publicacion in ('borrador', 'publicado', 'bloqueada', 'oculta')),
    constraint lecciones_orden_check check (orden >= 0),
    constraint lecciones_unidad_orden_unique unique (unidad_id, orden)
);

create table if not exists preguntas (
    id uuid primary key default gen_random_uuid(),
    leccion_id uuid not null references lecciones(id) on delete cascade,
    enunciado text not null,
    tipo varchar(30) not null default 'seleccion',
    datos jsonb,
    orden integer not null default 0,
    estado_publicacion varchar(20) not null default 'borrador',
    created_at timestamptz not null default now(),
    constraint preguntas_tipo_check check (tipo in (
        'seleccion',
        'verdadero_falso',
        'completar_texto',
        'completar_codigo',
        'ordenar',
        'relacionar'
    )),
    constraint preguntas_estado_check check (estado_publicacion in ('borrador', 'publicado', 'oculta')),
    constraint preguntas_orden_check check (orden >= 0),
    constraint preguntas_leccion_orden_unique unique (leccion_id, orden)
);

create table if not exists opciones (
    id uuid primary key default gen_random_uuid(),
    pregunta_id uuid not null references preguntas(id) on delete cascade,
    texto text not null,
    orden integer not null default 0,
    created_at timestamptz not null default now(),
    constraint opciones_orden_check check (orden >= 0),
    constraint opciones_pregunta_orden_unique unique (pregunta_id, orden)
);

create table if not exists soluciones (
    id uuid primary key default gen_random_uuid(),
    pregunta_id uuid not null unique references preguntas(id) on delete cascade,
    opcion_correcta_id uuid references opciones(id) on delete restrict,
    solucion jsonb,
    explicacion text not null,
    created_at timestamptz not null default now(),
    constraint soluciones_origen_check check (opcion_correcta_id is not null or solucion is not null)
);

create table if not exists perfiles (
    id uuid primary key references auth.users(id) on delete cascade,
    nombre_usuario varchar(50) not null unique,
    nombre_visible varchar(100),
    avatar_url text,
    nivel integer not null default 1,
    experiencia integer not null default 0,
    racha_dias integer not null default 0,
    racha_respuestas integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint perfiles_nivel_check check (nivel >= 1),
    constraint perfiles_experiencia_check check (experiencia >= 0),
    constraint perfiles_racha_dias_check check (racha_dias >= 0),
    constraint perfiles_racha_respuestas_check check (racha_respuestas >= 0)
);

create table if not exists progreso_lecciones (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references perfiles(id) on delete cascade,
    leccion_id uuid not null references lecciones(id) on delete cascade,
    completada boolean not null default false,
    aprobada boolean not null default false,
    intentos integer not null default 0,
    mejor_porcentaje numeric(5,2) not null default 0,
    ultimo_porcentaje numeric(5,2) not null default 0,
    ultimo_intento_id uuid,
    aprobado_en timestamptz,
    updated_at timestamptz not null default now(),
    constraint progreso_usuario_leccion_unique unique (usuario_id, leccion_id),
    constraint progreso_intentos_check check (intentos >= 0),
    constraint progreso_mejor_porcentaje_check check (mejor_porcentaje >= 0 and mejor_porcentaje <= 100),
    constraint progreso_ultimo_porcentaje_check check (ultimo_porcentaje >= 0 and ultimo_porcentaje <= 100)
);

create table if not exists intentos (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references perfiles(id) on delete cascade,
    leccion_id uuid not null references lecciones(id) on delete cascade,
    clave_idempotencia uuid not null,
    estado varchar(20) not null default 'en_curso',
    iniciado_at timestamptz not null default now(),
    finalizado_at timestamptz,
    cantidad_preguntas integer not null default 0,
    respuestas_correctas integer not null default 0,
    respuestas_incorrectas integer not null default 0,
    porcentaje numeric(5,2) not null default 0,
    completado boolean not null default false,
    aprobado boolean not null default false,
    xp_ganado integer not null default 0,
    created_at timestamptz not null default now(),
    constraint intentos_clave_unica unique (usuario_id, clave_idempotencia),
    constraint intentos_estado_check check (estado in ('en_curso', 'completado', 'abandonado')),
    constraint intentos_cantidad_check check (cantidad_preguntas >= 0),
    constraint intentos_correctas_check check (respuestas_correctas >= 0),
    constraint intentos_incorrectas_check check (respuestas_incorrectas >= 0),
    constraint intentos_porcentaje_check check (porcentaje >= 0 and porcentaje <= 100),
    constraint intentos_cerrado_check check (
        (estado = 'en_curso' and finalizado_at is null)
        or (estado <> 'en_curso' and finalizado_at is not null)
    )
);

-- La FK de progreso_lecciones se agrega aca porque intentos se define despues.
do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'progreso_lecciones_ultimo_intento_fkey'
    ) then
        alter table progreso_lecciones
        add constraint progreso_lecciones_ultimo_intento_fkey
        foreign key (ultimo_intento_id) references intentos(id) on delete set null;
    end if;
end;
$$;

create table if not exists respuestas_intento (
    id uuid primary key default gen_random_uuid(),
    intento_id uuid not null references intentos(id) on delete cascade,
    pregunta_id uuid not null references preguntas(id) on delete cascade,
    opcion_id uuid references opciones(id) on delete restrict,
    respuesta jsonb,
    correcta boolean not null,
    created_at timestamptz not null default now(),
    constraint respuestas_intento_pregunta_unique unique (intento_id, pregunta_id),
    constraint respuestas_intento_origen_check check (opcion_id is not null or respuesta is not null)
);

create table if not exists amistades (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references perfiles(id) on delete cascade,
    amigo_id uuid not null references perfiles(id) on delete cascade,
    estado varchar(20) not null default 'pendiente',
    created_at timestamptz not null default now(),
    constraint amistades_estado_check check (estado in ('pendiente', 'aceptada', 'rechazada', 'bloqueada')),
    constraint amistades_usuarios_diferentes check (usuario_id <> amigo_id),
    constraint amistades_unique unique (usuario_id, amigo_id)
);

create table if not exists logros (
    id uuid primary key default gen_random_uuid(),
    nombre varchar(100) not null unique,
    descripcion text not null,
    icono_url text,
    experiencia_recompensa integer not null default 0,
    created_at timestamptz not null default now(),
    constraint logros_experiencia_check check (experiencia_recompensa >= 0)
);

create table if not exists logros_usuario (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references perfiles(id) on delete cascade,
    logro_id uuid not null references logros(id) on delete cascade,
    obtenido_at timestamptz not null default now(),
    constraint logros_usuario_unique unique (usuario_id, logro_id)
);

create index if not exists idx_unidades_curso on unidades(curso_id, orden);
create index if not exists idx_lecciones_unidad on lecciones(unidad_id, orden);
create index if not exists idx_preguntas_leccion on preguntas(leccion_id, orden);
create index if not exists idx_opciones_pregunta on opciones(pregunta_id, orden);
create index if not exists idx_progreso_usuario on progreso_lecciones(usuario_id);
create index if not exists idx_intentos_usuario on intentos(usuario_id);
create index if not exists idx_perfiles_ranking on perfiles(nivel, experiencia desc, racha_dias desc, racha_respuestas desc);

create unique index if not exists perfiles_nombre_usuario_normalizado_idx
on perfiles (lower(nombre_usuario));

create or replace function crear_perfil_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.perfiles (
        id,
        nombre_usuario,
        nombre_visible
    )
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'user_name',
            'usuario_' || substr(new.id::text, 1, 8)
        ),
        coalesce(
            new.raw_user_meta_data ->> 'name',
            new.raw_user_meta_data ->> 'full_name'
        )
    );

    return new;
end;
$$;

create or replace function comprobar_respuesta(
    p_pregunta_id uuid,
    p_opcion_id uuid
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
    respuesta_correcta uuid;
    explicacion_respuesta text;
begin
    if not exists (
        select 1
        from preguntas
        where id = p_pregunta_id
        and estado_publicacion = 'publicado'
    ) then
        raise exception 'La pregunta no existe o no esta publicada';
    end if;

    if not exists (
        select 1
        from opciones
        where id = p_opcion_id
        and pregunta_id = p_pregunta_id
    ) then
        raise exception 'La opcion no pertenece a la pregunta';
    end if;

    select
        opcion_correcta_id,
        soluciones.explicacion
    into
        respuesta_correcta,
        explicacion_respuesta
    from soluciones
    where pregunta_id = p_pregunta_id;

    if respuesta_correcta is null then
        raise exception 'La pregunta no tiene una solucion configurada';
    end if;

    return query
    select
        p_opcion_id = respuesta_correcta,
        explicacion_respuesta;
end;
$$;

-- Normaliza respuestas de texto: sempre colapsa espacios y quita bordes; con
-- p_estricto tambien conserva mayusculas/minusculas (para codigo).
create or replace function normalizar_texto_respuesta(
    p_texto text,
    p_estricto boolean default false
)
returns text
language plpgsql
immutable
as $$
begin
    if p_texto is null then
        return null;
    end if;

    p_texto := regexp_replace(p_texto, '\s+', ' ', 'g');
    p_texto := btrim(p_texto);

    if not p_estricto then
        p_texto := lower(p_texto);
    end if;

    return p_texto;
end;
$$;

create or replace function texto_coincide_respuesta(
    p_enviado text,
    p_esperado text,
    p_estricto boolean default false
)
returns boolean
language plpgsql
immutable
as $$
begin
    return normalizar_texto_respuesta(p_enviado, p_estricto)
           = normalizar_texto_respuesta(p_esperado, p_estricto);
end;
$$;

-- Correccion de todos los demas tipos de actividad. La respuesta viaja como
-- jsonb y se valida contra soluciones / datos de la propia pregunta, por eso
-- un elemento nunca puede corregirse fuera de su actividad:
--
--   seleccion / verdadero_falso: {"opcion_id": uuid}
--   completar_texto:    {"valor": "texto"}
--   completar_codigo:   {"blancos": {"b1": "texto", ...}}
--   ordenar:            {"orden": ["<id elemento>", ...]}
--   relacionar:         {"pares": [{"id_a": "...", "id_b": "..."}, ...]}
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

        if v_datos -> 'valor' is not null then
            v_correcta := texto_coincide_respuesta(
                v_valor #>> '{}', v_datos ->> 'valor', v_estricto
            );
        end if;

        if not v_correcta then
            for v_esperado in select jsonb_array_elements_text(coalesce(v_datos -> 'alternativas', '[]'::jsonb)) loop
                exit when v_correcta;
                v_correcta := texto_coincide_respuesta(v_valor #>> '{}', v_esperado, v_estricto);
            end loop;
        end if;

    elsif v_tipo = 'completar_codigo' then
        v_respuesta := p_respuesta -> 'blancos';

        if v_respuesta is null then
            raise exception 'La respuesta debe indicar los valores de los blancos';
        end if;

        v_correcta := true;

        for v_blanco in select jsonb_array_elements(v_datos -> 'blancos') loop
            exit when not v_correcta;
            v_clave := v_blanco ->> 'clave';
            v_valor := v_respuesta -> v_clave;
            v_estricto := coalesce(v_blanco ->> 'estricta', 'true') = 'true';

            if v_valor is null then
                v_correcta := false;
            else
                v_correcta := texto_coincide_respuesta(v_valor #>> '{}', v_blanco ->> 'valor', v_estricto);

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

        -- El orden enviado debe ser exactamente el guardado y cada elemento
        -- debe pertenecer a esta pregunta (no a otra actividad).
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

        v_total_pares := jsonb_array_length(v_solucion -> 'pares');

        -- Todos los pares correctos, sin duplicados ni pares sobrantes.
        v_correcta :=
            v_total_pares = jsonb_array_length(v_respuesta)
            and (select count(distinct value ->> 'id_a') from jsonb_array_elements(v_respuesta)) = v_total_pares
            and not exists (
                select 1
                from jsonb_array_elements(v_solucion -> 'pares') sp
                where not exists (
                    select 1
                    from jsonb_array_elements(v_respuesta) re
                    where re ->> 'id_a' = sp ->> 'id_a'
                      and re ->> 'id_b' = sp ->> 'id_b'
                )
            );

    else
        raise exception 'Tipo de actividad no reconocido: %', v_tipo;
    end if;

    return query select v_correcta, v_explicacion;
end;
$$;

drop trigger if exists trigger_crear_perfil on auth.users;
create trigger trigger_crear_perfil
    after insert on auth.users
    for each row
    execute function crear_perfil_usuario();

alter table cursos enable row level security;
alter table unidades enable row level security;
alter table lecciones enable row level security;
alter table preguntas enable row level security;
alter table opciones enable row level security;
alter table soluciones enable row level security;
alter table perfiles enable row level security;
alter table progreso_lecciones enable row level security;
alter table intentos enable row level security;
alter table respuestas_intento enable row level security;
alter table amistades enable row level security;
alter table logros enable row level security;
alter table logros_usuario enable row level security;

drop policy if exists "cursos publicados visibles" on cursos;
create policy "cursos publicados visibles"
on cursos
for select
to anon, authenticated
using (estado_publicacion = 'publicado');

drop policy if exists "unidades publicadas o bloqueadas visibles" on unidades;
create policy "unidades publicadas o bloqueadas visibles"
on unidades
for select
to anon, authenticated
using (estado_publicacion in ('publicado', 'bloqueada'));

drop policy if exists "lecciones publicadas o bloqueadas visibles" on lecciones;
create policy "lecciones publicadas o bloqueadas visibles"
on lecciones
for select
to anon, authenticated
using (estado_publicacion in ('publicado', 'bloqueada'));

drop policy if exists "preguntas publicadas visibles" on preguntas;
create policy "preguntas publicadas visibles"
on preguntas
for select
to anon, authenticated
using (estado_publicacion = 'publicado');

drop policy if exists "opciones de preguntas publicadas visibles" on opciones;
create policy "opciones de preguntas publicadas visibles"
on opciones
for select
to anon, authenticated
using (
    exists (
        select 1
        from preguntas
        where preguntas.id = opciones.pregunta_id
        and preguntas.estado_publicacion = 'publicado'
    )
);

drop policy if exists "perfil propio visible" on perfiles;
create policy "perfil propio visible"
on perfiles
for select
to authenticated
using (id = auth.uid());

-- perfiles NO se lee entero entre usuarios. Cada quien ve su fila completa y
-- para el ranking se usa la vista perfiles_publicos, que expone solo los
-- campos que la interfaz muestra de otras personas.
drop policy if exists "perfiles para ranking" on perfiles;

drop policy if exists "usuario modifica su perfil" on perfiles;
create policy "usuario modifica su perfil"
on perfiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop view if exists perfiles_publicos;
create view perfiles_publicos
with (security_invoker = off)
as
    select id,
           nombre_usuario,
           avatar_url,
           nivel,
           experiencia,
           racha_dias
    from perfiles;

grant select on perfiles_publicos to authenticated;
revoke all on perfiles_publicos from anon;

drop policy if exists "progreso propio visible" on progreso_lecciones;
create policy "progreso propio visible"
on progreso_lecciones
for select
to authenticated
using (usuario_id = auth.uid());

-- progreso_lecciones solo admite lectura directa desde el cliente.
-- Las escrituras pasan por finalizar_intento() para que el servidor sea
-- el unico que puede marcar una leccion como completada o aprobada.
drop policy if exists "progreso propio inserta" on progreso_lecciones;
drop policy if exists "progreso propio modifica" on progreso_lecciones;

drop policy if exists "intentos propios visibles" on intentos;
create policy "intentos propios visibles"
on intentos
for select
to authenticated
using (usuario_id = auth.uid());

-- intentos solo admite lectura directa desde el cliente.
-- El alta y el cierre se hacen en iniciar_intento() / finalizar_intento().
drop policy if exists "intentos propios inserta" on intentos;

drop policy if exists "respuestas propias visibles" on respuestas_intento;
create policy "respuestas propias visibles"
on respuestas_intento
for select
to authenticated
using (
    exists (
        select 1
        from intentos
        where intentos.id = respuestas_intento.intento_id
        and intentos.usuario_id = auth.uid()
    )
);

-- respuestas_intento solo admite lectura directa desde el cliente.
-- El insert lo hace registrar_respuesta(), que corrige contra soluciones
-- y evita que el cliente marque su propia respuesta como correcta.
drop policy if exists "respuestas propias inserta" on respuestas_intento;

drop policy if exists "amistades propias visibles" on amistades;
create policy "amistades propias visibles"
on amistades
for select
to authenticated
using (
    usuario_id = auth.uid()
    or amigo_id = auth.uid()
);

drop policy if exists "amistades propias insertan" on amistades;
create policy "amistades propias insertan"
on amistades
for insert
to authenticated
with check (usuario_id = auth.uid());

drop policy if exists "amistades propias modifican" on amistades;
create policy "amistades propias modifican"
on amistades
for update
to authenticated
using (
    usuario_id = auth.uid()
    or amigo_id = auth.uid()
);

drop policy if exists "logros visibles" on logros;
create policy "logros visibles"
on logros
for select
to anon, authenticated
using (true);

drop policy if exists "logros propios visibles" on logros_usuario;
create policy "logros propios visibles"
on logros_usuario
for select
to authenticated
using (usuario_id = auth.uid());

drop policy if exists "soluciones bloqueadas" on soluciones;
create policy "soluciones bloqueadas"
on soluciones
for select
to authenticated
using (false);

create or replace function cantidad_preguntas_publicadas(p_leccion_id uuid)
returns integer
language sql
stable
security invoker
set search_path = public
as $$
    select count(*)::integer
    from preguntas
    where leccion_id = p_leccion_id
      and estado_publicacion = 'publicado';
$$;

-- Solo una lecciÃ³n 'publicado' se puede practicar. 'bloqueada' sigue siendo
-- visible para listar el contenido, pero el servidor no acepta intentar
-- resolverla: asi el desbloqueo no depende solo de la interfaz.
create or replace function es_leccion_publicada(p_leccion_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
    select exists (
        select 1
        from lecciones
        where id = p_leccion_id
          and estado_publicacion = 'publicado'
    );
$$;

create or replace function recalcular_intento(p_intento_id uuid)
returns table (
    total integer,
    correctas integer,
    incorrectas integer,
    porcentaje numeric,
    completado boolean,
    aprobado boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid;
    v_leccion uuid;
    v_total integer;
    v_correctas integer;
    v_respondidas integer;
    v_estado varchar;
begin
    select i.usuario_id, i.leccion_id
    into v_usuario, v_leccion
    from intentos i
    where i.id = p_intento_id
      and i.usuario_id = auth.uid();

    if v_usuario is null then
        raise exception 'El intento no existe o no pertenece al usuario';
    end if;

    select estado into v_estado from intentos where id = p_intento_id;

    v_total := cantidad_preguntas_publicadas(v_leccion);
    select count(*)::integer,
           count(*) filter (where r.correcta)::integer
    into v_respondidas, v_correctas
    from respuestas_intento r
    where r.intento_id = p_intento_id;

    total := v_total;
    correctas := v_correctas;
    incorrectas := greatest(v_respondidas - v_correctas, 0);
    porcentaje := case
        when v_total = 0 then 0
        else round(v_correctas::numeric * 100 / v_total, 2)
    end;
    completado := v_total > 0 and v_respondidas >= v_total;
    -- Regla general de aprobacion: al menos 2/3 de las actividades correctas,
    -- con redondeo hacia arriba para no pedir nunca mas de lo justo:
    -- 3 -> 2, 4 -> 3, 5 -> 4, 6 -> 4, 7 -> 5.
    aprobado := completado and v_correctas >= ceiling(v_total::numeric * 2 / 3)::integer;

    return next;
end;
$$;

-- Publica la siguiente unidad de un curso cuando todas las lecciones
-- publicadas de la unidad actual del usuario quedan aprobadas. Es parte del
-- desbloqueo secuencial: sin esto, las unidades 2..N quedarian congeladas en
-- estado 'bloqueada' para siempre.
create or replace function desbloquear_siguiente_unidad(
    p_usuario_id uuid,
    p_leccion_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_unidad_actual uuid;
    v_curso uuid;
    v_unidad_siguiente uuid;
begin
    select l.unidad_id, u.curso_id
    into v_unidad_actual, v_curso
    from lecciones l
    join unidades u on u.id = l.unidad_id
    where l.id = p_leccion_id;

    if v_unidad_actual is null then
        return;
    end if;

    -- Falta leccion: la unidad no esta completa, no hay nada que desbloquear.
    if exists (
        select 1
        from lecciones l
        where l.unidad_id = v_unidad_actual
          and l.estado_publicacion = 'publicado'
          and not exists (
              select 1 from progreso_lecciones p
              where p.usuario_id = p_usuario_id
                and p.leccion_id = l.id
                and p.aprobada
          )
    ) then
        return;
    end if;

    select u.id into v_unidad_siguiente
    from unidades u
    where u.curso_id = v_curso
      and u.estado_publicacion = 'bloqueada'
      and u.orden = (
          select min(u2.orden) from unidades u2
          where u2.curso_id = v_curso and u2.estado_publicacion = 'bloqueada'
      );

    if v_unidad_siguiente is not null then
        update unidades
        set estado_publicacion = 'publicado'
        where id = v_unidad_siguiente;
    end if;
end;
$$;

create or replace function iniciar_intento(
    p_leccion_id uuid,
    p_clave_idempotencia uuid
)
returns table (
    intento_id uuid,
    ya_existia boolean,
    total integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_id uuid;
    v_leccion_existente uuid;
    v_existente boolean;
    v_total integer;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para iniciar un intento';
    end if;

    if not es_leccion_publicada(p_leccion_id) then
        raise exception 'La leccion no existe o no esta publicada';
    end if;

    select i.id, i.leccion_id into v_id, v_leccion_existente
    from intentos i
    where i.usuario_id = v_usuario and i.clave_idempotencia = p_clave_idempotencia;

    if v_id is not null and v_leccion_existente <> p_leccion_id then
        raise exception 'La clave de idempotencia ya fue usada para otra leccion';
    end if;

    if v_id is not null then
        v_existente := true;
    else
        v_total := cantidad_preguntas_publicadas(p_leccion_id);
        insert into intentos (usuario_id, leccion_id, clave_idempotencia, estado, cantidad_preguntas)
        values (v_usuario, p_leccion_id, p_clave_idempotencia, 'en_curso', v_total)
        on conflict (usuario_id, clave_idempotencia) do nothing;

        select i.id into v_id
        from intentos i
        where i.usuario_id = v_usuario and i.clave_idempotencia = p_clave_idempotencia;

        v_existente := false;
    end if;

    select i.cantidad_preguntas into v_total from intentos i where i.id = v_id;

    return query select v_id, v_existente, coalesce(v_total, 0);
end;
$$;

create or replace function registrar_respuesta(
    p_intento_id uuid,
    p_pregunta_id uuid,
    p_respuesta jsonb
)
returns table (
    correcta boolean,
    explicacion text,
    ya_registrada boolean,
    porcentaje numeric,
    correctas integer,
    total integer,
    completado boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_leccion uuid;
    v_estado varchar;
    v_tipo varchar;
    v_correccion record;
    v_opcion uuid;
    v_ya_registrada boolean := false;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para responder';
    end if;

    select i.leccion_id, i.estado into v_leccion, v_estado
    from intentos i
    where i.id = p_intento_id and i.usuario_id = v_usuario;

    if v_leccion is null then
        raise exception 'El intento no existe o no pertenece al usuario';
    end if;

    if v_estado <> 'en_curso' then
        raise exception 'El intento ya fue finalizado';
    end if;

    select tipo into v_tipo
    from preguntas
    where id = p_pregunta_id
      and leccion_id = v_leccion
      and estado_publicacion = 'publicado';

    if v_tipo is null then
        raise exception 'La pregunta no pertenece a la leccion o no esta publicada';
    end if;

    if exists (
        select 1 from respuestas_intento where intento_id = p_intento_id and pregunta_id = p_pregunta_id
    ) then
        v_ya_registrada := true;
        select r.correcta, s.explicacion into v_correccion
        from respuestas_intento r
        join soluciones s on s.pregunta_id = r.pregunta_id
        where r.intento_id = p_intento_id and r.pregunta_id = p_pregunta_id;
    else
        select c.correcta, c.explicacion into v_correccion
        from comprobar_respuesta(p_pregunta_id, p_respuesta) c;

        if v_tipo in ('seleccion', 'verdadero_falso') then
            v_opcion := (p_respuesta ->> 'opcion_id')::uuid;
        end if;

        insert into respuestas_intento
            (intento_id, pregunta_id, opcion_id, respuesta, correcta)
        values (p_intento_id, p_pregunta_id, v_opcion, p_respuesta, v_correccion.correcta)
        on conflict (intento_id, pregunta_id) do nothing;
    end if;

    update intentos i
    set respuestas_correctas = (select count(*)::integer from respuestas_intento r where r.intento_id = i.id and r.correcta),
        respuestas_incorrectas = (select count(*)::integer from respuestas_intento r where r.intento_id = i.id and not r.correcta)
    where i.id = p_intento_id;

    return query
    select v_correccion.correcta,
           v_correccion.explicacion,
           v_ya_registrada,
           r.porcentaje,
           r.correctas,
           r.total,
           r.completado
    from recalcular_intento(p_intento_id) r;
end;
$$;

create or replace function registrar_respuesta(
    p_intento_id uuid,
    p_pregunta_id uuid,
    p_opcion_id uuid
)
returns table (
    correcta boolean,
    explicacion text,
    ya_registrada boolean,
    porcentaje numeric,
    correctas integer,
    total integer,
    completado boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Compatibilidad con clientes anteiores: delega en la version jsonb.
    return query
    select * from registrar_respuesta(
        p_intento_id,
        p_pregunta_id,
        jsonb_build_object('opcion_id', p_opcion_id)
    );
end;
$$;

create or replace function finalizar_intento(p_intento_id uuid)
returns table (
    porcentaje numeric,
    correctas integer,
    incorrectas integer,
    total integer,
    completado boolean,
    aprobado boolean,
    xp_ganado integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_leccion uuid;
    v_estado varchar;
    v_resumen record;
    v_xp integer;
    v_ya_aprobada boolean;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para finalizar un intento';
    end if;

    select i.leccion_id, i.estado into v_leccion, v_estado
    from intentos i
    where i.id = p_intento_id and i.usuario_id = v_usuario;

    if v_leccion is null then
        raise exception 'El intento no existe o no pertenece al usuario';
    end if;

    if v_estado <> 'en_curso' then
        select * into v_resumen from recalcular_intento(p_intento_id);
        select xp_ganado into v_xp from intentos where id = p_intento_id;
        return query
        select v_resumen.porcentaje, v_resumen.correctas, v_resumen.incorrectas,
               v_resumen.total, v_resumen.completado, v_resumen.aprobado, v_xp;
        return;
    end if;

    select * into v_resumen from recalcular_intento(p_intento_id);

    select p.aprobada into v_ya_aprobada
    from progreso_lecciones p
    where p.usuario_id = v_usuario and p.leccion_id = v_leccion;

    v_ya_aprobada := coalesce(v_ya_aprobada, false);

    update intentos
    set estado = 'completado',
        finalizado_at = now(),
        cantidad_preguntas = v_resumen.total,
        respuestas_correctas = v_resumen.correctas,
        respuestas_incorrectas = v_resumen.incorrectas,
        porcentaje = v_resumen.porcentaje,
        completado = v_resumen.completado,
        aprobado = v_resumen.aprobado
    where id = p_intento_id and usuario_id = v_usuario;

    insert into progreso_lecciones (
        usuario_id, leccion_id, completada, aprobada, intentos,
        mejor_porcentaje, ultimo_porcentaje, ultimo_intento_id, aprobado_en, updated_at
    )
    values (
        v_usuario, v_leccion,
        v_resumen.completado, v_resumen.aprobado, 1,
        v_resumen.porcentaje, v_resumen.porcentaje, p_intento_id,
        case when v_resumen.aprobado then now() else null end, now()
    )
    on conflict (usuario_id, leccion_id) do update
    set intentos = progreso_lecciones.intentos + 1,
        completada = progreso_lecciones.completada or excluded.completada,
        aprobada = progreso_lecciones.aprobada or excluded.aprobada,
        mejor_porcentaje = greatest(progreso_lecciones.mejor_porcentaje, excluded.mejor_porcentaje),
        ultimo_porcentaje = excluded.ultimo_porcentaje,
        ultimo_intento_id = excluded.ultimo_intento_id,
        aprobado_en = case
            when excluded.aprobada and progreso_lecciones.aprobado_en is null then now()
            else progreso_lecciones.aprobado_en
        end,
        updated_at = now();

    v_xp := 0;
    if v_resumen.aprobado and not v_ya_aprobada then
        v_xp := 20 + v_resumen.correctas * 5;
        -- El perfil lo crea el trigger al crearse el usuario. Si todavia no
        -- existe se corta la operacion: es preferible fallar y reintentar
        -- que perder la respuesta o el XP en silencio.
        update perfiles set experiencia = experiencia + v_xp, updated_at = now()
        where id = v_usuario;

        if not found then
            raise exception 'El perfil del usuario todavia no esta disponible';
        end if;

        update intentos set xp_ganado = v_xp where id = p_intento_id;
    else
        select i.xp_ganado into v_xp from intentos i where i.id = p_intento_id;
    end if;

    if v_resumen.aprobado then
        perform desbloquear_siguiente_unidad(v_usuario, v_leccion);
    end if;

    return query
    select v_resumen.porcentaje, v_resumen.correctas, v_resumen.incorrectas,
           v_resumen.total, v_resumen.completado, v_resumen.aprobado, v_xp;
end;
$$;

create or replace function obtener_progreso()
returns table (
    leccion_id uuid,
    completada boolean,
    aprobada boolean,
    intentos integer,
    mejor_porcentaje numeric,
    ultimo_porcentaje numeric,
    ultimo_intento_id uuid,
    aprobado_en timestamptz,
    updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
    select p.leccion_id, p.completada, p.aprobada, p.intentos,
           p.mejor_porcentaje, p.ultimo_porcentaje, p.ultimo_intento_id,
           p.aprobado_en, p.updated_at
    from progreso_lecciones p
    where p.usuario_id = auth.uid()
    order by p.updated_at desc;
$$;

revoke all on function comprobar_respuesta(uuid, uuid) from public;
grant execute on function comprobar_respuesta(uuid, uuid) to anon, authenticated;

revoke all on function iniciar_intento(uuid, uuid) from public;
grant execute on function iniciar_intento(uuid, uuid) to authenticated;

revoke all on function registrar_respuesta(uuid, uuid, uuid) from public;
grant execute on function registrar_respuesta(uuid, uuid, uuid) to authenticated;

revoke all on function finalizar_intento(uuid) from public;
grant execute on function finalizar_intento(uuid) to authenticated;

revoke all on function obtener_progreso() from public;
grant execute on function obtener_progreso() to authenticated;

revoke all on function cantidad_preguntas_publicadas(uuid) from public;
grant execute on function cantidad_preguntas_publicadas(uuid) to anon, authenticated;

revoke all on function es_leccion_publicada(uuid) from public;
grant execute on function es_leccion_publicada(uuid) to anon, authenticated;

revoke all on function recalcular_intento(uuid) from public;

revoke all on function comprobar_respuesta(uuid, jsonb) from public;
grant execute on function comprobar_respuesta(uuid, jsonb) to anon, authenticated;

revoke all on function registrar_respuesta(uuid, uuid, jsonb) from public;
grant execute on function registrar_respuesta(uuid, uuid, jsonb) to authenticated;

revoke all on function desbloquear_siguiente_unidad(uuid, uuid) from public;

-- ---------------------------------------------------------------------------
-- Migracion de progreso persistente
-- Necesaria en bases donde intentos / progreso_lecciones ya existen:
-- "create table if not exists" no agrega columnas a tablas previas.
-- Es idempotente: se puede ejecutar mas de una vez sin efectos.
-- ---------------------------------------------------------------------------

do $$
begin
    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'intentos' and column_name = 'clave_idempotencia'
    ) then
        alter table intentos add column clave_idempotencia uuid;
        update intentos set clave_idempotencia = gen_random_uuid()
        where clave_idempotencia is null;
        alter table intentos alter column clave_idempotencia set not null;
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'intentos' and column_name = 'estado'
    ) then
        alter table intentos add column estado varchar(20) not null default 'en_curso';
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'intentos' and column_name = 'iniciado_at'
    ) then
        alter table intentos add column iniciado_at timestamptz not null default now();
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'intentos' and column_name = 'finalizado_at'
    ) then
        alter table intentos add column finalizado_at timestamptz;
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'intentos' and column_name = 'xp_ganado'
    ) then
        alter table intentos add column xp_ganado integer not null default 0;
    end if;

    -- Solo se cierran intentos que ya estaban marcados como completados.
-- Los intentos que sigan "en_curso" se respetan para no invalidar
-- partidas que todavia esteen en curso.
update intentos
    set estado = 'completado',
        finalizado_at = coalesce(finalizado_at, created_at, now())
    where estado = 'en_curso' and completado;

    if not exists (
        select 1 from pg_constraint where conname = 'intentos_clave_unica'
    ) then
        alter table intentos
        add constraint intentos_clave_unica unique (usuario_id, clave_idempotencia);
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'intentos_estado_check'
    ) then
        alter table intentos
        add constraint intentos_estado_check check (estado in ('en_curso', 'completado', 'abandonado'));
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'intentos_cerrado_check'
    ) then
        alter table intentos
        add constraint intentos_cerrado_check check (
            (estado = 'en_curso' and finalizado_at is null)
            or (estado <> 'en_curso' and finalizado_at is not null)
        );
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'progreso_lecciones' and column_name = 'ultimo_porcentaje'
    ) then
        alter table progreso_lecciones add column ultimo_porcentaje numeric(5,2) not null default 0;
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'progreso_lecciones' and column_name = 'ultimo_intento_id'
    ) then
        alter table progreso_lecciones add column ultimo_intento_id uuid;
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'progreso_lecciones' and column_name = 'aprobado_en'
    ) then
        alter table progreso_lecciones add column aprobado_en timestamptz;
    end if;

    update progreso_lecciones
    set ultimo_porcentaje = mejor_porcentaje,
        aprobado_en = coalesce(aprobado_en, case when aprobada then updated_at else null end)
    where mejor_porcentaje > 0 and ultimo_porcentaje = 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- Migracion de tipos de actividad
-- Necesaria en bases donde preguntas / soluciones / respuestas_intento ya
-- existen. Amplia las actividades de solo multiple_choice a seis tipos:
-- seleccion, verdadero_falso, completar_texto, completar_codigo, ordenar y
-- relacionar. multiple_choice (si queda alguno) se normaliza a seleccion.
-- ---------------------------------------------------------------------------
do $$
begin
    alter table preguntas add column if not exists datos jsonb;

    update preguntas set tipo = 'seleccion' where tipo = 'multiple_choice';
    alter table preguntas alter column tipo set default 'seleccion';

    alter table preguntas drop constraint if exists preguntas_tipo_check;
    alter table preguntas
    add constraint preguntas_tipo_check check (tipo in (
        'seleccion',
        'verdadero_falso',
        'completar_texto',
        'completar_codigo',
        'ordenar',
        'relacionar'
    ));

    alter table soluciones alter column opcion_correcta_id drop not null;
    alter table soluciones add column if not exists solucion jsonb;

    alter table soluciones drop constraint if exists soluciones_origen_check;
    alter table soluciones
    add constraint soluciones_origen_check
    check (opcion_correcta_id is not null or solucion is not null);

    alter table respuestas_intento alter column opcion_id drop not null;
    alter table respuestas_intento add column if not exists respuesta jsonb;

    alter table respuestas_intento drop constraint if exists respuestas_intento_origen_check;
    alter table respuestas_intento
    add constraint respuestas_intento_origen_check
    check (opcion_id is not null or respuesta is not null);
end;
$$;

create index if not exists intentos_usuario_leccion_idx on intentos (usuario_id, leccion_id, created_at desc);
create index if not exists intentos_clave_idx on intentos (usuario_id, clave_idempotencia);
create index if not exists progreso_lecciones_usuario_idx on progreso_lecciones (usuario_id, updated_at desc);
create index if not exists respuestas_intento_intento_idx on respuestas_intento (intento_id);

insert into cursos (
    id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion
)
values (
    '10000000-0000-0000-0000-000000000001',
    'JavaScript',
    'CreÃ¡ tus primeros programas en el lenguaje mÃ¡s usado del mundo.',
    'El lenguaje de la web',
    'JS',
    'javascriptLogo',
    '#f7df1e',
    1,
    'publicado'
)
on conflict (id) do nothing;

insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values
(
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Variables y datos',
    'GuardÃ¡ informaciÃ³n y conocÃ© los tipos de datos bÃ¡sicos de JavaScript.',
    1,
    'publicado'
),
(
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Operadores',
    'CalculÃ¡ con nÃºmeros y comparÃ¡ valores usando operadores.',
    2,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'Condicionales',
    'TomÃ¡ decisiones en tu cÃ³digo con if y else.',
    3,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    'Bucles',
    'RepetÃ­ tareas automÃ¡ticamente con for y while.',
    4,
    'bloqueada'
),
(
    '20000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    'Funciones',
    'OrganizÃ¡ tu cÃ³digo en bloques reutilizables.',
    5,
    'bloqueada'
)
on conflict (id) do nothing;

insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values
(
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Variables y asignaciÃ³n',
    'Una variable guarda un valor para reutilizarlo despuÃ©s. En JavaScript usamos let para declarar una variable y luego le asignamos un valor.',
    E'let nombre = "Ana";\nlet edad = 18;\nconsole.log(nombre);\nconsole.log(edad);',
    1,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'Operadores y cÃ¡lculo',
    'Los operadores permiten combinar valores y hacer cÃ¡lculos. La suma, resta, multiplicaciÃ³n y divisiÃ³n son las operaciones mÃ¡s comunes.',
    E'let precio = 10;\nlet cantidad = 3;\nlet total = precio * cantidad;\nconsole.log(total);',
    2,
    'publicado'
)
on conflict (id) do nothing;

insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion)
values
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Â¿CuÃ¡l de estas lÃ­neas declara correctamente una variable llamada edad con el valor 18?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    'Â¿QuÃ© valor completa la sentencia para guardar el nombre de una persona?\nlet nombre = ___;',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    'Â¿QuÃ© opciÃ³n representa una asignaciÃ³n vÃ¡lida de una constante?',
    'multiple_choice',
    3,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000002',
    'Â¿QuÃ© resultado devuelve 12 + 5?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000002',
    'Â¿QuÃ© operador completa la sentencia para calcular el resto de la divisiÃ³n?\nlet resto = 10 ___ 3;',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000002',
    'Â¿CuÃ¡l de estas expresiones calcula correctamente el total de 4 Ã— 3?',
    'multiple_choice',
    3,
    'publicado'
)
on conflict (id) do nothing;

insert into opciones (id, pregunta_id, texto, orden)
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
    'const apellido = "PÃ©rez";',
    1
),
(
    '50000000-0000-0000-0000-000000000010',
    '40000000-0000-0000-0000-000000000003',
    'const = "PÃ©rez";',
    2
),
(
    '50000000-0000-0000-0000-000000000011',
    '40000000-0000-0000-0000-000000000003',
    'let const = "PÃ©rez";',
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
    '40000000-0000-0000-000000000004',
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
)
on conflict (id) do nothing;

insert into soluciones (pregunta_id, opcion_correcta_id, explicacion)
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
    'La suma combina ambos valores numÃ©ricos y da 17.'
),
(
    '40000000-0000-0000-0000-000000000005',
    '50000000-0000-0000-0000-000000000017',
    'El operador % devuelve el resto de la divisiÃ³n: 10 % 3 da 1.'
),
(
    '40000000-0000-0000-0000-000000000006',
    '50000000-0000-0000-0000-000000000021',
    'La multiplicaciÃ³n usa el operador *. 4 * 3 equivale a 12.'
)
on conflict (pregunta_id) do nothing;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'perfiles_nombre_usuario_formato_check'
    ) then
        alter table perfiles
        add constraint perfiles_nombre_usuario_formato_check
        check (
            length(nombre_usuario) between 3 and 20
            and nombre_usuario ~* '^[a-z0-9]+(?:[._-][a-z0-9]+)*$'
        );
    end if;
end;
$$;

update lecciones
set ejemplo_codigo = replace(
  replace(
    replace(ejemplo_codigo, E'\\r\\n', E'\n'),
    E'\\n', E'\n'
  ),
  E'\\t', E'\t'
)
where ejemplo_codigo like E'%\\n%'
   or ejemplo_codigo like E'%\\t%'
   or ejemplo_codigo like E'%\\r%';

-- ===========================================================================
-- Ampliacion de curricula (Etapa 6)
-- ===========================================================================

-- Reorden de bandas de orden para evitar choques de unique en la
-- reasignacion de lecciones a unidades nuevas.
update lecciones
set orden = orden + 100
where id between '30000000-0000-0000-0000-000000000001'::uuid
              and '30000000-0000-0000-0000-000000000010'::uuid;

update lecciones set
  unidad_id = '20000000-0000-0000-0000-000000000001'::uuid,
  orden = case id
    when '30000000-0000-0000-0000-000000000001'::uuid then 1
    when '30000000-0000-0000-0000-000000000002'::uuid then 2
    when '30000000-0000-0000-0000-000000000003'::uuid then 3
  end
where id in (
  '30000000-0000-0000-0000-000000000001'::uuid,
  '30000000-0000-0000-0000-000000000002'::uuid,
  '30000000-0000-0000-0000-000000000003'::uuid
);

update lecciones set
  unidad_id = '20000000-0000-0000-0000-000000000002'::uuid,
  orden = case id
    when '30000000-0000-0000-0000-000000000004'::uuid then 1
    when '30000000-0000-0000-0000-000000000005'::uuid then 2
    when '30000000-0000-0000-0000-000000000006'::uuid then 3
    when '30000000-0000-0000-0000-000000000007'::uuid then 4
  end
where id in (
  '30000000-0000-0000-0000-000000000004'::uuid,
  '30000000-0000-0000-0000-000000000005'::uuid,
  '30000000-0000-0000-0000-000000000006'::uuid,
  '30000000-0000-0000-0000-000000000007'::uuid
);

update lecciones set
  unidad_id = '20000000-0000-0000-0000-000000000003'::uuid,
  orden = case id
    when '30000000-0000-0000-0000-000000000008'::uuid then 1
    when '30000000-0000-0000-0000-000000000009'::uuid then 2
    when '30000000-0000-0000-0000-000000000010'::uuid then 3
  end
where id in (
  '30000000-0000-0000-0000-000000000008'::uuid,
  '30000000-0000-0000-0000-000000000009'::uuid,
  '30000000-0000-0000-0000-000000000010'::uuid
);

update unidades
set nombre = 'Conceptos basicos',
    descripcion = 'Guarda datos, calcula y toma decisiones con if y else.',
    orden = 1,
    estado_publicacion = 'publicado'
where id = '20000000-0000-0000-0000-000000000001'::uuid;

update unidades
set nombre = 'Control de flujo',
    descripcion = 'Repeti tareas, organiza tu codigo y trabaja con colecciones.',
    orden = 2,
    estado_publicacion = 'bloqueada'
where id = '20000000-0000-0000-0000-000000000002'::uuid;

insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values (
  '20000000-0000-0000-0000-000000000003'::uuid,
  '10000000-0000-0000-0000-000000000001'::uuid,
  'Estructuras y datos',
  'ReunI todo en objetos, metodos y un proyecto de cierre.',
  3,
  'bloqueada'
) on conflict (id) do update
  set nombre = excluded.nombre,
      descripcion = excluded.descripcion,
      orden = excluded.orden,
      estado_publicacion = excluded.estado_publicacion;

delete from unidades
where id > '20000000-0000-0000-0000-000000000003'::uuid;

update lecciones set
  titulo = 'Variables y tipos de datos',
  explicacion = 'Una variable guarda un dato para usarlo despues. Con let o const declaras la variable y le das un valor: un texto (string), un numero o un booleano.',
  ejemplo_codigo = E'const nombre = "Ana";\nlet edad = 18;\nconst esAlumno = true;'
where id = '30000000-0000-0000-0000-000000000001'::uuid;

update lecciones set
  titulo = 'Operadores y calculo',
  explicacion = 'Los operadores combinan valores: aritmeticos (+ - * / %) para calcular y de comparacion (> < ===) para decidir.',
  ejemplo_codigo = E'let precio = 10;\nlet cantidad = 3;\nlet total = precio * cantidad;\nconsole.log(total);'
where id = '30000000-0000-0000-0000-000000000002'::uuid;

update lecciones set
  titulo = 'Condicionales con if',
  explicacion = 'Con if y else, el programa ejecuta un bloque solo cuando la condicion se cumple. El operador === compara valor y tipo al mismo tiempo.',
  ejemplo_codigo = E'const edad = 15;\nif (edad >= 18) {\n  console.log("Es adulto");\n} else {\n  console.log("Menor");\n}'
where id = '30000000-0000-0000-0000-000000000003'::uuid;

update lecciones set
  titulo = 'Bucles for',
  explicacion = 'Un bucle for tiene tres partes: valor inicial, condicion de continuacion y paso. El cuerpo corre en cada vuelta mientras la condicion sea verdadera.',
  ejemplo_codigo = E'let suma = 0;\nfor (let i = 1; i <= 5; i++) {\n  suma = suma + i;\n}\nconsole.log(suma);'
where id = '30000000-0000-0000-0000-000000000004'::uuid;

update lecciones set
  titulo = 'Bucles while',
  explicacion = 'El bucle while repite mientras la condicion sea verdadera. Sin un cambio que la vuelva falsa, el bucle no termina nunca.',
  ejemplo_codigo = E'let contador = 3;\nwhile (contador > 0) {\n  console.log(contador);\n  contador = contador - 1;\n}\nconsole.log("Despegue");'
where id = '30000000-0000-0000-0000-000000000005'::uuid;

update lecciones set
  titulo = 'Funciones',
  explicacion = 'Una funcion agrupa codigo para reutilizarlo: recibe parametros, hace su trabajo y devuelve un resultado con return.',
  ejemplo_codigo = E'function doble(x) {\n  return x * 2;\n}\nconsole.log(doble(5));'
where id = '30000000-0000-0000-0000-000000000006'::uuid;

update lecciones set
  titulo = 'Arrays y listas',
  explicacion = 'Un array guarda una lista de valores con indices: el primero es la posicion 0. length dice cuantos elementos tiene y push agrega al final.',
  ejemplo_codigo = E'const frutas = ["pera", "manzana"];\nconsole.log(frutas[0]);\nconsole.log(frutas.length);'
where id = '30000000-0000-0000-0000-000000000007'::uuid;

-- Limpieza de la vieja curricula de JavaScript (3 preguntas por leccion).

delete from preguntas
where id between '40000000-0000-0000-0000-000000000001'::uuid
             and '40000000-0000-0000-0000-000000000006'::uuid;
-- ---------------------------------------------------------------------------
-- Contenido: JavaScript (53 actividades: 4/5/7 por dificultad)
-- ---------------------------------------------------------------------------
-- Nomenculatura de claves por pregunta, ej: js:l01:a1
-- ids deterministicos: uuid(md5(clave)) para pre/aptas y clave ':o{n}'
-- para opciones. on conflict do nothing hace el seed re-aplicable.

insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values
(
  '30000000-0000-0000-0000-000000000008'::uuid,
  '20000000-0000-0000-0000-000000000003'::uuid,
  'Objetos',
  'Un objeto guarda datos con nombres de propiedad. Se lee con la notacion punto o c by corchetes y se puede recorrer con for...in.',
  E'const perro = { nombre: "Fury", edad: 3 };\nconsole.log(perro.nombre);\nconsole.log(perro["edad"]);',
  1,
  'publicado'
),
(
  '30000000-0000-0000-0000-000000000009'::uuid,
  '20000000-0000-0000-0000-000000000003'::uuid,
  'Cadenas de texto',
  'Los strings tienen metodos: toUpperCase, trim, includes, split. Se combinan para limpiar, comparar y trocear.',
  E'const texto = "  Kodigo  ";\nconsole.log(texto.trim().toUpperCase());',
  2,
  'publicado'
),
(
  '30000000-0000-0000-0000-000000000010'::uuid,
  '20000000-0000-0000-0000-000000000003'::uuid,
  'Proyecto: notas de clase',
  'Cierre del curso: un combino con arrays, bucles, funciones y objetos para calcular notas y promedios.',
  E'const notas = [10, 6, 8, 9, 5];\nlet total = 0;\nfor (let i = 0; i < notas.length; i++) {\n  total = total + notas[i];\n}\nconsole.log(total / notas.length);',
  3,
  'publicado'
) on conflict (id) do nothing;-- ACTIVIDADES JS: unidad 1 (Conceptos basicos, 3 lecciones x 4)
with lecciones_num as (
  select id, row_number() over (order by id) as n
  from lecciones
  where id between '30000000-0000-0000-0000-000000000001'::uuid
               and '30000000-0000-0000-0000-000000000010'::uuid
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:js:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- L1 Variables y tipos de datos
  ('js:l01:a1', 1,
   'Que linea declara una varible edad con el valor 18, de forma que se pueda cambiar despues?',
   'seleccion', null, 1),
  ('js:l01:a2', 1,
   'Que palabra reservada se usa para declarar una constante en JavaScript?',
   'completar_texto',
   '{"valor": "const", "alternativas": []}'::jsonb, 2),
  ('js:l01:a3', 1,
   'Que tipo de dato representa la expresion "Julia"?',
   'seleccion', null, 3),
  ('js:l01:a4', 1,
   'En JavaScript, una variable declarada con let si puede cambiar de valor mas adelante.',
   'verdadero_falso', null, 4),
  -- L2 Operadores y calculo
  ('js:l02:a1', 2,
   E'Que muestra en consola el codigo?\nconsole.log(2 + 3 * 4);',
   'seleccion', null, 1),
  ('js:l02:a2', 2,
   'Completa la linea para calcular el resto de dividir 10 entre 3.',
   'completar_codigo',
   '{"codigo": "let resto = 10 {b1} 3;", "blancos": [{"clave": "b1", "valor": "%", "alternativas": [], "estricta": true}], "candidatos": ["+", "-", "*", "%", "/"]}'::jsonb,
   2),
  ('js:l02:a3', 2,
   'El operador % devuelve el resto de una division entera: 10 % 3 da 1.',
   'verdadero_falso', null, 3),
  ('js:l02:a4', 2,
   'Ordena las lineas para que el programa declare a, calcule b y muestre c en la consola.',
   'ordenar', '{"instruccion": "De arriba hacia abajo, tal como se ejecuta el programa"}'::jsonb, 4),
  -- L3 Condicionales con if
  ('js:l03:a1', 3,
   E'Que se muestra en consola?\nconst edad = 15;\nif (edad >= 18) {\n  console.log("Es adulto");\n} else {\n  console.log("Menor");\n}',
   'seleccion', null, 1),
  ('js:l03:a2', 3,
   'Completa el operador de comparacion estricta, el que exige mismo valor y mismo tipo.',
   'completar_codigo',
   '{"codigo": "const guardado = 8;\nconst ingresado = 8;\nif (ingresado {b1} guardado) {\n  console.log(\"Coincide exactamente\");\n}", "blancos": [{"clave": "b1", "valor": "===", "alternativas": [], "estricta": true}], "candidatos": ["==", "===", "!==", ">="]}'::jsonb,
   2),
  ('js:l03:a3', 3,
   'Un if sin else ejecuta su bloque aunque la condicion sea falsa.',
   'verdadero_falso', null, 3),
  ('js:l03:a4', 3,
   'Uni cada operador con su significado.',
   'relacionar',
   '{"columna_a": [{"id": "op-mayor", "texto": ">"}, {"id": "op-menor", "texto": "<"}, {"id": "op-estricto", "texto": "==="}, {"id": "op-negar", "texto": "!"}], "columna_b": [{"id": "sg-mayor", "texto": "Es mayor que"}, {"id": "sg-menor", "texto": "Es menor que"}, {"id": "sg-estricto", "texto": "Es igual, valor y tipo"}, {"id": "sg-negar", "texto": "Niega y da vuelta la comparacion"}]}'::jsonb,
   4)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;
-- ACTIVIDADES JS: unidad 2 (Control de flujo, 4 lecciones x 5)
with lecciones_num as (
  select id, row_number() over (order by id) as n
  from lecciones
  where id between '30000000-0000-0000-0000-000000000001'::uuid
               and '30000000-0000-0000-0000-000000000010'::uuid
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:js:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- L4 Bucles for
  ('js:l04:a1', 4,
   E'Cuantas lineas imprime este bucle y con que valores?\nfor (let i = 0; i < 3; i++) {\n  console.log(i);\n}',
   'seleccion', null, 1),
  ('js:l04:a2', 4,
   'Completa la condicion para que el bucle sume los numeros del 1 al 10.',
   'completar_codigo',
   '{"codigo": "let total = 0;\nfor (let i = 1; i {b1} 10; i++) {\n  total = total + i;\n}\nconsole.log(total);", "blancos": [{"clave": "b1", "valor": "<=", "alternativas": [], "estricta": true}], "candidatos": ["<", "<=", ">", "!="]}'::jsonb,
   2),
  ('js:l04:a3', 4,
   'Ordena las lineas del programa que suma e imprime los numeros del 1 al 5 (sin contar las llaves).',
   'ordenar', '{"instruccion": "Primero la preparacion, el bucle y el resultado al final"}'::jsonb, 3),
  ('js:l04:a4', 4,
   'Una variable declarada con let dentro del parrafo del for deja de existir cuando el bucle termina.',
   'verdadero_falso', null, 4),
  ('js:l04:a5', 4,
   'En "for (let i = 0; i < 10; i++)", cuantas veces se ejecuta el cuerpo del bucle?',
   'seleccion', null, 5),
  -- L5 Bucles while
  ('js:l05:a1', 5,
   E'Que valores imprime?\nlet n = 5;\nwhile (n > 3) {\n  console.log(n);\n  n--;\n}',
   'seleccion', null, 1),
  ('js:l05:a2', 5,
   'Completa la condicion para que la cuenta regresiva arranque en 3 y baje hasta 1.',
   'completar_codigo',
   '{"codigo": "let contador = 3;\nwhile (contador {b1} 0) {\n  console.log(contador);\n  contador = contador - 1;\n}", "blancos": [{"clave": "b1", "valor": ">", "alternativas": [], "estricta": true}], "candidatos": ["<", ">", "<=", "==="]}'::jsonb,
   2),
  ('js:l05:a3', 5,
   'Ordena las lineas del programa que baja un saldo de 100 a 30, restando 10 cada vuelta.',
   'ordenar', '{"instruccion": "Primero la variable, despues el bucle y su cuerpo"}'::jsonb, 3),
  ('js:l05:a4', 5,
   E'Por que este bucle no termina nunca?\nwhile (true) {\n  console.log("Hola");\n}',
   'seleccion', null, 4),
  ('js:l05:a5', 5,
   'Que palabra salta directamente a la siguiente vuelta de un bucle sin dejar de repetir?',
   'completar_texto',
   '{"valor": "continue", "alternativas": ["continue;"]}'::jsonb, 5),
  -- L6 Funciones
  ('js:l06:a1', 6,
   E'Que imprime el programa?\nfunction doble(x) {\n  return x * 2;\n}\nconsole.log(doble(5));',
   'seleccion', null, 1),
  ('js:l06:a2', 6,
   'Completa la funcion para que devuelva el area de un cuadrado.',
   'completar_codigo',
   '{"codigo": "function area(lado) {\n  b1 lado * lado;\n}", "blancos": [{"clave": "b1", "valor": "return", "alternativas": [], "estricta": true}], "candidatos": ["return", "let", "if", "print"]}'::jsonb,
   2),
  ('js:l06:a3', 6,
   'Las variables creadas dentro de una funcion no se pueden usar fuera de ella.',
   'verdadero_falso', null, 3),
  ('js:l06:a4', 6,
   'Ordena las lineas: definir la funcion, llamarla y mostrar el total.',
   'ordenar', '{"instruccion": "Primero definis, despues usas"}'::jsonb, 4),
  ('js:l06:a5', 6,
   'Uni cada pieza de codigo con lo que hace.',
   'relacionar',
   '{"columna_a": [{"id": "ped-let", "texto": "let visitas = 0"}, {"id": "ped-if", "texto": "if (visitas > 5) {}"}, {"id": "ped-func", "texto": "function sumar(a, b) {}"}, {"id": "ped-ret", "texto": "return a + b"}], "columna_b": [{"id": "hac-let", "texto": "Declarar una variable"}, {"id": "hac-if", "texto": "Decidir un caminillo"}, {"id": "hac-func", "texto": "Agrupar codigo reutilizable"}, {"id": "hac-ret", "texto": "Devolver un resultado"}]}'::jsonb,
   5),
  -- L7 Arrays y listas
  ('js:l07:a1', 7,
   E'Que imprime?\nconst notas = [8, 7, 9];\nconsole.log(notas[1]);',
   'seleccion', null, 1),
  ('js:l07:a2', 7,
   'Completa el codigo para saber cuantas frutas hay en la lista.',
   'completar_codigo',
   '{"codigo": "const frutas = [\"pera\", \"manzana\"];\nconst total = frutas.{b1};", "blancos": [{"clave": "b1", "valor": "length", "alternativas": [], "estricta": true}], "candidatos": ["length", "push", "pop", "count"]}'::jsonb,
   2),
  ('js:l07:a3', 7,
   'Ordena: crear la lista, ordenarla y mostrar su primer valor.',
   'ordenar', '{"instruccion": "Del dato inicial al primer elemento ordenado"}'::jsonb, 3),
  ('js:l07:a4', 7,
   'En un array, la primera posicion se marca con el indice 0.',
   'verdadero_falso', null, 4),
  ('js:l07:a5', 7,
   'Que metodo agrega un elemento al final de un array?',
   'completar_texto',
   '{"valor": "push", "alternativas": ["push();"]}'::jsonb, 5)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;
-- ACTIVIDADES JS: unidad 3 (Estructuras y datos, 3 lecciones x 7)
with lecciones_num as (
  select id, row_number() over (order by id) as n
  from lecciones
  where id between '30000000-0000-0000-0000-000000000001'::uuid
               and '30000000-0000-0000-0000-000000000010'::uuid
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:js:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- L8 Objetos
  ('js:l08:a1', 8,
   E'Que imprime?\nconst perro = { nombre: "Fury", edad: 3 };\nconsole.log(perro.edad);',
   'seleccion', null, 1),
  ('js:l08:a2', 8,
   'Completa la propiedad que mide cuanto dura la cancion.',
   'completar_codigo',
   '{"codigo": "const cancion = { titulo: \"Alma\", duracion: 210 };\nconsole.log(cancion.{b1});", "blancos": [{"clave": "b1", "valor": "duracion", "alternativas": [], "estricta": true}], "candidatos": ["duracion", "titulo", "length", "duración"]}'::jsonb,
   2),
  ('js:l08:a3', 8,
   'Ordena las lineas que arman un objeto usuario con nombre y nivel 12, y luego muestran el nivel.',
   'ordenar',
   '{"instruccion": "Crear el objeto vacio, sumar propiedades, mostrar el dato"}'::jsonb, 3),
  ('js:l08:a4', 8,
   'Como se recorren solo las llaves de un objeto?',
   'seleccion', null, 4),
  ('js:l08:a5', 8,
   'Completa el metodo que obtiene las llaves de un objeto.',
   'completar_codigo',
   '{"codigo": "const ventas = { enero: 10, febrero: 5, marzo: 20 };\nconst claves = Object.{b1}(ventas);", "blancos": [{"clave": "b1", "valor": "keys", "alternativas": [], "estricta": true}], "candidatos": ["keys", "values", "entries", "length"]}'::jsonb,
   5),
  ('js:l08:a6', 8,
   'En un objeto, no pueden existir dos propiedades con el mismo nombre.',
   'verdadero_falso', null, 6),
  ('js:l08:a7', 8,
   E'Que imprime este recorrido?\nconst notas = { julia: 9, bianca: 7 };\nfor (let clave in notas) {\n  console.log(clave);\n}',
   'seleccion', null, 7),
  -- L9 Cadenas de texto
  ('js:l09:a1', 9,
   E'Que imprime?\nconst texto = "Kodigo";\nconsole.log(texto.toUpperCase());',
   'seleccion', null, 1),
  ('js:l09:a2', 9,
   'Completa el metodo que quita los espacios de los extremos del mensaje.',
   'completar_codigo',
   '{"codigo": "const mensaje = \"   hola  \";\nconsole.log(mensaje.{b1});", "blancos": [{"clave": "b1", "valor": "trim", "alternativas": [], "estricta": true}], "candidatos": ["trim", "slice", "split", "replace"]}'::jsonb,
   2),
  ('js:l09:a3', 9,
   'Que devuelve la expresion "a,b,c".split(",")?',
   'seleccion', null, 3),
  ('js:l09:a4', 9,
   'Completa el metodo que pregunta si el texto contiene la parte "cur".',
   'completar_codigo',
   '{"codigo": "const aula = \"cursos\";\nif (aula.{b1}(\"cur\")) {\n  console.log(\"Se encontro\");\n}", "blancos": [{"clave": "b1", "valor": "includes", "alternativas": [], "estricta": true}], "candidatos": ["includes", "replace", "trim", "push"]}'::jsonb,
   4),
  ('js:l09:a5', 9,
   'Uni cada metodo con lo que hace.',
   'relacionar',
   '{"columna_a": [{"id": "met-may", "texto": "toUpperCase"}, {"id": "met-min", "texto": "toLowerCase"}, {"id": "met-trim", "texto": "trim"}, {"id": "met-split", "texto": "split"}], "columna_b": [{"id": "des-min", "texto": "Pasa todo a mayusculas"}, {"id": "des-may", "texto": "Pasa todo a minusculas"}, {"id": "des-trim", "texto": "Saca espacios de los extremos"}, {"id": "des-split", "texto": "Corta el texto en pedazos"}]}'::jsonb,
   5),
  ('js:l09:a6', 9,
   'Ordena las lineas que dividen un texto por espacios y muestran la segunda palabra.',
   'ordenar', '{"instruccion": "Del texto completo a la palabra elegida"}'::jsonb, 6),
  ('js:l09:a7', 9,
   '"ABC".toLowerCase() devuelve "abc".',
   'verdadero_falso', null, 7),
  -- L10 Proyecto: notas de clase
  ('js:l10:a1', 10,
   'Ordena el programa que calcula el total de las notas del array.',
   'ordenar', '{"instruccion": "De la preparacion del array hasta mostrar el total"}'::jsonb, 1),
  ('js:l10:a2', 10,
   'Completa la operacion para sumar cada nota al acumulador.',
   'completar_codigo',
   '{"codigo": "let total = 0;\nfor (let i = 0; i < notas.length; i++) {\n  total {b1}= notas[i];\n}", "blancos": [{"clave": "b1", "valor": "+", "alternativas": [], "estricta": true}], "candidatos": ["+", "-", "*", "%"]}'::jsonb,
   2),
  ('js:l10:a3', 10,
   E'Que imprime?\nconst notas = [100, 55, 72];\nnotas.push(60);\nconsole.log(notas.length);',
   'seleccion', null, 3),
  ('js:l10:a4', 10,
   'Uni cada herramienta con el problema que resuelve.',
   'relacionar',
   '{"columna_a": [{"id": "hrr-for", "texto": "for"}, {"id": "hrr-if", "texto": "if"}, {"id": "hrr-func", "texto": "funcion"}, {"id": "hrr-obj", "texto": "objeto"}], "columna_b": [{"id": "sol-for", "texto": "Repetir un cálculo por cada vuelta"}, {"id": "sol-if", "texto": "Elegir el camino según una condicion"}, {"id": "sol-func", "texto": "Reutilizar el mismo bloque de codigo"}, {"id": "sol-obj", "texto": "Guardar datos con nombres"}]}'::jsonb,
   4),
  ('js:l10:a5', 10,
   E'Que imprime?\nfunction contarAprobadas(notas) {\n  let pasan = 0;\n  for (let i = 0; i < notas.length; i++) {\n    if (notas[i] >= 7) {\n      pasan++;\n    }\n  }\n  return pasan;\n}\nconsole.log(contarAprobadas([7, 5, 9]));',
   'seleccion', null, 5),
  ('js:l10:a6', 10,
   'Un return corta la funcion completa, aunque este dentro de un for.',
   'verdadero_falso', null, 6),
  ('js:l10:a7', 10,
   'Completa el calculo del promedio de las notas.',
   'completar_codigo',
   '{"codigo": "const promedio = total {b1} notas.length;", "blancos": [{"clave": "b1", "valor": "/", "alternativas": [], "estricta": true}], "candidatos": ["+", "/", "*", "%"]}'::jsonb,
   7)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;
-- Opciones de seleccion / verdadero_falso / ordenar.
-- La posicion (orden) de la opcion correcta varia por pregunta.
insert into opciones (id, pregunta_id, texto, orden)
select
  uuid(md5('kodigo:opc:' || c.clave_preg || ':o' || c.opo)),
  p.id,
  c.texto,
  c.orden
from (values
  ('js:l01:a1', 1, 'let edad = 18;', 1),
  ('js:l01:a1', 2, 'edad = 18;', 2),
  ('js:l01:a1', 3, 'variable edad = 18;', 3),
  ('js:l01:a1', 4, 'let 18 = edad;', 4),
  ('js:l01:a3', 1, 'numero', 1),
  ('js:l01:a3', 2, 'string', 2),
  ('js:l01:a3', 3, 'booleano', 3),
  ('js:l01:a3', 4, 'undefined', 4),
  ('js:l01:a4', 1, 'Verdadero', 1),
  ('js:l01:a4', 2, 'Falso', 2),
  ('js:l02:a1', 1, '20', 1),
  ('js:l02:a1', 2, '14', 2),
  ('js:l02:a1', 3, '24', 3),
  ('js:l02:a1', 4, 'Error', 4),
  ('js:l02:a3', 1, 'Verdadero', 1),
  ('js:l02:a3', 2, 'Falso', 2),
  ('js:l02:a4', 1, 'let a = 2;', 1),
  ('js:l02:a4', 2, 'let b = a + 3;', 2),
  ('js:l02:a4', 3, 'let c = b * b;', 3),
  ('js:l02:a4', 4, 'console.log(c);', 4),
  ('js:l03:a1', 1, 'Es adulto', 1),
  ('js:l03:a1', 2, 'Menor', 2),
  ('js:l03:a1', 3, 'Las dos lineas', 3),
  ('js:l03:a1', 4, 'Error', 4),
  ('js:l03:a3', 1, 'Verdadero', 1),
  ('js:l03:a3', 2, 'Falso', 2),
  ('js:l04:a1', 1, '0 1 2 3', 1),
  ('js:l04:a1', 2, '0 1 2', 2),
  ('js:l04:a1', 3, '1 2 3', 3),
  ('js:l04:a1', 4, 'Solo 3', 4),
  ('js:l04:a3', 1, 'let suma = 0;', 1),
  ('js:l04:a3', 2, 'for (let i = 1; i <= 5; i++)', 2),
  ('js:l04:a3', 3, 'suma = suma + i;', 3),
  ('js:l04:a3', 4, 'console.log(suma);', 4),
  ('js:l04:a4', 1, 'Verdadero', 1),
  ('js:l04:a4', 2, 'Falso', 2),
  ('js:l04:a5', 1, '9', 1),
  ('js:l04:a5', 2, '10', 2),
  ('js:l04:a5', 3, '11', 3),
  ('js:l04:a5', 4, 'Infinitas', 4),
  ('js:l05:a1', 1, '5 4 3', 1),
  ('js:l05:a1', 2, '5 4', 2),
  ('js:l05:a1', 3, '5 4 3 2', 3),
  ('js:l05:a1', 4, '3 2 1', 4),
  ('js:l05:a3', 1, 'let saldo = 100;', 1),
  ('js:l05:a3', 2, 'while (saldo > 30) {', 2),
  ('js:l05:a3', 3, 'saldo = saldo - 10;', 3),
  ('js:l05:a3', 4, '}', 4),
  ('js:l05:a4', 1, 'Falta un console.log', 1),
  ('js:l05:a4', 2, 'La condicion es siempre verdadera', 2),
  ('js:l05:a4', 3, 'Hola no es un numero', 3),
  ('js:l05:a4', 4, 'Falta cerrar la llave', 4),
  ('js:l05:a5', 1, 'continue', 1),
  ('js:l05:a5', 2, 'continue;', 2),
  ('js:l06:a1', 1, '5', 1),
  ('js:l06:a1', 2, '10', 2),
  ('js:l06:a1', 3, '20', 3),
  ('js:l06:a1', 4, 'Error', 4),
  ('js:l06:a3', 1, 'Verdadero', 1),
  ('js:l06:a3', 2, 'Falso', 2),
  ('js:l06:a4', 1, 'function sumar(a, b) { return a + b; }', 1),
  ('js:l06:a4', 2, 'let total = sumar(3, 4);', 2),
  ('js:l06:a4', 3, 'console.log(total);', 3),
  ('js:l07:a1', 1, '8', 1),
  ('js:l07:a1', 2, '7', 2),
  ('js:l07:a1', 3, '9', 3),
  ('js:l07:a1', 4, 'undefined', 4),
  ('js:l07:a3', 1, 'let numeros = [5, 3, 1];', 1),
  ('js:l07:a3', 2, 'numeros.sort();', 2),
  ('js:l07:a3', 3, 'console.log(numeros[0]);', 3),
  ('js:l07:a4', 1, 'Verdadero', 1),
  ('js:l07:a4', 2, 'Falso', 2),
  ('js:l08:a1', 1, 'Fury', 1),
  ('js:l08:a1', 2, '3', 2),
  ('js:l08:a1', 3, 'undefined', 3),
  ('js:l08:a1', 4, 'Error', 4),
  ('js:l08:a3', 1, 'let usuario = {};', 1),
  ('js:l08:a3', 2, 'usuario.nombre = "Ana";', 2),
  ('js:l08:a3', 3, 'usuario.nivel = 12;', 3),
  ('js:l08:a3', 4, 'console.log(usuario.nivel);', 4),
  ('js:l08:a4', 1, 'objeto.keys()', 1),
  ('js:l08:a4', 2, 'for (let clave in objeto)', 2),
  ('js:l08:a4', 3, 'Object.values(objeto)', 3),
  ('js:l08:a4', 4, 'objeto.forEach(clave)', 4),
  ('js:l08:a6', 1, 'Verdadero', 1),
  ('js:l08:a6', 2, 'Falso', 2),
  ('js:l08:a7', 1, '9 7', 1),
  ('js:l08:a7', 2, 'julia y bianca', 2),
  ('js:l08:a7', 3, 'Solo julia', 3),
  ('js:l08:a7', 4, 'Error', 4),
  ('js:l09:a1', 1, 'kodigo', 1),
  ('js:l09:a1', 2, 'KODIGO', 2),
  ('js:l09:a1', 3, 'Kodigo', 3),
  ('js:l09:a1', 4, 'undefined', 4),
  ('js:l09:a3', 1, 'Un string "a b c"', 1),
  ('js:l09:a3', 2, 'El numero 3', 2),
  ('js:l09:a3', 3, 'Una lista ["a", "b", "c"]', 3),
  ('js:l09:a3', 4, 'true', 4),
  ('js:l09:a6', 1, 'let texto = "hola mundo";', 1),
  ('js:l09:a6', 2, 'let pedazos = texto.split(" ");', 2),
  ('js:l09:a6', 3, 'console.log(pedazos[1]);', 3),
  ('js:l09:a7', 1, 'Verdadero', 1),
  ('js:l09:a7', 2, 'Falso', 2),
  ('js:l10:a1', 1, 'let notas = [10, 6, 8, 9, 5];', 1),
  ('js:l10:a1', 2, 'let total = 0;', 2),
  ('js:l10:a1', 3, 'for (let i = 0; i < notas.length; i++) {', 3),
  ('js:l10:a1', 4, 'total = total + notas[i];', 4),
  ('js:l10:a1', 5, '}', 5),
  ('js:l10:a1', 6, 'console.log(total);', 6),
  ('js:l10:a3', 1, '3', 1),
  ('js:l10:a3', 2, '4', 2),
  ('js:l10:a3', 3, '235', 3),
  ('js:l10:a3', 4, '60', 4),
  ('js:l10:a5', 1, '3', 1),
  ('js:l10:a5', 2, '2', 2),
  ('js:l10:a5', 3, '9', 3),
  ('js:l10:a5', 4, '1', 4),
  ('js:l10:a6', 1, 'Verdadero', 1),
  ('js:l10:a6', 2, 'Falso', 2)
) as c(clave_preg, opo, texto, orden)
join preguntas p on p.id = uuid(md5('kodigo:preg:js:' || c.clave_preg))
on conflict (id) do nothing;

-- Soluciones: correcta por opcion exacta en seleccion / verdadero_falso.
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion)
select
  uuid(md5('kodigo:sol:' || s.clave_preg)),
  p.id,
  o.id,
  s.explicacion
from (values
  ('js:l01:a1', 'let edad = 18;',
   'let declara la variable con nombre edad y le asigna el valor 18. Otras formas fallan por sintaxis o porque mezclan el valor con el nombre.'),
  ('js:l01:a3', 'string',
   '"Julia" esta entre comillas: eso es un texto, un string.'),
  ('js:l01:a4', 'Verdadero',
   'let permite reasignar: const es la que lo impide.'),
  ('js:l02:a1', '14',
   'Primero se evalua la multiplicacion (3 * 4 = 12) y despues la suma (2 + 12 = 14).'),
  ('js:l02:a3', 'Verdadero',
   '% es el modulo: devuelve lo que sobra al dividir.'),
  ('js:l03:a1', 'Menor',
   'edad es 15, y 15 >= 18 es falso: entra por el else.'),
  ('js:l03:a3', 'Falso',
   'Si la condicion no se cumple y no hay else, el if no ejecuta nada.'),
  ('js:l04:a1', '0 1 2',
   'Empieza en 0 y con i < 3 imprime 0, 1 y 2 (cuando llega a 3 el bucle corta).'),
  ('js:l04:a4', 'Verdadero',
   'let tiene alcance de bloque: i muere al terminar el bucle.'),
  ('js:l04:a5', '10',
   'El cuerpo corre mientras i va de 0 a 9: diez vueltas.'),
  ('js:l05:a1', '5 4',
   'Imprime 5 y 4; cuando n llega a 3, la condicion ya no se cumple.'),
  ('js:l05:a4', 'La condicion es siempre verdadera',
   'while (true) nunca sera falso: es un bucle infinito.'),
  ('js:l06:a1', '10',
   'doble(5) devuelve 5 * 2 = 10.'),
  ('js:l06:a3', 'Verdadero',
   'Las variables internas de una funcion son locales.'),
  ('js:l07:a1', '7',
   'El indice 1 es la segunda posicion: 7.'),
  ('js:l08:a1', '3',
   'perro.edad guarda el numero 3. El nombre es Fury.'),
  ('js:l08:a4', 'for (let clave in objeto)',
   'for...in recorre las llaves: en cada vuelta clave es el nombre de una propiedad.'),
  ('js:l08:a7', 'julia y bianca',
   'for...in recorre las llaves del objeto: imprime los nombres de las personas, no sus notas.'),
  ('js:l09:a1', 'KODIGO',
   'toUpperCase devuelve el texto en mayusculas: KODIGO.'),
  ('js:l09:a3', 'Una lista ["a", "b", "c"]',
   'split(",") corta el texto por las comas y devuelve un array de tres pedazos.'),
  ('js:l10:a3', '4',
   'El array tenia 3 notas y push agrego una: length da 4.'),
  ('js:l10:a5', '2',
   'En [7, 5, 9] solo 7 y 9 cumplen notas[i] >= 7: pasan 2. (La de 5 no cuenta. La funcion devuelve el conteo, no las notas.)')
) as s(clave_preg, correcta, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:js:' || s.clave_preg))
join opciones o on o.texto = s.correcta and o.pregunta_id = p.id
on conflict (pregunta_id) do nothing;
-- Soluciones que quedaron de las preguntas vf de la unidad 3 y L7.
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion)
select
  uuid(md5('kodigo:sol:' || s.clave_preg)),
  p.id,
  o.id,
  s.explicacion
from (values
  ('js:l07:a4', 'Verdadero',
   'Los arrays empiezan a contar desde 0: la primera posicion es el indice 0.'),
  ('js:l08:a6', 'Verdadero',
   'Si repetis el nombre de la propiedad, el primer valor se pisaria con el segundo.'),
  ('js:l09:a7', 'Verdadero',
   'toLowerCase devuelve el texto completo en minusculas.'),
  ('js:l10:a6', 'Verdadero',
   'return corta la ejecucion de la funcion entera y devuelve un valor.')
) as s(clave_preg, correcta, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:js:' || s.clave_preg))
join opciones o on o.texto = s.correcta and o.pregunta_id = p.id
on conflict (pregunta_id) do nothing;
-- Soluciones de ordenar: la secuencia correcta esAhora el orden natural
-- de las opciones de la pregunta (o1..oN tal como se cargaron).
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:ordenar:' || e.clave_preg)),
  p.id,
  jsonb_build_object('orden', (
    select jsonb_agg(o.id order by o.orden)
    from opciones o
    where o.pregunta_id = p.id
  )),
  e.explicacion
from (values
  ('js:l02:a4', 'Orden correcto: declarar a, calcular b, calcular c y mostrarla en consola.'),
  ('js:l04:a3', 'Orden correcto: preparar el acumulador, recorrer de 1 a 5, sumar en cada vuelta y mostrar el resultado final.'),
  ('js:l05:a3', 'Orden correcto: iniciar el saldo 100, el While sigue mientras haya mas de 30, resta 10 en el cuerpo y se cierra la llave.'),
  ('js:l06:a4', 'Orden correcto: definir la funcion, llamarla guardando el resultado y mostrar ese total.'),
  ('js:l07:a3', 'Orden correcto: crear la lista, ordenarla con sort y mostrar el primer valor, que queda 1.'),
  ('js:l08:a3', 'Orden correcto: crear el objeto vacio, asignar nombre y nivel, y mostrar el nivel al final.'),
  ('js:l09:a6', 'Orden correcto: guardar el texto, partirlo por espacios y mostrar el segundo pedazo: mundo.'),
  ('js:l10:a1', 'Orden correcto: crear el array de notas, preparar el total, recorrer el array, sumar cada nota, cerrar el bucle y mostrar el total.')
) as e(clave_preg, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:js:' || e.clave_preg))
on conflict (pregunta_id) do nothing;
-- Soluciones de completar_texto / completar_codigo: la respuesta correcta
-- vive en datos de la pregunta; Solutions guarda {:.jsonb} y la explicacion.
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:texto:' || e.clave_preg)),
  p.id,
  e.solucion,
  e.explicacion
from (values
  ('js:l01:a2', '{}'::jsonb, 'La palabra const declara un valor que no se puede reasignar. let declara variables que si se pueden cambiar.'),
  ('js:l05:a5', '{}'::jsonb, 'continue salta a la siguiente vuelta del bucle. break corta el bucle entero, no es lo mismo.'),
  ('js:l07:a5', '{}'::jsonb, 'push agrega al final del array. pop saca el ultimo, shift el primero.'),
  ('js:l02:a2', '{}'::jsonb, 'El operador % (modulo) devuelve el resto: 10 % 3 da 1, al sobrar 1.'),
  ('js:l03:a2', '{}'::jsonb, '=== compara valor y tipo al mismo tiempo. 8 === 8 es verdadero; "8" === 8 no lo seria.'),
  ('js:l04:a2', '{}'::jsonb, 'Con i <= 10 el cuerpo corre hasta i = 10: suma 1 + 2 + ... + 10 = 55. Con la < seria hasta 9.'),
  ('js:l05:a2', '{}'::jsonb, 'Para contar hacia abajo desde 3 la condicion tiene que dejar de cumplirse cuando llegue a 0: contador > 0.'),
  ('js:l06:a2', '{}'::jsonb, 'La palabra return devuelve el calculo lado * lado. Cualquier otra palabra rompiaria la sintaxis de la funcion.'),
  ('js:l07:a2', '{}'::jsonb, 'length es una propiedad de los arrays: cuantos elementos tiene. push/pop si agregan o sacan.'),
  ('js:l08:a2', '{}'::jsonb, 'La propiedad se llama duracion, en minusculas y sin acentos: cancion.duracion.'),
  ('js:l08:a5', '{}'::jsonb, 'Object.keys(sistema) devuelve un array con sus llaves: enero, febrero, marzo.'),
  ('js:l09:a2', '{}'::jsonb, 'trim recorta los espacios de ambos lados: "   hola  " queda "hola".'),
  ('js:l09:a4', '{}'::jsonb, 'includes pregunta si el texto contiene la subcadena: "cursos".includes("cur") es verdadero.'),
  ('js:l10:a2', '{}'::jsonb, 'La operacion suma: total += notas[i] equivale a total = total + notas[i].'),
  ('js:l10:a7', '{}'::jsonb, 'El promedio es el total dividido la cantidad de notas: usar /.')
) as e(clave_preg, solucion, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:js:' || e.clave_preg))
on conflict (pregunta_id) do nothing;

-- Soluciones de relacionar: los pares correctos con los ids de datos.
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:relacionar:' || e.clave_preg)),
  p.id,
  e.solucion,
  e.explicacion
from (values
  ('js:l03:a4',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'op-mayor', 'id_b', 'sg-mayor'),
     jsonb_build_object('id_a', 'op-menor', 'id_b', 'sg-menor'),
     jsonb_build_object('id_a', 'op-estricto', 'id_b', 'sg-estricto'),
     jsonb_build_object('id_a', 'op-negar', 'id_b', 'sg-negar'))),
   'Cada operador compara de una forma distinta: > mayor, < menor, === igual arranque de tipob, ! invierte una condicion.'),
  ('js:l06:a5',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'ped-let', 'id_b', 'hac-let'),
     jsonb_build_object('id_a', 'ped-if', 'id_b', 'hac-if'),
     jsonb_build_object('id_a', 'ped-func', 'id_b', 'hac-func'),
     jsonb_build_object('id_a', 'ped-ret', 'id_b', 'hac-ret'))),
   'let declara datos, if decide caminos, una function agrupa codigo reutilizable y return devuelve un valor.'),
  ('js:l09:a5',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'met-may', 'id_b', 'des-min'),
     jsonb_build_object('id_a', 'met-min', 'id_b', 'des-may'),
     jsonb_build_object('id_a', 'met-trim', 'id_b', 'des-trim'),
     jsonb_build_object('id_a', 'met-split', 'id_b', 'des-split'))),
   'toUpperCase pasa a mayusculas, toLowerCase a minusculas, trim recorta espacios y split corta el texto en partes.'),
  ('js:l10:a4',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'hrr-for', 'id_b', 'sol-for'),
     jsonb_build_object('id_a', 'hrr-if', 'id_b', 'sol-if'),
     jsonb_build_object('id_a', 'hrr-func', 'id_b', 'sol-func'),
     jsonb_build_object('id_a', 'hrr-obj', 'id_b', 'sol-obj'))),
   'for repite, if decide, la funcion agrupa y reutiliza, y el objeto guarda datos con nombres.')
) as e(clave_preg, solucion, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:js:' || e.clave_preg))
on conflict (pregunta_id) do nothing;
-- ===========================================================================
-- Cursor nuevo: HTML (10 lecciones, 53 actividades, 4/5/7)
-- ===========================================================================

insert into cursos (
    id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion
)
values (
    '10000000-0000-0000-0000-000000000002'::uuid,
    'HTML',
    'Estructura la web: etiquetas, listas, formularios y semantica real.',
    'La estructura de la web',
    'HT',
    'htmlLogo',
    '#e34f26',
    2,
    'publicado'
) on conflict (id) do nothing;

-- Unidades: la primera publica, el resto se desbloquea al aprobar las anteriores.

insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values
(
  uuid(md5('kodigo:unidad:html:u1')),
  '10000000-0000-0000-0000-000000000002'::uuid,
  'Estructura y texto',
  'Aprende como se arma un documento HTML y escribe texto de verdad.',
  1,
  'publicado'
),
(
  uuid(md5('kodigo:unidad:html:u2')),
  '10000000-0000-0000-0000-000000000002'::uuid,
  'Interactividad',
  'Formularios, imagenes, semantica y tablas para organizar contenido.',
  2,
  'bloqueada'
),
(
  uuid(md5('kodigo:unidad:html:u3')),
  '10000000-0000-0000-0000-000000000002'::uuid,
  'Detalle y proyecto',
  'Atributos, accesibilidad y un proyecto de cierre que une todo.',
  3,
  'bloqueada'
) on conflict (id) do update
  set nombre = excluded.nombre,
      descripcion = excluded.descripcion,
      orden = excluded.orden,
      estado_publicacion = excluded.estado_publicacion;

-- Lecciones: 10 con orden 1..10 repartidas por la unidad que corresponde.

insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values
(
  uuid(md5('kodigo:leccion:html:l01')),
  uuid(md5('kodigo:unidad:html:u1')),
  'El documento HTML',
  'Un documento HTML declara que es HTML5 y se divide en head (datos del sitio) y body (lo que se ve).',
  E'<!DOCTYPE html>\n<html lang="es">\n  <head>\n    <title>Kodigo</title>\n  </head>\n  <body>\n    <h1>Hola</h1>\n  </body>\n</html>',
  1,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l02')),
  uuid(md5('kodigo:unidad:html:u1')),
  'Etiquetas de texto',
  'Las etiquetas marcan que la pagina puede representarse bien: encabezados, parrafos y cerramientos.',
  E'<h1>Kodigo</h1>\n<p>Aprendamos algo nuevo</p>',
  2,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l03')),
  uuid(md5('kodigo:unidad:html:u1')),
  'Listas y enlaces',
  'Las listas agrupan items (ul sin orden, ol con orden) y los enlaces navegan con href.',
  E'<ul>\n  <li>Primer paso</li>\n  <li>Segundo paso</li>\n</ul>\n<a href="https://kodigo.org">Visita Kodigo</a>',
  3,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l04')),
  uuid(md5('kodigo:unidad:html:u2')),
  'Formularios',
  'Un form guarda campos: inputs con type, labels con for y un boton de envio.',
  E'<form action="/login">\n  <label for="usuario">Usuario</label>\n  <input id="usuario" type="text">\n  <button type="submit">Entrar</button>\n</form>',
  4,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l05')),
  uuid(md5('kodigo:unidad:html:u2')),
  'Imagenes',
  'La etiqueta img muestra una imagen con src (ubicacion) y alt (descripcion de lectura).',
  E'<img src="perro.png" alt="Perro Essen">',
  5,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l06')),
  uuid(md5('kodigo:unidad:html:u2')),
  'Etiquetas semanticas',
  'nav, main, article, aside y footer dan significado a las partes de la pagina.',
  E'<nav>\n  <a href="/">Inicio</a>\n</nav>\n<main>\n  <article>\n    <h1>Noticias</h1>\n  </article>\n</main>',
  6,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l07')),
  uuid(md5('kodigo:unidad:html:u2')),
  'Tablas',
  'Las tablas ordenan datos en filas (tr) y celdas (td): th marca los encabezados.',
  E'<table>\n  <tr><th>Nombre</th><th>Edad</th></tr>\n  <tr><td>Ana</td><td>18</td></tr>\n</table>',
  7,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l08')),
  uuid(md5('kodigo:unidad:html:u3')),
  'Atributos y clases',
  'id identifica un elemento, class agrupa muchos y data-* guarda datos propios.',
  E'<button id="enviar" class="principal">Enviar</button>',
  8,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l09')),
  uuid(md5('kodigo:unidad:html:u3')),
  'Formularios avanzados',
  'El campo pedido: type de cada dato (email, number), label accesible y placeholder.',
  E'<label for="email">Email</label>\n<input id="email" type="email" placeholder="tu@correo.com" required>',
  9,
  'publicado'
),
(
  uuid(md5('kodigo:leccion:html:l10')),
  uuid(md5('kodigo:unidad:html:u3')),
  'Proyecto: perfil de mascota',
  'Cierra el curso con una pagina completa: estructura, texto, imagen y formulario.',
  E'<main>\n  <section>\n    <h1>Rocky</h1>\n    <img src="rocky.jpg" alt="Rocky">\n    <p>Le encanta la parrilla</p>\n  </section>\n</main>',
  10,
  'publicado'
) on conflict (id) do nothing;


-- ACTIVIDADES HTML: unidad 1 (Estructura y texto, 3 lecciones x 4)
with lecciones_num as (
  select id,
         case id
           when uuid(md5('kodigo:leccion:html:l01')) then 1
           when uuid(md5('kodigo:leccion:html:l02')) then 2
           when uuid(md5('kodigo:leccion:html:l03')) then 3
         end as n
  from lecciones
  where id in (
    uuid(md5('kodigo:leccion:html:l01')),
    uuid(md5('kodigo:leccion:html:l02')),
    uuid(md5('kodigo:leccion:html:l03'))
  )
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:html:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- L1 El documento HTML
  ('html:l01:a1', 1,
   'Que etiqueta guarda el titulo que se muestra en la pestana del navegador?',
   'seleccion', null, 1),
  ('html:l01:a2', 1,
   'Que valor del atributo lang declara que la pagina esta escrita en espanol?',
   'completar_texto',
   '{"valor": "es", "alternativas": ["es-ES", "es-AR"]}'::jsonb, 2),
  ('html:l01:a3', 1,
   'Que linea declara que el documento usa HTML5?',
   'seleccion', null, 3),
  ('html:l01:a4', 1,
   'Todo documento HTML tiene una parte head (datos del sitio) y una body (lo que se ve).',
   'verdadero_falso', null, 4),
  -- L2 Etiquetas de texto
  ('html:l02:a1', 2,
   'Que etiqueta marca el titulo principal del contenido de la pagina?',
   'seleccion', null, 1),
  ('html:l02:a2', 2,
   'Completa la etiqueta para que el texto quede en un parrafo.',
   'completar_codigo',
   '{"codigo": "<{b1}>Aprendemos HTML</{b1}>", "blancos": [{"clave": "b1", "valor": "p", "alternativas": [], "estricta": true}], "candidatos": ["p", "div", "text", "t"]}'::jsonb,
   2),
  ('html:l02:a3', 2,
   'La etiqueta que se abre con <p> se cierra con </p>, y la barra indica el cierre.',
   'verdadero_falso', null, 3),
  ('html:l02:a4', 2,
   'Ordena las lineas para armar un cuerpo de documento con un titulo y un parrafo.',
   'ordenar', '{"instruccion": "Tal como vive en el HTML"}'::jsonb, 4),
  -- L3 Listas y enlaces
  ('html:l03:a1', 3,
   'Que etiqueta crea una lista donde el orden de los items no importa?',
   'seleccion', null, 1),
  ('html:l03:a2', 3,
   'Completa el enlace para que apunte al sitio de Kodigo.',
   'completar_codigo',
   '{"codigo": "<a {b1}=\"https://kodigo.org\">Visita Kodigo</a>", "blancos": [{"clave": "b1", "valor": "href", "alternativas": [], "estricta": true}], "candidatos": ["href", "src", "link", "target"]}'::jsonb,
   2),
  ('html:l03:a3', 3,
   'El enlace href="#" salta al tope de la misma pagina.',
   'verdadero_falso', null, 3),
  ('html:l03:a4', 3,
   'Que valor del atributo target abre el enlace en una pestana nueva?',
   'completar_texto',
   '{"valor": "_blank", "alternativas": ["blank"]}'::jsonb, 4)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;


-- ACTIVIDADES HTML: unidad 2 (Interactividad, 4 lecciones x 5)
with lecciones_num as (
  select id,
         case id
           when uuid(md5('kodigo:leccion:html:l04')) then 1
           when uuid(md5('kodigo:leccion:html:l05')) then 2
           when uuid(md5('kodigo:leccion:html:l06')) then 3
           when uuid(md5('kodigo:leccion:html:l07')) then 4
         end as n
  from lecciones
  where id in (
    uuid(md5('kodigo:leccion:html:l04')),
    uuid(md5('kodigo:leccion:html:l05')),
    uuid(md5('kodigo:leccion:html:l06')),
    uuid(md5('kodigo:leccion:html:l07'))
  )
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:html:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- L4 Formularios
  ('html:l04:a1', 1,
   'En una encuesta se elige un solo correo entre varios. Que type de input corresponde?',
   'seleccion', null, 1),
  ('html:l04:a2', 1,
   'Ordena el formulario de ingreso con su campo y el boton de envio.',
   'ordenar', '{"instruccion": "El orden en que vive en el HTML"}'::jsonb, 2),
  ('html:l04:a3', 1,
   'Completa el checkbox para que aparezca tildado al cargar la pagina.',
   'completar_codigo',
   '{"codigo": "<input type=\"checkbox\" {b1}>", "blancos": [{"clave": "b1", "valor": "checked", "alternativas": [], "estricta": true}], "candidatos": ["checked", "selected", "required", "tildado"]}'::jsonb,
   3),
  ('html:l04:a4', 1,
   'El atributo required obliga al navegador a validar el campo antes de enviar el formulario.',
   'verdadero_falso', null, 4),
  ('html:l04:a5', 1,
   'Que etiqueta agrupa todos los campos de un formulario?',
   'completar_texto',
   '{"valor": "form", "alternativas": ["<form>"]}'::jsonb, 5),
  -- L5 Imagenes
  ('html:l05:a1', 2,
   E'Si perro.png no carga, que texto ve el usuario?\n<img src="perro.png" alt="Perro Essen">',
   'seleccion', null, 1),
  ('html:l05:a2', 2,
   'Completa la imagen para que cargue el archivo perro.png.',
   'completar_codigo',
   '{"codigo": "<img {b1}=\"perro.png\" alt=\"Perro\">", "blancos": [{"clave": "b1", "valor": "src", "alternativas": [], "estricta": true}], "candidatos": ["src", "href", "link", "data"]}'::jsonb,
   2),
  ('html:l05:a3', 2,
   'La etiqueta img no tiene cierre porque no envuelve contenido.',
   'verdadero_falso', null, 3),
  ('html:l05:a4', 2,
   'Ordena los pedazos para armar la etiqueta de la imagen.',
   'ordenar', '{"instruccion": "De la apertura al cierre"}'::jsonb, 4),
  ('html:l05:a5', 2,
   'Que atributo de la imagen describe su contenido para lectores de pantalla?',
   'completar_texto',
   '{"valor": "alt", "alternativas": []}'::jsonb, 5),
  -- L6 Etiquetas semanticas
  ('html:l06:a1', 3,
   'Que etiqueta envuelve el menu de navegacion del sitio?',
   'seleccion', null, 1),
  ('html:l06:a2', 3,
   'Ordena las secciones de una pagina de arriba hacia abajo.',
   'ordenar', '{"instruccion": "La estructura tipica de una pagina"}'::jsonb, 2),
  ('html:l06:a3', 3,
   'Relaciona cada etiqueta con su papel en la pagina.',
   'relacionar',
   '{"columna_a": [{"id": "sem-nav", "texto": "<nav>"}, {"id": "sem-article", "texto": "<article>"}, {"id": "sem-aside", "texto": "<aside>"}, {"id": "sem-footer", "texto": "<footer>"}], "columna_b": [{"id": "rol-nav", "texto": "El menu de enlaces del sitio"}, {"id": "rol-article", "texto": "Un contenido que vale por si solo"}, {"id": "rol-aside", "texto": "La informacion al costado del tema"}, {"id": "rol-footer", "texto": "El pie con creditos y contactos"}], "instruccion": "Toca una etiqueta y luego su papel"}'::jsonb,
   3),
  ('html:l06:a4', 3,
   'La etiqueta div describe el significado de su contenido.',
   'verdadero_falso', null, 4),
  ('html:l06:a5', 3,
   'Completa la etiqueta que envuelve el contenido principal de la pagina.',
   'completar_codigo',
   '{"codigo": "<{b1}>\n  <h1>Bienvenidos</h1>\n</{b1}>", "blancos": [{"clave": "b1", "valor": "main", "alternativas": [], "estricta": true}], "candidatos": ["main", "head", "title", "aside"]}'::jsonb,
   5),
  -- L7 Tablas
  ('html:l07:a1', 4,
   'En una tabla, que etiqueta marca una fila?',
   'seleccion', null, 1),
  ('html:l07:a2', 4,
   'Completa la fila de datos de la tabla.',
   'completar_codigo',
   '{"codigo": "<table>\n  <tr><th>Nombre</th><th>Edad</th></tr>\n  <{b1}><td>Ana</td><td>18</td></{b1}>\n</table>", "blancos": [{"clave": "b1", "valor": "tr", "alternativas": [], "estricta": true}], "candidatos": ["tr", "td", "th", "tabla"]}'::jsonb,
   2),
  ('html:l07:a3', 4,
   'La etiqueta th marca las celdas que hacen de encabezado de la tabla.',
   'verdadero_falso', null, 3),
  ('html:l07:a4', 4,
   'Ordena la tabla con su encabezado y una fila de datos.',
   'ordenar', '{"instruccion": "Del contenedor hacia los datos"}'::jsonb, 4),
  ('html:l07:a5', 4,
   'Relaciona cada parte de la tabla con su papel.',
   'relacionar',
   '{"columna_a": [{"id": "tab-thead", "texto": "<thead>"}, {"id": "tab-tbody", "texto": "<tbody>"}, {"id": "tab-tfoot", "texto": "<tfoot>"}, {"id": "tab-caption", "texto": "<caption>"}], "columna_b": [{"id": "rol-thead", "texto": "La fila de encabezados"}, {"id": "rol-tbody", "texto": "El cuerpo con los datos"}, {"id": "rol-tfoot", "texto": "Los totales del pie"}, {"id": "rol-caption", "texto": "El titulo de la tabla"}], "instruccion": "Toca una etiqueta y luego su papel"}'::jsonb,
   5)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;


-- ACTIVIDADES HTML: unidad 3 (Detalle y proyecto, 3 lecciones x 7)
with lecciones_num as (
  select id,
         case id
           when uuid(md5('kodigo:leccion:html:l08')) then 1
           when uuid(md5('kodigo:leccion:html:l09')) then 2
           when uuid(md5('kodigo:leccion:html:l10')) then 3
         end as n
  from lecciones
  where id in (
    uuid(md5('kodigo:leccion:html:l08')),
    uuid(md5('kodigo:leccion:html:l09')),
    uuid(md5('kodigo:leccion:html:l10'))
  )
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:html:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- L8 Atributos y clases
  ('html:l08:a1', 1,
   'Que atributo identifica un elemento unico en toda la pagina?',
   'seleccion', null, 1),
  ('html:l08:a2', 1,
   'Que atributo agrupa varios elementos para que compartan el mismo estilo?',
   'completar_texto',
   '{"valor": "class", "alternativas": []}'::jsonb, 2),
  ('html:l08:a3', 1,
   'Completa el atributo data para guardar en que paso del tutorial esta el visitante.',
   'completar_codigo',
   '{"codigo": "<li data-{b1}=\"1\">Paso actual</li>", "blancos": [{"clave": "b1", "valor": "paso", "alternativas": [], "estricta": true}], "candidatos": ["paso", "name", "id", "class"]}'::jsonb,
   3),
  ('html:l08:a4', 1,
   'Ordena los pedazos del boton con sus atributos.',
   'ordenar', '{"instruccion": "De la etiqueta a los atributos y al contenido"}'::jsonb, 4),
  ('html:l08:a5', 1,
   E'Que logra el atributo en este enlace?\n<a href="/docs">Documentacion</a>',
   'seleccion', null, 5),
  ('html:l08:a6', 1,
   'El id puede repetirse en la misma pagina, pero class no.',
   'verdadero_falso', null, 6),
  ('html:l08:a7', 1,
   'Completa el id de la tarjeta del sitio.',
   'completar_codigo',
   '{"codigo": "<div class=\"tarjeta\" id=\"tarjeta-{b1}\">Contenido</div>", "blancos": [{"clave": "b1", "valor": "principal", "alternativas": [], "estricta": true}], "candidatos": ["principal", "class", "id", "tarjeta"]}'::jsonb,
   7),
  -- L9 Formularios avanzados
  ('html:l09:a1', 2,
   'Completa el input para que pida un correo electronico con su formato validado.',
   'completar_codigo',
   '{"codigo": "<label for=\"email\">Email</label>\n<input id=\"email\" type=\"{b1}\">", "blancos": [{"clave": "b1", "valor": "email", "alternativas": [], "estricta": true}], "candidatos": ["email", "text", "password", "number"]}'::jsonb,
   1),
  ('html:l09:a2', 2,
   E'En un campo <input type="number" min="1" max="10"> el usuario escribe 0. Que pasa?',
   'seleccion', null, 2),
  ('html:l09:a3', 2,
   'Ordena el par accesible: el texto del label y el campo al que apunta.',
   'ordenar', '{"instruccion": "Juntando el control con su texto"}'::jsonb, 3),
  ('html:l09:a4', 2,
   'Para que sirve el atributo for de un label?',
   'seleccion', null, 4),
  ('html:l09:a5', 2,
   E'Completa el input para mostrar la ayuda "Escribe tu nombre".',
   'completar_codigo',
   '{"codigo": "<input type=\"text\" {b1}=\"Escribe tu nombre\">", "blancos": [{"clave": "b1", "valor": "placeholder", "alternativas": [], "estricta": true}], "candidatos": ["placeholder", "alt", "value", "title"]}'::jsonb,
   5),
  ('html:l09:a6', 2,
   'Con type="password" los caracteres escritos se tapan con puntos o asteriscos.',
   'verdadero_falso', null, 6),
  ('html:l09:a7', 2,
   'Que atributo del label lo conecta con el campo cuyo id es email?',
   'completar_texto',
   '{"valor": "for", "alternativas": []}'::jsonb, 7),
  -- L10 Proyecto: perfil de mascota
  ('html:l10:a1', 3,
   'Ordena la pagina del perfil: estructura, titulo, foto y descripcion.',
   'ordenar', '{"instruccion": "Armando la pagina completa"}'::jsonb, 1),
  ('html:l10:a2', 3,
   'Completa la fila de datos del historial medico del perfil.',
   'completar_codigo',
   '{"codigo": "<table>\n  <tr><th>Nombre</th><th>Edad</th></tr>\n  <{b1}><td>Rocky</td><td>2</td></{b1}>\n</table>", "blancos": [{"clave": "b1", "valor": "tr", "alternativas": [], "estricta": true}], "candidatos": ["tr", "td", "th", "tabla"]}'::jsonb,
   2),
  ('html:l10:a3', 3,
   'Que logra el enlace <a href="mailto:contacto@kodigo.org">Contacto</a>?',
   'seleccion', null, 3),
  ('html:l10:a4', 3,
   'Relaciona la etiqueta con el rol que cumple en la pagina del perfil.',
   'relacionar',
   '{"columna_a": [{"id": "per-h1", "texto": "<h1>"}, {"id": "per-p", "texto": "<p>"}, {"id": "per-ol", "texto": "<ol>"}, {"id": "per-a", "texto": "<a>"}], "columna_b": [{"id": "rol-h1", "texto": "El titulo principal"}, {"id": "rol-p", "texto": "El parrafo de descripcion"}, {"id": "rol-ol", "texto": "La lista numerada de vacunas"}, {"id": "rol-a", "texto": "El enlace al turnero"}], "instruccion": "Toca una etiqueta y luego su papel"}'::jsonb,
   4),
  ('html:l10:a5', 3,
   'Completa el contenedor que agrupa las fotos del album.',
   'completar_codigo',
   '{"codigo": "<{b1} class=\"galeria\">\n  <img src=\"foto1.jpg\" alt=\"Foto uno\">\n  <img src=\"foto2.jpg\" alt=\"Foto dos\">\n</{b1}>", "blancos": [{"clave": "b1", "valor": "div", "alternativas": [], "estricta": true}], "candidatos": ["div", "ol", "form", "option"]}'::jsonb,
   5),
  ('html:l10:a6', 3,
   'El elemento datalist ofrece opciones predefinidas para completar un input.',
   'verdadero_falso', null, 6),
  ('html:l10:a7', 3,
   'Que etiqueta marca un texto con importancia fuerte?',
   'seleccion', null, 7)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;


-- Opciones HTML: seleccion, verdadero_falso y los elementos de ordenar.
-- La posicion de la correcta varIa por pregunta; en ordenar es el orden natural.
insert into opciones (id, pregunta_id, texto, orden)
select
  uuid(md5('kodigo:opc:html:' || c.clave_preg || ':o' || c.opo)),
  p.id,
  c.texto,
  c.orden
from (values
  ('html:l01:a1', 1, '<head>', 1),
  ('html:l01:a1', 2, '<title>', 2),
  ('html:l01:a1', 3, '<meta>', 3),
  ('html:l01:a1', 4, '<h1>', 4),
  ('html:l01:a3', 1, '<doctype html5>', 1),
  ('html:l01:a3', 2, '<HTML5>', 2),
  ('html:l01:a3', 3, '<!DOCTYPE html>', 3),
  ('html:l01:a3', 4, '<html5>', 4),
  ('html:l01:a4', 1, 'Verdadero', 1),
  ('html:l01:a4', 2, 'Falso', 2),
  ('html:l02:a1', 1, '<h6>', 1),
  ('html:l02:a1', 2, '<title>', 2),
  ('html:l02:a3', 1, 'Verdadero', 1),
  ('html:l02:a3', 2, 'Falso', 2),
  ('html:l02:a1', 3, '<h1>', 3),
  ('html:l02:a1', 4, '<header>', 4),
  ('html:l02:a4', 1, '<body>', 1),
  ('html:l02:a4', 2, '<h1>Kodigo</h1>', 2),
  ('html:l02:a4', 3, '<p>Nuestro primer parrafo</p>', 3),
  ('html:l02:a4', 4, '</body>', 4),
  ('html:l03:a1', 1, '<ol>', 1),
  ('html:l03:a1', 2, '<li>', 2),
  ('html:l03:a1', 3, '<ul>', 3),
  ('html:l03:a1', 4, '<list>', 4),
  ('html:l03:a3', 1, 'Verdadero', 1),
  ('html:l03:a3', 2, 'Falso', 2),
  ('html:l04:a1', 1, 'checkbox', 1),
  ('html:l04:a1', 2, 'text', 2),
  ('html:l04:a1', 3, 'radio', 3),
  ('html:l04:a1', 4, 'email', 4),
  ('html:l04:a2', 1, '<form action="/login">', 1),
  ('html:l04:a2', 2, '<input type="text" name="usuario">', 2),
  ('html:l04:a2', 3, '<button type="submit">Entrar</button>', 3),
  ('html:l04:a2', 4, '</form>', 4),
  ('html:l04:a4', 1, 'Verdadero', 1),
  ('html:l04:a4', 2, 'Falso', 2),
  ('html:l05:a1', 1, 'No ve nada', 1),
  ('html:l05:a1', 2, 'perro.png', 2),
  ('html:l05:a1', 3, 'Un icono roto', 3),
  ('html:l05:a1', 4, 'Perro Essen', 4),
  ('html:l05:a3', 1, 'Verdadero', 1),
  ('html:l05:a3', 2, 'Falso', 2),
  ('html:l05:a4', 1, '<img', 1),
  ('html:l05:a4', 2, 'src="logo.png"', 2),
  ('html:l05:a4', 3, 'alt="Logo de Kodigo"', 3),
  ('html:l05:a4', 4, '/>', 4),
  ('html:l06:a1', 1, '<aside>', 1),
  ('html:l06:a1', 2, '<nav>', 2),
  ('html:l06:a1', 3, '<main>', 3),
  ('html:l06:a1', 4, '<article>', 4),
  ('html:l06:a2', 1, '<header>', 1),
  ('html:l06:a2', 2, '<nav>', 2),
  ('html:l06:a2', 3, '<main>', 3),
  ('html:l06:a2', 4, '<footer>', 4),
  ('html:l06:a4', 1, 'Verdadero', 1),
  ('html:l06:a4', 2, 'Falso', 2),
  ('html:l07:a1', 1, '<td>', 1),
  ('html:l07:a1', 2, '<table>', 2),
  ('html:l07:a1', 3, '<th>', 3),
  ('html:l07:a1', 4, '<tr>', 4),
  ('html:l07:a3', 1, 'Verdadero', 1),
  ('html:l07:a3', 2, 'Falso', 2),
  ('html:l07:a4', 1, '<table>', 1),
  ('html:l07:a4', 2, '<tr><th>Nota</th></tr>', 2),
  ('html:l07:a4', 3, '<tr><td>8</td></tr>', 3),
  ('html:l07:a4', 4, '</table>', 4),
  ('html:l08:a1', 1, 'class', 1),
  ('html:l08:a1', 2, 'name', 2),
  ('html:l08:a1', 3, 'id', 3),
  ('html:l08:a1', 4, 'data-id', 4),
  ('html:l08:a4', 1, '<button', 1),
  ('html:l08:a4', 2, 'id="enviar"', 2),
  ('html:l08:a4', 3, 'class="principal"', 3),
  ('html:l08:a4', 4, '>Enviar</button>', 4),
  ('html:l08:a5', 1, 'Abre la pagina /docs del mismo sitio', 1),
  ('html:l08:a5', 2, 'Cambia el color del enlace', 2),
  ('html:l08:a5', 3, 'Crea un id para el enlace', 3),
  ('html:l08:a5', 4, 'Escribe /docs en la pantalla', 4),
  ('html:l08:a6', 1, 'Verdadero', 1),
  ('html:l08:a6', 2, 'Falso', 2),
  ('html:l09:a2', 1, 'Se envia igual', 1),
  ('html:l09:a2', 2, 'Se borra el campo', 2),
  ('html:l09:a2', 3, 'El navegador rechaza el valor al enviar', 3),
  ('html:l09:a2', 4, 'Se cambian los limites', 4),
  ('html:l09:a3', 1, '<label for="email">', 1),
  ('html:l09:a3', 2, 'Correo</label>', 2),
  ('html:l09:a3', 3, '<input id="email" type="email">', 3),
  ('html:l09:a4', 1, 'Marca el campo como obligatorio', 1),
  ('html:l09:a4', 2, 'Asocia el texto con el campo cuyo id coincide', 2),
  ('html:l09:a4', 3, 'Define el tipo de dato del campo', 3),
  ('html:l09:a4', 4, 'Le pone color al texto', 4),
  ('html:l09:a6', 1, 'Verdadero', 1),
  ('html:l09:a6', 2, 'Falso', 2),
  ('html:l10:a1', 1, '<main>', 1),
  ('html:l10:a1', 2, '<section>', 2),
  ('html:l10:a1', 3, '<h1>Rocky</h1>', 3),
  ('html:l10:a1', 4, '<img src="rocky.jpg" alt="Rocky">', 4),
  ('html:l10:a1', 5, '<p>Le encantan los huesos</p>', 5),
  ('html:l10:a1', 6, '</section>', 6),
  ('html:l10:a1', 7, '</main>', 7),
  ('html:l10:a3', 1, 'Carga la pagina /contacto', 1),
  ('html:l10:a3', 2, 'Descarga un archivo de contacto', 2),
  ('html:l10:a3', 3, 'Abre una pestana nueva', 3),
  ('html:l10:a3', 4, 'Abre el programa de correo para escribir a contacto@kodigo.org', 4),
  ('html:l10:a6', 1, 'Verdadero', 1),
  ('html:l10:a6', 2, 'Falso', 2),
  ('html:l10:a7', 1, '<bold>', 1),
  ('html:l10:a7', 2, '<b>', 2),
  ('html:l10:a7', 3, '<strong>', 3),
  ('html:l10:a7', 4, '<em>', 4)
) as c(clave_preg, opo, texto, orden)
join preguntas p on p.id = uuid(md5('kodigo:preg:html:' || c.clave_preg))
on conflict (id) do nothing;


-- Soluciones HTML: correcta por texto de opcion en seleccion / verdadero_falso.
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion)
select
  uuid(md5('kodigo:sol:html:' || s.clave_preg)),
  p.id,
  o.id,
  s.explicacion
from (values
  ('html:l01:a1', '<title>', 'El elemento title, dentro de head, define el texto que se ve en la pestana del navegador.'),
  ('html:l01:a3', '<!DOCTYPE html>', 'La declaracion de HTML5 es <!DOCTYPE html> y va sola, al inicio del archivo.'),
  ('html:l01:a4', 'Verdadero', 'head guarda metadatos como el title; body guarda todo lo que se ve.'),
  ('html:l02:a1', '<h1>', 'h1 es el encabezado mas importante del contenido; header es una seccion estructural, no un titulo.'),
  ('html:l02:a3', 'Verdadero', 'La barra del cierre cierra la etiqueta: <p> abre y </p> cierra.'),
  ('html:l03:a1', '<ul>', 'ul es la lista sin orden; ol es la numera.'),
  ('html:l03:a3', 'Verdadero', 'El enlace con href="#" salta al tope del documento.'),
  ('html:l04:a1', 'radio', 'radio deja elegir una sola opcion del grupo; checkbox permite varias.'),
  ('html:l04:a4', 'Verdadero', 'required le pide al navegador que valide el campo antes de enviar los datos.'),
  ('html:l05:a1', 'Perro Essen', 'El texto de alt reemplaza a la imagen cuando no se puede mostrar, y lo leen los lectores de pantalla.'),
  ('html:l05:a3', 'Verdadero', 'img es una etiqueta vacia: trae la imagen, no envuelve texto.'),
  ('html:l06:a1', '<nav>', 'nav marca el bloque de enlaces de navegacion principal.'),
  ('html:l06:a4', 'Falso', 'div es un contenedor generico sin significado; para significar algo hay etiquetas semanticas.'),
  ('html:l07:a1', '<tr>', 'tr (table row) arma la fila; dentro van las celdas td.'),
  ('html:l07:a3', 'Verdadero', 'th marca las celdas de encabezado de cada columna.'),
  ('html:l08:a1', 'id', 'El id identifica un elemento unico; class agrupa muchos.'),
  ('html:l08:a5', 'Abre la pagina /docs del mismo sitio', 'El atributo href apunta a /docs y el navegador navega a esa ruta del sitio.'),
  ('html:l08:a6', 'Falso', 'Al reves: el id es unico en la pagina y la class puede repetirse.'),
  ('html:l09:a2', 'El navegador rechaza el valor al enviar', 'min delimita el valor minimo aceptado: el navegador avisa y frena el envio.'),
  ('html:l09:a4', 'Asocia el texto con el campo cuyo id coincide', 'for="email" conecta el label con el input de id email: clic en el texto enfoca el campo.'),
  ('html:l09:a6', 'Verdadero', 'El navegador tapa los caracteres con puntos o asteriscos en el campo tipo password.'),
  ('html:l10:a3', 'Abre el programa de correo para escribir a contacto@kodigo.org', 'El esquema mailto: prepara un correo nuevo con ese destinatario.'),
  ('html:l10:a6', 'Verdadero', 'El datalist lista sugerencias y el input las ofrece al usuario que escribe.')
  ('html:l10:a7', '<strong>', 'strong da importancia semantica; <b> es solo estilo visual y <em> es enfasis.')
) as s(clave_preg, correcta, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:html:' || s.clave_preg))
join opciones o on o.texto = s.correcta and o.pregunta_id = p.id
on conflict (pregunta_id) do nothing;

-- Soluciones HTML de ordenar: la secuencia correcta es el orden natural
-- de las opciones tal como se cargaron (o1..oN).
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:html:ordenar:' || e.clave_preg)),
  p.id,
  jsonb_build_object('orden', (
    select jsonb_agg(o.id order by o.orden)
    from opciones o
    where o.pregunta_id = p.id
  )),
  e.explicacion
from (values
  ('html:l02:a4', 'Orden correcto: abrir el body, el titulo, el parrafo y cerrar el body.'),
  ('html:l04:a2', 'Orden correcto: el form envuelve el campo de texto y el boton de envio.'),
  ('html:l05:a4', 'Orden correcto: abrir la etiqueta img, el src, el alt y cerrarla.'),
  ('html:l06:a2', 'Orden correcto: el encabezado, el menu, el contenido principal y el pie.'),
  ('html:l07:a4', 'Orden correcto: la tabla, la fila de encabezado th, la fila de datos td y el cierre.'),
  ('html:l08:a4', 'Orden correcto: la etiqueta, sus atributos id y class, y el contenido del boton.'),
  ('html:l09:a3', 'Orden correcto: el label con su texto y luego el campo al que apunta.'),
  ('html:l10:a1', 'Orden correcto: el main, la seccion del perfil con titulo, foto y descripcion, y los cierres.')
) as e(clave_preg, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:html:' || e.clave_preg))
on conflict (pregunta_id) do nothing;

-- Soluciones HTML de completar_texto / completarCodigo: la correcta vive en datos.
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:html:texto:' || e.clave_preg)),
  p.id,
  e.solucion,
  e.explicacion
from (values
  ('html:l01:a2', '{}'::jsonb, 'lang usa el codigo del idioma: es para espanol, y tolera region como es-AR.'),
  ('html:l03:a4', '{}'::jsonb, 'target="_blank" abre el enlace en una pestana nueva.'),
  ('html:l04:a5', '{}'::jsonb, 'form envuelve los campos y los envia con action.'),
  ('html:l05:a5', '{}'::jsonb, 'alt es la descripcion accesible de la imagen: imprescindible para lectores de pantalla.'),
  ('html:l08:a2', '{}'::jsonb, 'class puede usarse en cuantos elementos se quiera para compartir estilo.'),
  ('html:l09:a7', '{}'::jsonb, 'El label apunta al campo con for, cuyo valor coincide con el id.')
) as e(clave_preg, solucion, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:html:' || e.clave_preg))
on conflict (pregunta_id) do nothing;


-- Soluciones HTML de completar_codigo: la respuesta vive en datos de la pregunta.
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:html:texto:' || e.clave_preg)),
  p.id,
  e.solucion,
  e.explicacion
from (values
  ('html:l02:a2', '{}'::jsonb, 'Los parrafos se marcan con <p> y se cierran con </p>: la misma etiqueta con la barra.'),
  ('html:l03:a2', '{}'::jsonb, 'El destino del enlace va en el atributo href de la etiqueta <a>.'),
  ('html:l04:a3', '{}'::jsonb, 'El atributo booleano checked deja la casilla tildada desde el arranque, sin valor.'),
  ('html:l05:a2', '{}'::jsonb, 'La ubicacion del archivo de imagen va en el atributo src.'),
  ('html:l06:a5', '{}'::jsonb, 'main encierra el contenido principal: existe una sola vez por pagina.'),
  ('html:l07:a2', '{}'::jsonb, 'Cada fila de datos es un tr que envuelve sus celdas td.'),
  ('html:l08:a3', '{}'::jsonb, 'Los atributos data-* guardan datos propios del elemento: data-paso="1".'),
  ('html:l08:a7', '{}'::jsonb, 'El id queda como tarjeta-principal: el nombre se completa con el valor del hueco.'),
  ('html:l09:a1', '{}'::jsonb, 'type="email" deja que el navegador valide el formato del correo.'),
  ('html:l09:a5', '{}'::jsonb, 'placeholder muestra la marca de agua con la ayuda de escritura.'),
  ('html:l10:a2', '{}'::jsonb, 'Cada fila de datos del historial es un tr con sus celdas td.'),
  ('html:l10:a5', '{}'::jsonb, 'div agrupa las imagenes en el bloque de galeria.')
) as e(clave_preg, solucion, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:html:' || e.clave_preg))
on conflict (pregunta_id) do nothing;


-- Soluciones HTML de relacionar: los pares correctos con los ids de datos.
insert into soluciones (id, pregunta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:relacionar:' || e.clave_preg)),
  p.id,
  e.solucion,
  e.explicacion
from (values
  ('html:l06:a3',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'sem-nav', 'id_b', 'rol-nav'),
     jsonb_build_object('id_a', 'sem-article', 'id_b', 'rol-article'),
     jsonb_build_object('id_a', 'sem-aside', 'id_b', 'rol-aside'),
     jsonb_build_object('id_a', 'sem-footer', 'id_b', 'rol-footer'))),
   'nav agrupa el menu, article un contenido independiente, aside lo lateral y footer el pie de pagina.'),
  ('html:l07:a5',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'tab-thead', 'id_b', 'rol-thead'),
     jsonb_build_object('id_a', 'tab-tbody', 'id_b', 'rol-tbody'),
     jsonb_build_object('id_a', 'tab-tfoot', 'id_b', 'rol-tfoot'),
     jsonb_build_object('id_a', 'tab-caption', 'id_b', 'rol-caption'))),
   'thead encabeza la tabla, tbody guarda los datos, tfoot los totales y caption la titula.'),
  ('html:l10:a4',
   jsonb_build_object('pares', jsonb_build_array(
     jsonb_build_object('id_a', 'per-h1', 'id_b', 'rol-h1'),
     jsonb_build_object('id_a', 'per-p', 'id_b', 'rol-p'),
     jsonb_build_object('id_a', 'per-ol', 'id_b', 'rol-ol'),
     jsonb_build_object('id_a', 'per-a', 'id_b', 'rol-a'))),
   'h1 titula el perfil, p describe a la mascota, ol enumera las vacunas en orden y a lleva al turnero.')
) as e(clave_preg, solucion, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:html:' || e.clave_preg))
on conflict (pregunta_id) do nothing;
