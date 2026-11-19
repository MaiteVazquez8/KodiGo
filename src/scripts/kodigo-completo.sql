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
        'relacionar',
        'escribir_codigo',
        'corregir_codigo',
        'salida_codigo',
        'predecir',
        'bloques',
        'robot'
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

-- Solo una lección 'publicado' se puede practicar. 'bloqueada' sigue siendo
-- visible para listar el contenido, pero el servidor no acepta intentar
-- resolverla: asi el desbloqueo no depende solo de la interfaz.
-- Una leccion se puede practicar si esta publicada y si su unidad esta
-- publicada para todos o desbloqueada para ESTE usuario. El estado global de
-- la unidad no se modifica al avanzar: el desbloqueo vive en progreso_unidades.
create or replace function es_leccion_publicada(p_leccion_id uuid)
returns boolean
language plpgsql
stable
security invoker
set search_path = public
as $$
begin
    return exists (
        select 1
        from lecciones l
        join unidades u on u.id = l.unidad_id
        where l.id = p_leccion_id
          and l.estado_publicacion = 'publicado'
          and u.estado_publicacion in ('publicado', 'bloqueada')
          and (
              u.estado_publicacion = 'publicado'
              or exists (
                  select 1
                  from progreso_unidades pu
                  where pu.usuario_id = auth.uid()
                    and pu.unidad_id = u.id
              )
          )
    );
end;
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
    -- Regla general de aprobacion: al menos la mitad de las actividades correctas,
    -- con redondeo hacia arriba. Ejemplos: 3 -> 2, 4 -> 2, 5 -> 3, 6 -> 3, 7 -> 4.
    aprobado := completado and v_correctas >= ceiling(v_total::numeric * 1 / 2)::integer;

    return next;
end;
$$;

-- Desbloqueo individual: cuando todas las lecciones publicadas de la unidad
-- actual del usuario quedan aprobadas, se registra la unidad como completada
-- y se habilita la siguiente SOLO para ese usuario en progreso_unidades. No se
-- toca el estado editorial global de la unidad.
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
    v_orden integer;
    v_unidad_siguiente uuid;
begin
    select l.unidad_id, u.curso_id, u.orden
    into v_unidad_actual, v_curso, v_orden
    from lecciones l
    join unidades u on u.id = l.unidad_id
    where l.id = p_leccion_id;

    if v_unidad_actual is null then
        return;
    end if;

    -- Mientras falte una leccion publicada de la unidad actual no se
    -- desbloquea la siguiente.
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

    insert into progreso_unidades (usuario_id, unidad_id, completada_en)
    values (p_usuario_id, v_unidad_actual, now())
    on conflict (usuario_id, unidad_id) do update
        set completada_en = coalesce(progreso_unidades.completada_en, excluded.completada_en);

    select u.id into v_unidad_siguiente
    from unidades u
    where u.curso_id = v_curso
      and u.orden > v_orden
      and u.estado_publicacion in ('publicado', 'bloqueada')
    order by u.orden
    limit 1;

    if v_unidad_siguiente is not null then
        insert into progreso_unidades (usuario_id, unidad_id)
        values (p_usuario_id, v_unidad_siguiente)
        on conflict (usuario_id, unidad_id) do nothing;
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

    -- Serializa los cierres de este usuario: dos finalizaciones concurrentes
    -- sobre dos intentos distintos de la misma leccion no pueden evaluar a la
    -- vez el gate de primera aprobacion.
    perform 1 from perfiles where id = v_usuario for update;

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
        update perfiles set experiencia = experiencia + v_xp,
            nivel = nivel_por_experiencia(experiencia + v_xp),
            updated_at = now()
        where id = v_usuario;

        if not found then
            raise exception 'El perfil del usuario todavia no esta disponible';
        end if;

        update intentos set xp_ganado = v_xp where id = p_intento_id;
    else
        select i.xp_ganado into v_xp from intentos i where i.id = p_intento_id;
    end if;

    -- Racha diaria real: se actualiza al cerrar cualquier intento, no solo al
    -- aprobar. Un dia sin actividad la reinicia en 1 al volver.
    update perfiles
    set racha_dias = case
            when ultima_actividad_en = current_date then racha_dias
            when ultima_actividad_en = current_date - 1 then racha_dias + 1
            else 1
        end,
        ultima_actividad_en = current_date,
        updated_at = now()
    where id = v_usuario;

    if v_resumen.aprobado then
        perform desbloquear_siguiente_unidad(v_usuario, v_leccion);
    end if;

    -- Los logros se evaluan al cerrar el intento porque dependen de datos que
    -- recien ahora quedaron persistidos (lecciones, unidades, respuestas).
    perform evaluar_logros(v_usuario);

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

revoke all on function iniciar_intento(uuid, uuid) from public;

revoke all on function registrar_respuesta(uuid, uuid, uuid) from public;

revoke all on function finalizar_intento(uuid) from public;

revoke all on function obtener_progreso() from public;

revoke all on function cantidad_preguntas_publicadas(uuid) from public;

revoke all on function es_leccion_publicada(uuid) from public;

revoke all on function recalcular_intento(uuid) from public;

-- La sobrecarga comprobar_respuesta(uuid, jsonb) recien se define en el
-- bloque ETAPA 8 (al final del script). Sus permisos se otorgan ahi.

revoke all on function registrar_respuesta(uuid, uuid, jsonb) from public;

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
    -- La restriccion definitiva se re-agrega en el bloque ETAPA 8 con los once
    -- tipos. No se re-agrega aca: en una re-aplicacion sobre una base con
    -- tipos ampliados, validar filas existentes contra solo seis tipos falla.

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
    'Creá tus primeros programas en el lenguaje más usado del mundo.',
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
)
on conflict (id) do nothing;

insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values
(
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Variables y asignación',
    'Una variable guarda un valor para reutilizarlo después. En JavaScript usamos let para declarar una variable y luego le asignamos un valor.',
    E'let nombre = "Ana";\nlet edad = 18;\nconsole.log(nombre);\nconsole.log(edad);',
    1,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'Operadores y cálculo',
    'Los operadores permiten combinar valores y hacer cálculos. La suma, resta, multiplicación y división son las operaciones más comunes.',
    E'let precio = 10;\nlet cantidad = 3;\nlet total = precio * cantidad;\nconsole.log(total);',
    2,
    'publicado'
)
on conflict (id) do nothing;

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
-- Lecciones JavaScript que faltaban en el seed (003 a 007)
-- El seed original insertaba 001, 002, 008, 009 y 010 y actualizaba textos de
-- 003..007 sin haberlas creado; por eso el curso arrancaba incompleto.
-- Inserta exactamente las cinco faltantes. Idempotente.
-- ===========================================================================
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values
(
    '30000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    'Condicionales con if',
    'Con if y else, el programa ejecuta un bloque solo cuando la condicion se cumple. El operador === compara valor y tipo al mismo tiempo.',
    E'const edad = 15;\nif (edad >= 18) {\n  console.log("Es adulto");\n} else {\n  console.log("Menor");\n}',
    3,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000004',
    '20000000-0000-0000-0000-000000000002',
    'Bucles for',
    'Un bucle for tiene tres partes: valor inicial, condicion de continuacion y paso. El cuerpo corre en cada vuelta mientras la condicion sea verdadera.',
    E'let suma = 0;\nfor (let i = 1; i <= 5; i++) {\n  suma = suma + i;\n}\nconsole.log(suma);',
    1,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000002',
    'Bucles while',
    'El bucle while repite mientras la condicion sea verdadera. Sin un cambio que la vuelva falsa, el bucle no termina nunca.',
    E'let contador = 3;\nwhile (contador > 0) {\n  console.log(contador);\n  contador = contador - 1;\n}\nconsole.log("Despegue");',
    2,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000002',
    'Funciones',
    'Una funcion agrupa codigo para reutilizarlo: recibe parametros, hace su trabajo y devuelve un resultado con return.',
    E'function doble(x) {\n  return x * 2;\n}\nconsole.log(doble(5));',
    3,
    'publicado'
),
(
    '30000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000002',
    'Arrays y listas',
    'Un array guarda una lista de valores con indices: el primero es la posicion 0. length dice cuantos elementos tiene y push agrega al final.',
    E'const frutas = ["pera", "manzana"];\nconsole.log(frutas[0]);\nconsole.log(frutas.length);',
    4,
    'publicado'
)
on conflict (id) do nothing;

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

-- Limpieza de la vieja curricula de JavaScript: elimina las unidades JS
-- antiguas que no son las tres actuales. Sólo afecta al curso de
-- JavaScript; las unidades generadas por md5 (HTML, ExpoTécnica) quedan.
delete from unidades
where curso_id = '10000000-0000-0000-0000-000000000001'::uuid
  and id <> all (array[
    '20000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000003'::uuid
  ]);

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

-- ===========================================================================
-- 20. Reparacion del seed de JavaScript (leccion_id de las preguntas)
--
-- La primera vez que se aplico el seed faltaban lecciones (003..007), por
-- lo que las preguntas de esas lecciones se asociaron a las equivocadas o
-- directamente no se insertaron. Este bloque las reasocia al estado
-- correcto. Es idempotente: en bases frescas es un no-op.
-- ===========================================================================

with mapa(prefijo, clave, leccion) as (values
  ('js2', 'js2:l01:a1', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js2', 'js2:l01:a2', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js2', 'js2:l01:a3', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js2', 'js2:l02:a1', '30000000-0000-0000-0000-000000000002'::uuid),
  ('js2', 'js2:l02:a2', '30000000-0000-0000-0000-000000000002'::uuid),
  ('js2', 'js2:l03:a1', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js2', 'js2:l03:a2', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js2', 'js2:l03:a3', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js2', 'js2:l04:a1', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js2', 'js2:l04:a2', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js2', 'js2:l05:a1', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js2', 'js2:l05:a2', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js2', 'js2:l06:a1', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js2', 'js2:l06:a2', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js2', 'js2:l07:a1', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js2', 'js2:l07:a2', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js2', 'js2:l08:a1', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js2', 'js2:l08:a2', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js2', 'js2:l09:a1', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js2', 'js2:l09:a2', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js2', 'js2:l09:a3', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js2', 'js2:l10:a1', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js2', 'js2:l10:a2', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l01:a1', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js', 'js:l01:a2', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js', 'js:l01:a3', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js', 'js:l01:a4', '30000000-0000-0000-0000-000000000001'::uuid),
  ('js', 'js:l02:a1', '30000000-0000-0000-0000-000000000002'::uuid),
  ('js', 'js:l02:a2', '30000000-0000-0000-0000-000000000002'::uuid),
  ('js', 'js:l02:a3', '30000000-0000-0000-0000-000000000002'::uuid),
  ('js', 'js:l02:a4', '30000000-0000-0000-0000-000000000002'::uuid),
  ('js', 'js:l03:a1', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js', 'js:l03:a2', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js', 'js:l03:a3', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js', 'js:l03:a4', '30000000-0000-0000-0000-000000000003'::uuid),
  ('js', 'js:l04:a1', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js', 'js:l04:a2', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js', 'js:l04:a3', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js', 'js:l04:a4', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js', 'js:l04:a5', '30000000-0000-0000-0000-000000000004'::uuid),
  ('js', 'js:l05:a1', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js', 'js:l05:a2', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js', 'js:l05:a3', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js', 'js:l05:a4', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js', 'js:l05:a5', '30000000-0000-0000-0000-000000000005'::uuid),
  ('js', 'js:l06:a1', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js', 'js:l06:a2', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js', 'js:l06:a3', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js', 'js:l06:a4', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js', 'js:l06:a5', '30000000-0000-0000-0000-000000000006'::uuid),
  ('js', 'js:l07:a1', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js', 'js:l07:a2', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js', 'js:l07:a3', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js', 'js:l07:a4', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js', 'js:l07:a5', '30000000-0000-0000-0000-000000000007'::uuid),
  ('js', 'js:l08:a1', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l08:a2', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l08:a3', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l08:a4', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l08:a5', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l08:a6', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l08:a7', '30000000-0000-0000-0000-000000000008'::uuid),
  ('js', 'js:l09:a1', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l09:a2', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l09:a3', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l09:a4', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l09:a5', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l09:a6', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l09:a7', '30000000-0000-0000-0000-000000000009'::uuid),
  ('js', 'js:l10:a1', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l10:a2', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l10:a3', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l10:a4', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l10:a5', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l10:a6', '30000000-0000-0000-0000-000000000010'::uuid),
  ('js', 'js:l10:a7', '30000000-0000-0000-0000-000000000010'::uuid)
)
update preguntas p
set leccion_id = m.leccion
from mapa m
where p.id = uuid(md5('kodigo:preg:' || m.prefijo || ':' || m.clave))
  and p.leccion_id <> m.leccion;

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
  ('html:l10:a6', 'Verdadero', 'El datalist lista sugerencias y el input las ofrece al usuario que escribe.'),
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

-- ===========================================================================
-- Etapa 7: Desafio ExpoTecnica (eventos, cuestionario competitivo, Core
-- Defender, ranking publico y panel de administracion).
--
-- Contrato del sistema:
--   * El evento es la unidad de competencia (ExpoTecnica 2026, 2027, ...).
--     Cada evento tiene su propio desafio, sus partidas y su ranking; nunca
--     se mezclan rankings de eventos distintos.
--   * El desafio se congela cuando se crea la primera partida
--     (expotec_desafios.congelado_en): mientras exista una sola partida no se
--     puede cambiar preguntas, puntajes ni reglas. Cada partida guarda ademas
--     una copia vigente de las reglas en config_snapshot.
--   * Las preguntas y opciones se asignan con orden aleatorio en el servidor
--     al crear la partida y quedan guardadas (expotec_preguntas_asignadas):
--     recargar la pagina no cambia el cuestionario.
--   * Todo el puntaje oficial se calcula y persiste en el servidor mediante
--     funciones SECURITY DEFINER. Las tablas nuevas no tienen politicas de
--     INSERT/UPDATE/DELETE: el cliente solo puede leer lo suyo y ejecutar RPC.
--   * El alias es identificador publico con unicidad por evento a nivel de
--     base de datos (case-insensitive). Nunca es mecanismo de autenticacion:
--     la identidad real es auth.uid() (invitados incluidos, con la sesion
--     anonima de Supabase de alcance limitado).
--   * El ranking oficial con sus desempates vive en expotec_ranking() y la
--     tabla publica minima para tiempo real es expotec_resultados_publicos.
--   * Cada partida pertenece a un grupo (tanda). Reiniciar el ranking
--     deshabilita los intentos cerrados y pasa los que estan en curso al
--     grupo siguiente; rehabilitar un grupo recupera sus partidas sin borrarlas.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Tablas del sistema de eventos
-- ---------------------------------------------------------------------------

create table if not exists expotec_eventos (
    id uuid primary key default gen_random_uuid(),
    nombre varchar(120) not null,
    descripcion text,
    fecha_inicio timestamptz,
    fecha_fin timestamptz,
    estado varchar(20) not null default 'borrador',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint expotec_eventos_estado_check check (estado in ('borrador', 'programado', 'activo', 'cerrado')),
    constraint expotec_eventos_fechas_check check (
        fecha_inicio is null or fecha_fin is null or fecha_inicio <= fecha_fin
    )
);

create table if not exists expotec_desafios (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null unique references expotec_eventos(id) on delete cascade,
    nombre varchar(120) not null,
    version integer not null default 1,
    cantidad_preguntas integer not null default 10,
    puntos_por_correcta integer not null default 100,
    tiempo_cuestionario_seg integer,
    duracion_juego_seg integer not null default 180,
    vidas_juego integer not null default 3,
    intentos_permitidos integer not null default 1,
    mostrar_soluciones boolean not null default true,
    congelado_en timestamptz,
    created_at timestamptz not null default now(),
    constraint expotec_desafios_cantidad_check check (cantidad_preguntas between 1 and 50),
    constraint expotec_desafios_puntos_check check (puntos_por_correcta >= 0),
    constraint expotec_desafios_tiempo_check check (tiempo_cuestionario_seg is null or tiempo_cuestionario_seg between 30 and 7200),
    constraint expotec_desafios_duracion_check check (duracion_juego_seg between 20 and 900),
    constraint expotec_desafios_vidas_check check (vidas_juego between 1 and 10),
    constraint expotec_desafios_intentos_check check (intentos_permitidos between 1 and 20)
);

-- Preguntas seleccionadas para el desafio. La FK a preguntas es restrict:
-- una pregunta usada en un desafio no se puede borrar, solo despublicar.
create table if not exists expotec_desafio_preguntas (
    id uuid primary key default gen_random_uuid(),
    desafio_id uuid not null references expotec_desafios(id) on delete cascade,
    pregunta_id uuid not null references preguntas(id) on delete restrict,
    orden integer not null default 0,
    constraint expotec_desafio_preguntas_orden_check check (orden >= 0),
    constraint expotec_desafio_preguntas_unica unique (desafio_id, pregunta_id),
    constraint expotec_desafio_preguntas_posicion_unique unique (desafio_id, orden)
);

create table if not exists expotec_participantes (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references expotec_eventos(id) on delete cascade,
    usuario_id uuid not null references perfiles(id) on delete cascade,
    alias varchar(40) not null,
    alias_normalizado varchar(40) not null,
    created_at timestamptz not null default now(),
    constraint expotec_participantes_evento_alias_unique unique (evento_id, alias_normalizado)
);
create index if not exists expotec_participantes_evento_idx on expotec_participantes (evento_id);
create index if not exists expotec_participantes_usuario_idx on expotec_participantes (usuario_id);

create table if not exists expotec_partidas (
    id uuid primary key default gen_random_uuid(),
    evento_id uuid not null references expotec_eventos(id) on delete cascade,
    desafio_id uuid not null references expotec_desafios(id) on delete cascade,
    participante_id uuid not null references expotec_participantes(id) on delete cascade,
    usuario_id uuid not null references perfiles(id) on delete cascade,
    alias varchar(40) not null,
    estado varchar(30) not null default 'creada',
    -- Tanda (grupo) a la que pertenece el intento. Al reiniciar el ranking se
    -- deshabilita el grupo actual y los intentos en curso pasan al siguiente.
    grupo integer not null default 1,
    -- Estado previo de una partida deshabilitada: permite devolverla a
    -- 'finalizada', 'vencida' o 'abandonada' sin inventar un estado nuevo.
    estado_anterior varchar(30),
    config_snapshot jsonb not null,
    iniciado_at timestamptz not null default now(),
    vencimiento_at timestamptz,
    cuestionario_completado_at timestamptz,
    finalizado_at timestamptz,
    tiempo_cuestionario_seg numeric(10,2),
    correctas integer not null default 0,
    incorrectas integer not null default 0,
    respondidas integer not null default 0,
    puntaje_cuestionario integer not null default 0,
    puntaje_juego integer not null default 0,
    puntaje_total integer generated always as (puntaje_cuestionario + puntaje_juego) stored,
    created_at timestamptz not null default now(),
    constraint expotec_partidas_estado_check check (estado in (
        'creada', 'en_cuestionario', 'cuestionario_completado',
        'en_juego', 'finalizada', 'vencida', 'abandonada',
        -- Un administrador puede deshabilitar una partida para sacar a un
        -- participante del ranking sin borrar sus datos: el estado vuelve
        -- a 'finalizada' al rehabilitar.
        'deshabilitada'
    )),
    constraint expotec_partidas_cerrada_check check (
        finalizado_at is null or estado in ('finalizada', 'vencida', 'abandonada', 'deshabilitada')
    ),
    constraint expotec_partidas_grupo_check check (grupo >= 1),
    constraint expotec_partidas_estado_anterior_check check (
        estado_anterior is null or estado_anterior in ('finalizada', 'vencida', 'abandonada')
    ),
    constraint expotec_partidas_conteos_check check (
        correctas >= 0 and incorrectas >= 0 and respondidas >= 0
        and puntaje_cuestionario >= 0 and puntaje_juego >= 0
    ),
    constraint expotec_partidas_tiempo_check check (tiempo_cuestionario_seg is null or tiempo_cuestionario_seg >= 0)
);
-- Un usuario no puede tener dos partidas abiertas en el mismo evento: la
-- reconexion siempre recupera la partida existente.
create unique index if not exists expotec_partidas_abierta_unica
on expotec_partidas (usuario_id, evento_id)
where estado in ('creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego');
create index if not exists expotec_partidas_evento_idx on expotec_partidas (evento_id);
create index if not exists expotec_partidas_usuario_idx on expotec_partidas (usuario_id);
create index if not exists expotec_partidas_estado_idx on expotec_partidas (evento_id, estado);
create index if not exists expotec_partidas_evento_grupo_idx on expotec_partidas (evento_id, grupo, estado);

-- Adaptacion para bases ya instaladas: las partidas anteriores siguen siendo
-- del grupo 1 y se guarda el estado previo al deshabilitarlas. El check se
-- reemplaza porque 'deshabilitada' tambien puede tener finalizado_at.
alter table expotec_partidas add column if not exists grupo integer not null default 1;
alter table expotec_partidas add column if not exists estado_anterior varchar(30);
alter table expotec_partidas drop constraint if exists expotec_partidas_grupo_check;
alter table expotec_partidas add constraint expotec_partidas_grupo_check check (grupo >= 1);
alter table expotec_partidas drop constraint if exists expotec_partidas_estado_anterior_check;
alter table expotec_partidas add constraint expotec_partidas_estado_anterior_check
    check (estado_anterior is null or estado_anterior in ('finalizada', 'vencida', 'abandonada'));
alter table expotec_partidas drop constraint if exists expotec_partidas_cerrada_check;
alter table expotec_partidas add constraint expotec_partidas_cerrada_check
    check (finalizado_at is null or estado in ('finalizada', 'vencida', 'abandonada', 'deshabilitada'));

create table if not exists expotec_preguntas_asignadas (
    id uuid primary key default gen_random_uuid(),
    partida_id uuid not null references expotec_partidas(id) on delete cascade,
    pregunta_id uuid not null references preguntas(id) on delete restrict,
    orden integer not null,
    opciones_orden jsonb not null,
    constraint expotec_preguntas_asignadas_posicion_unique unique (partida_id, orden),
    constraint expotec_preguntas_asignadas_pregunta_unique unique (partida_id, pregunta_id),
    constraint expotec_preguntas_asignadas_orden_check check (orden >= 0),
    constraint expotec_preguntas_asignadas_opciones_check check (jsonb_typeof(opciones_orden) = 'array')
);
create index if not exists expotec_preguntas_asignadas_partida_idx on expotec_preguntas_asignadas (partida_id, orden);

create table if not exists expotec_respuestas (
    id uuid primary key default gen_random_uuid(),
    partida_id uuid not null references expotec_partidas(id) on delete cascade,
    pregunta_asignada_id uuid not null references expotec_preguntas_asignadas(id) on delete cascade,
    pregunta_id uuid not null references preguntas(id) on delete restrict,
    opcion_id uuid not null references opciones(id) on delete restrict,
    correcta boolean not null,
    puntos integer not null default 0,
    respondido_at timestamptz not null default now(),
    constraint expotec_respuestas_preguntas_unique unique (partida_id, pregunta_asignada_id),
    constraint expotec_respuestas_puntos_check check (puntos >= 0)
);
create index if not exists expotec_respuestas_partida_idx on expotec_respuestas (partida_id);
create index if not exists expotec_respuestas_opcion_idx on expotec_respuestas (opcion_id);

create table if not exists expotec_sesiones_juego (
    id uuid primary key default gen_random_uuid(),
    partida_id uuid not null unique references expotec_partidas(id) on delete cascade,
    ticket uuid not null,
    iniciado_at timestamptz not null default now(),
    finalizado_at timestamptz,
    duracion_seg numeric(10,2),
    meteoritos integer not null default 0,
    impactos integer not null default 0,
    checkpoints jsonb,
    estado varchar(20) not null default 'en_curso',
    constraint expotec_sesiones_estado_check check (estado in ('en_curso', 'cerrada')),
    constraint expotec_sesiones_cerrada_check check (
        (estado = 'en_curso' and finalizado_at is null)
        or (estado = 'cerrada' and finalizado_at is not null)
    ),
    constraint expotec_sesiones_conteos_check check (
        meteoritos >= 0 and impactos >= 0
        and (duracion_seg is null or duracion_seg >= 0)
    )
);

-- Tabla publica minima: alimenta la pantalla de ranking externa y la
-- suscripcion Realtime. No contiene correos, identificadores privados,
-- respuestas ni tokens. Solo inserta el servidor al finalizar una partida.
create table if not exists expotec_resultados_publicos (
    id uuid primary key default gen_random_uuid(),
    partida_id uuid not null unique references expotec_partidas(id) on delete cascade,
    evento_id uuid not null references expotec_eventos(id) on delete cascade,
    alias varchar(40) not null,
    alias_normalizado varchar(40) not null,
    correctas integer not null default 0,
    incorrectas integer not null default 0,
    puntaje_cuestionario integer not null default 0,
    puntaje_juego integer not null default 0,
    puntaje_total integer not null default 0,
    tiempo_cuestionario_seg numeric(10,2),
    finalizado_at timestamptz not null,
    created_at timestamptz not null default now(),
    constraint expotec_resultados_puntaje_check check (
        correctas >= 0 and incorrectas >= 0
        and puntaje_cuestionario >= 0 and puntaje_juego >= 0
        and (puntaje_total = puntaje_cuestionario + puntaje_juego)
    )
);
create index if not exists expotec_resultados_evento_idx on expotec_resultados_publicos (evento_id);
create index if not exists expotec_resultados_ranking_idx on expotec_resultados_publicos (
    evento_id, puntaje_total desc, tiempo_cuestionario_seg asc nulls last,
    puntaje_juego desc, finalizado_at asc
);

create table if not exists expotec_admins (
    usuario_id uuid primary key references perfiles(id) on delete cascade,
    created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Identidad de administrador
--
-- Alta de un administrador: se hace por SQL desde el dashboard de Supabase
-- (ver docs/stage7). El cliente no puede escribir esta tabla, asi que un
-- usuario comun no puede otorgarse el rol desde el navegador.
-- ---------------------------------------------------------------------------

create or replace function es_administrador_expotec()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select auth.uid() is not null
       and exists (
           select 1 from expotec_admins where usuario_id = auth.uid()
       );
$$;

revoke all on function es_administrador_expotec() from public;
grant execute on function es_administrador_expotec() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Validacion de alias
-- ---------------------------------------------------------------------------

-- Normaliza un alias: recorta espacios, colapsa espacios internos y pasa a
-- minusculas. La unicidad por evento se comprueba contra este valor.
create or replace function expotec_alias_normalizado(p_alias text)
returns text
language plpgsql
immutable
as $$
begin
    return regexp_replace(btrim(lower(coalesce(p_alias, ''))), '\s+', ' ', 'g');
end;
$$;

-- Devuelve el mensaje de error, o null cuando el alias es aceptable.
create or replace function expotec_alias_inconveniente(p_alias text)
returns text
language plpgsql
immutable
as $$
declare
    v text;
begin
    v := expotec_alias_normalizado(p_alias);

    if v is null or length(v) = 0 then
        return 'El nombre no puede estar vacio.';
    end if;
    if length(v) < 3 then
        return 'El nombre debe tener al menos 3 caracteres.';
    end if;
    if length(v) > 20 then
        return 'El nombre debe tener hasta 20 caracteres.';
    end if;
    if v !~ '^[a-z0-9áéíóúüñ. _-]+$' then
        return 'Solo se permiten letras, numeros, espacios, puntos, guiones bajos y guiones.';
    end if;
    if left(v, 1) ~ '[ .-]' or right(v, 1) ~ '[ .-]' then
        return 'El nombre no puede empezar o terminar con un simbolo o espacio.';
    end if;
    if v ~ '([ .-]{2,})' then
        return 'El nombre no puede repetir simbolos o espacios seguidos.';
    end if;
    if v ~ '^(admin|administrador|sistema|kodigo|mod|perfil|root|staff)( .*)?$' then
        return 'Ese nombre esta reservado. Probá otra variante.';
    end if;
    if v ~ '(nazi|puta|puto|mierda|idiota|imbecil|tonto|pelotudo|fuck|shit|bitch|nigg)' then
        return 'Ese nombre no es apropiado. Elegí otro.';
    end if;
    return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Reglas de activacion del evento y congelamiento
-- ---------------------------------------------------------------------------

create or replace function expotec_evento_ventana_abierta(p_evento_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from expotec_eventos e
        where e.id = p_evento_id
          and e.estado = 'activo'
          and (e.fecha_inicio is null or e.fecha_inicio <= now())
          and (e.fecha_fin is null or now() <= e.fecha_fin)
    );
$$;

create or replace function expotec_desafio_congelado(p_desafio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from expotec_desafios d
        where d.id = p_desafio_id
          and (
              d.congelado_en is not null
              or exists (select 1 from expotec_partidas p where p.desafio_id = d.id)
          )
    );
$$;

-- ---------------------------------------------------------------------------
-- 5. Seguridad: RLS y politicas
--
-- Las tablas nuevas solo admiten lectura. Las escrituras ocurren exclusivamente
-- dentro de funciones SECURITY DEFINER, que corren como propietario del esquema
-- de forma equivalente al resto del esquema de Kodigo.
-- ---------------------------------------------------------------------------

alter table expotec_eventos enable row level security;
alter table expotec_desafios enable row level security;
alter table expotec_desafio_preguntas enable row level security;
alter table expotec_participantes enable row level security;
alter table expotec_partidas enable row level security;
alter table expotec_preguntas_asignadas enable row level security;
alter table expotec_respuestas enable row level security;
alter table expotec_sesiones_juego enable row level security;
alter table expotec_resultados_publicos enable row level security;
alter table expotec_admins enable row level security;

drop policy if exists "eventos activos publicos" on expotec_eventos;
create policy "eventos activos publicos"
on expotec_eventos
for select
to anon, authenticated
using (
    estado = 'activo'
    and (fecha_inicio is null or fecha_inicio <= now())
    and (fecha_fin is null or now() <= fecha_fin)
);

drop policy if exists "eventos para administrador" on expotec_eventos;
create policy "eventos para administrador"
on expotec_eventos
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "desafios para administrador" on expotec_desafios;
create policy "desafios para administrador"
on expotec_desafios
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "preguntas del desafio para administrador" on expotec_desafio_preguntas;
create policy "preguntas del desafio para administrador"
on expotec_desafio_preguntas
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "participantes para administrador" on expotec_participantes;
create policy "participantes para administrador"
on expotec_participantes
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "partidas propias visibles" on expotec_partidas;
create policy "partidas propias visibles"
on expotec_partidas
for select
to authenticated
using (usuario_id = auth.uid());

drop policy if exists "partidas para administrador" on expotec_partidas;
create policy "partidas para administrador"
on expotec_partidas
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "asignaciones de partidas propias" on expotec_preguntas_asignadas;
create policy "asignaciones de partidas propias"
on expotec_preguntas_asignadas
for select
to authenticated
using (
    exists (
        select 1 from expotec_partidas p
        where p.id = expotec_preguntas_asignadas.partida_id
          and p.usuario_id = auth.uid()
    )
);

drop policy if exists "asignaciones para administrador" on expotec_preguntas_asignadas;
create policy "asignaciones para administrador"
on expotec_preguntas_asignadas
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "respuestas de partidas propias" on expotec_respuestas;
create policy "respuestas de partidas propias"
on expotec_respuestas
for select
to authenticated
using (
    exists (
        select 1 from expotec_partidas p
        where p.id = expotec_respuestas.partida_id
          and p.usuario_id = auth.uid()
    )
);

drop policy if exists "respuestas para administrador" on expotec_respuestas;
create policy "respuestas para administrador"
on expotec_respuestas
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "sesiones de juego propias" on expotec_sesiones_juego;
create policy "sesiones de juego propias"
on expotec_sesiones_juego
for select
to authenticated
using (
    exists (
        select 1 from expotec_partidas p
        where p.id = expotec_sesiones_juego.partida_id
          and p.usuario_id = auth.uid()
    )
);

drop policy if exists "sesiones para administrador" on expotec_sesiones_juego;
create policy "sesiones para administrador"
on expotec_sesiones_juego
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "resultados publicos del ranking" on expotec_resultados_publicos;
create policy "resultados publicos del ranking"
on expotec_resultados_publicos
for select
to anon, authenticated
using (true);

drop policy if exists "admins leen su propia fila" on expotec_admins;
create policy "admins leen su propia fila"
on expotec_admins
for select
to authenticated
using (usuario_id = auth.uid());

-- El panel administrativo necesita leer TODO el contenido (incluidos
-- borradores). No se conceden permisos de escritura al cliente: la escritura
-- de contenido sigue siendo solo por RPC de administrador.
drop policy if exists "contenido completo para administrador (cursos)" on cursos;
create policy "contenido completo para administrador (cursos)"
on cursos
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "contenido completo para administrador (unidades)" on unidades;
create policy "contenido completo para administrador (unidades)"
on unidades
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "contenido completo para administrador (lecciones)" on lecciones;
create policy "contenido completo para administrador (lecciones)"
on lecciones
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "contenido completo para administrador (preguntas)" on preguntas;
create policy "contenido completo para administrador (preguntas)"
on preguntas
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "contenido completo para administrador (opciones)" on opciones;
create policy "contenido completo para administrador (opciones)"
on opciones
for select
to authenticated
using (es_administrador_expotec());

drop policy if exists "soluciones para administrador" on soluciones;
create policy "soluciones para administrador"
on soluciones
for select
to authenticated
using (es_administrador_expotec());

grant select on expotec_resultados_publicos to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Realtime: publicacion de la tabla publica para Postgres Changes
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        if not exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime'
              and schemaname = 'public'
              and tablename = 'expotec_resultados_publicos'
        ) then
            alter publication supabase_realtime add table public.expotec_resultados_publicos;
        end if;
    end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. RPC del participante
--
-- Todas: security definer + search_path fijado + verificacion de propiedad
-- con auth.uid(). El cliente solo ejecuta estas funciones.
-- ---------------------------------------------------------------------------

-- Evento activo con su desafio: datos de solo lectura para las pantallas.
create or replace function expotec_evento_activo()
returns table (
    id uuid,
    nombre varchar,
    descripcion text,
    fecha_inicio timestamptz,
    fecha_fin timestamptz,
    estado varchar,
    desafio_id uuid,
    desafio_nombre varchar,
    version integer,
    cantidad_preguntas integer,
    puntos_por_correcta integer,
    intentos_permitidos integer,
    tiempo_cuestionario_seg integer,
    duracion_juego_seg integer,
    vidas_juego integer
)
language sql
stable
security definer
set search_path = public
as $$
    select
        e.id, e.nombre, e.descripcion, e.fecha_inicio, e.fecha_fin, e.estado,
        d.id, d.nombre, d.version, d.cantidad_preguntas, d.puntos_por_correcta,
        d.intentos_permitidos, d.tiempo_cuestionario_seg, d.duracion_juego_seg,
        d.vidas_juego
    from expotec_eventos e
    join expotec_desafios d on d.evento_id = e.id
    where e.estado = 'activo'
      and (e.fecha_inicio is null or e.fecha_inicio <= now())
      and (e.fecha_fin is null or now() <= e.fecha_fin)
    order by e.created_at desc
    limit 1;
$$;

-- Comprueba si un alias puede usarse en un evento. La validacion definitiva
-- vive en expotec_iniciar_partida, nunca solo en el cliente.
create or replace function expotec_alias_disponible(
    p_evento_id uuid,
    p_alias text
)
returns table (
    disponible boolean,
    alias_normalizado varchar,
    mensaje varchar
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_normalizado varchar;
    v_mensaje text;
begin
    v_mensaje := expotec_alias_inconveniente(p_alias);
    if v_mensaje is not null then
        return query select false, null::varchar, v_mensaje::varchar;
        return;
    end if;

    v_normalizado := expotec_alias_normalizado(p_alias);

    if not expotec_evento_ventana_abierta(p_evento_id) then
        return query select false, v_normalizado, 'El evento no está activo ahora mismo.'::varchar;
        return;
    end if;

    if not exists (
        select 1
        from expotec_participantes x
        where x.evento_id = p_evento_id
          and x.alias_normalizado = v_normalizado
    ) then
        return query select true, v_normalizado, null::varchar;
        return;
    end if;

    return query
    select false, v_normalizado, 'Ese nombre ya está en uso en este evento.'::varchar;
end;
$$;

-- Parte de expotec_iniciar_partida: registra (o recupera) al participante.
create or replace function expotec_registrar_participante(
    p_evento_id uuid,
    p_alias text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_normalizado varchar;
    v_id uuid;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para participar';
    end if;

    v_normalizado := expotec_alias_normalizado(p_alias);

    select x.id into v_id
    from expotec_participantes x
    where x.evento_id = p_evento_id
      and x.alias_normalizado = v_normalizado;

    if v_id is not null then
        if exists (
            select 1 from expotec_participantes x2
            where x2.id = v_id and x2.usuario_id = v_usuario
        ) then
            return v_id;
        end if;
        raise exception 'Ese nombre ya está en uso en este evento.';
    end if;

    insert into expotec_participantes (evento_id, usuario_id, alias, alias_normalizado)
    values (
        p_evento_id,
        v_usuario,
        btrim(p_alias),
        v_normalizado
    )
    on conflict (evento_id, alias_normalizado) do nothing;

    select x.id into v_id
    from expotec_participantes x
    where x.evento_id = p_evento_id
      and x.alias_normalizado = v_normalizado;

    if v_id is null then
        raise exception 'Ese nombre ya está en uso en este evento.';
    end if;

    return v_id;
end;
$$;

revoke all on function expotec_registrar_participante(uuid, text) from public;

-- Cuenta los intentos evidentemente gastados del usuario en el evento.
-- Un intento abandonado sin ninguna respuesta no se cobra: recuperar un
-- arranque por error no castiga al participante.
create or replace function expotec_intentos_gastados(
    p_evento_id uuid,
    p_usuario uuid
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer
    from expotec_partidas p
    where p.evento_id = p_evento_id
      and p.usuario_id = p_usuario
      and (
          p.estado <> 'abandonada'
          or exists (
              select 1 from expotec_respuestas r
              where r.partida_id = p.id
          )
      );
$$;

revoke all on function expotec_intentos_gastados(uuid, uuid) from public;

-- Inicia (o recupera) una partida competitiva: crea el participante si hace
-- falta, congela el desafio y asigna preguntas y opciones con orden aleatorio
-- guardado. Devuelve la partida lista para jugar o una partida abierta propia.
create or replace function expotec_iniciar_partida(
    p_evento_id uuid,
    p_alias text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_mensaje text;
    v_evento record;
    v_desafio record;
    v_participante uuid;
    v_partida_abierta uuid;
    v_partida uuid;
    v_cantidad integer;
    v_grupo integer;
    v_config jsonb;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para participar';
    end if;

    -- 1) Evento activo y ventana vigente.
    if not expotec_evento_ventana_abierta(p_evento_id) then
        raise exception 'El evento no está activo ahora mismo.';
    end if;

    select e.id, e.nombre
    into v_evento
    from expotec_eventos e
    where e.id = p_evento_id;

    if v_evento.id is null then
        raise exception 'El evento no existe.';
    end if;

    -- 2) Alias valido.
    v_mensaje := expotec_alias_inconveniente(p_alias);
    if v_mensaje is not null then
        raise exception '%', v_mensaje;
    end if;

    select d.id, d.nombre, d.version, d.cantidad_preguntas, d.puntos_por_correcta,
           d.tiempo_cuestionario_seg, d.duracion_juego_seg, d.vidas_juego
    into v_desafio
    from expotec_desafios d
    where d.evento_id = p_evento_id;

    if v_desafio.id is null then
        raise exception 'El evento todavía no tiene un desafío configurado.';
    end if;

    -- 3) Participante por alias (unico por evento a nivel de base de datos).
    v_participante := expotec_registrar_participante(p_evento_id, p_alias);

    -- 4) Si el usuario ya tiene una partida abierta en este evento se recupera
    --    en lugar de crear una nueva: la recarga no duplica ni pierde estado.
    select p.id into v_partida_abierta
    from expotec_partidas p
    where p.usuario_id = v_usuario
      and p.evento_id = p_evento_id
      and p.estado in ('creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego')
    limit 1;

    if v_partida_abierta is not null then
        return v_partida_abierta;
    end if;

    -- 5) Los intentos son ilimitados por participante. El límite por intentos
    --    se eliminó a pedido de los docentes: cualquier participante puede
    --    repetir el desafío cuantas veces quiera en el mismo equipo. El alias
    --    sigue siendo único por evento y el ranking muestra la mejor partida
    --    por alias, así el participar más no distorsiona la igualdad.

    -- 6) Preguntas del desafio, suficientes y con contenido.
    select count(*)::integer into v_cantidad
    from expotec_desafio_preguntas dp
    join preguntas q on q.id = dp.pregunta_id
    where dp.desafio_id = v_desafio.id
      and q.estado_publicacion = 'publicado'
      and q.tipo = 'seleccion'
      and btrim(coalesce(q.enunciado, '')) <> '';

    if v_cantidad < coalesce(v_desafio.cantidad_preguntas, 1) then
        raise exception 'El desafío todavía no tiene sus % preguntas configuradas. Avisá al equipo de Kodigo.',
            coalesce(v_desafio.cantidad_preguntas, 1);
    end if;

    v_cantidad := v_desafio.cantidad_preguntas;

    -- 7) Congela el desafio con la primera partida: ya congelado no cambia nada.
    update expotec_desafios
    set congelado_en = coalesce(congelado_en, now())
    where id = v_desafio.id;

    -- 8) Crea la partida con las reglas congeladas en el grupo vigente: tras
    --    un reinicio, las nuevas partidas entran en la siguiente tanda.
    select coalesce(max(grupo), 1) into v_grupo
    from expotec_partidas
    where evento_id = p_evento_id;

    v_config := jsonb_build_object(
        'evento', jsonb_build_object('id', v_evento.id, 'nombre', v_evento.nombre),
        'desafio', jsonb_build_object(
            'id', v_desafio.id,
            'nombre', v_desafio.nombre,
            'version', v_desafio.version,
            'cantidad_preguntas', v_cantidad,
            'puntos_por_correcta', v_desafio.puntos_por_correcta,
            'tiempo_cuestionario_seg', v_desafio.tiempo_cuestionario_seg,
            'duracion_juego_seg', v_desafio.duracion_juego_seg,
            'vidas_juego', v_desafio.vidas_juego
        )
    );

    insert into expotec_partidas (
        evento_id, desafio_id, participante_id, usuario_id, alias,
        estado, grupo, config_snapshot, iniciado_at, vencimiento_at
    )
    values (
        p_evento_id, v_desafio.id, v_participante, v_usuario,
        btrim(p_alias),
        'en_cuestionario',
        v_grupo,
        v_config,
        now(),
        case
            when v_desafio.tiempo_cuestionario_seg is null then null
            else now() + make_interval(secs => v_desafio.tiempo_cuestionario_seg)
        end
    )
    returning id into v_partida;

    -- 9) Asignacion aleatoria de la seleccion en orden aleatorio. random()
    --    corre en el servidor: el cliente no puede elegir ni predecir el orden.
    insert into expotec_preguntas_asignadas (partida_id, pregunta_id, orden, opciones_orden)
    select
        v_partida,
        seleccionadas.id,
        seleccionadas.posicion - 1,
        mezcladas.opciones
    from (
        select pool.pregunta_id as id,
               row_number() over (order by random()) as posicion
        from (
            select dp2.pregunta_id
            from expotec_desafio_preguntas dp2
            join preguntas q2 on q2.id = dp2.pregunta_id
            where dp2.desafio_id = v_desafio.id
              and q2.estado_publicacion = 'publicado'
              and q2.tipo = 'seleccion'
              and btrim(coalesce(q2.enunciado, '')) <> ''
            order by random()
            limit v_cantidad
        ) pool
    ) seleccionadas
    cross join lateral (
        select jsonb_agg(o.id order by random()) opciones
        from opciones o
        where o.pregunta_id = seleccionadas.id
    ) mezcladas;

    return v_partida;
end;
$$;

-- Estado completo de la partida para pintar (y reanudar) el cuestionario.
-- Nunca incluye cual opcion es correcta ni explicaciones: esas salen por una
-- operacion autorizada aparte, solo cuando el intento termino.
create or replace function expotec_estado_partida(p_partida_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_partida expotec_partidas;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para consultar la partida';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = p_partida_id and p.usuario_id = v_usuario;

    if v_partida.id is null then
        raise exception 'La partida no existe o no te pertenece.';
    end if;

    -- Vencimiento: una partida en cuestionario que excedio su plazo queda
    -- vencida (incompleta, sin resultado oficial).
    if v_partida.estado = 'en_cuestionario'
       and v_partida.vencimiento_at is not null
       and now() > v_partida.vencimiento_at
    then
        update expotec_partidas
        set estado = 'vencida',
            finalizado_at = vencimiento_at
        where id = v_partida.id
          and estado = 'en_cuestionario';

        select * into v_partida from expotec_partidas p where p.id = p_partida_id;
    end if;

    return jsonb_build_object(
        'servidor_at', now(),
        'partida', jsonb_build_object(
            'id', v_partida.id,
            'estado', v_partida.estado,
            'alias', v_partida.alias,
            'evento_id', v_partida.evento_id,
            'iniciado_at', v_partida.iniciado_at,
            'vencimiento_at', v_partida.vencimiento_at,
            'completado_at', v_partida.cuestionario_completado_at,
            'finalizado_at', v_partida.finalizado_at,
            'respondidas', v_partida.respondidas,
            'correctas', v_partida.correctas,
            'incorrectas', v_partida.incorrectas,
            'puntaje_cuestionario', v_partida.puntaje_cuestionario,
            'tiempo_cuestionario_seg', v_partida.tiempo_cuestionario_seg,
            'config', v_partida.config_snapshot
        ),
        'preguntas', coalesce((
            select jsonb_agg(
                jsonb_build_object(
                    'id', a.id,
                    'orden', a.orden,
                    'enunciado', q.enunciado,
                    'opciones', coalesce((
                        select jsonb_agg(
                            jsonb_build_object('id', o.id, 'texto', o.texto)
                            order by ord.ord
                        )
                        from jsonb_array_elements_text(a.opciones_orden) with ordinality ord(id_texto, ord)
                        join opciones o on o.id::text = ord.id_texto
                    ), '[]'::jsonb)
                ) order by a.orden
            )
            from expotec_preguntas_asignadas a
            join preguntas q on q.id = a.pregunta_id
            where a.partida_id = v_partida.id
        ), '[]'::jsonb),
        'respuestas', coalesce((
            select jsonb_agg(
                jsonb_build_object(
                    'pregunta_asignada_id', r.pregunta_asignada_id,
                    'opcion_id', r.opcion_id,
                    'respondido_at', r.respondido_at
                ) order by r.respondido_at
            )
            from expotec_respuestas r
            where r.partida_id = v_partida.id
        ), '[]'::jsonb)
    );
end;
$$;

-- Confirma una respuesta. Verifica en orden: sesion, propiedad de la partida,
-- pertenencia de la pregunta a la partida, vigencia de evento/partida/plazo,
-- existencia de la opcion y pertenencia a la pregunta, ausencia de respuesta
-- previa. Es idempotente: la unica (partida, pregunta_asignada) impide dobles
-- registros incluso si dos pedidos llegan al mismo tiempo; el segundo pedido
-- ve la respuesta ya guardada y devuelve el mismo dato sin sumar puntos.
create or replace function expotec_responder(
    p_partida_id uuid,
    p_pregunta_asignada_id uuid,
    p_opcion_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_partida expotec_partidas;
    v_asignada expotec_preguntas_asignadas;
    v_respuesta_existente expotec_respuestas;
    v_correcta uuid;
    v_correspondiente boolean;
    v_cantidad integer;
    v_puntos integer;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para responder';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = p_partida_id and p.usuario_id = v_usuario;

    if v_partida.id is null then
        raise exception 'La partida no existe o no te pertenece.';
    end if;

    if not expotec_evento_ventana_abierta(v_partida.evento_id) then
        raise exception 'El evento ya no está activo.';
    end if;

    if not (v_partida.estado in ('en_cuestionario', 'creada')) then
        raise exception 'El cuestionario ya no acepta respuestas.';
    end if;

    if v_partida.vencimiento_at is not null and now() > v_partida.vencimiento_at then
        update expotec_partidas
        set estado = 'vencida',
            finalizado_at = vencimiento_at
        where id = v_partida.id and estado in ('creada', 'en_cuestionario');

        raise exception 'Se acabó el tiempo de la partida.';
    end if;

    select * into v_asignada
    from expotec_preguntas_asignadas a
    where a.id = p_pregunta_asignada_id
      and a.partida_id = v_partida.id;

    if v_asignada.id is null then
        raise exception 'La pregunta no fue asignada a esta partida.';
    end if;

    select s.opcion_correcta_id into v_correcta
    from soluciones s
    where s.pregunta_id = v_asignada.pregunta_id;

    if v_correcta is null then
        raise exception 'Esta pregunta todavía no tiene solución configurada. Avisá al equipo.';
    end if;

    -- La opcion debe existir y pertenecer a la pregunta asignada.
    select exists (
        select 1
        from opciones o
        where o.id = p_opcion_id
          and o.pregunta_id = v_asignada.pregunta_id
    ) into v_correspondiente;

    if not v_correspondiente then
        raise exception 'La opción no pertenece a esta pregunta.';
    end if;

    -- Respuesta previa: idempotencia (nunca se modifica ni se duplica).
    select * into v_respuesta_existente
    from expotec_respuestas r
    where r.partida_id = v_partida.id
      and r.pregunta_asignada_id = p_pregunta_asignada_id;

    if v_respuesta_existente.id is not null then
        return expotec_progreso_partida_jsonb(v_partida.id, true);
    end if;

    v_puntos := case
        when v_correcta = p_opcion_id
        then (v_partida.config_snapshot -> 'desafio' ->> 'puntos_por_correcta')::integer
        else 0
    end;

    insert into expotec_respuestas (
        partida_id, pregunta_asignada_id, pregunta_id, opcion_id, correcta, puntos
    )
    values (
        v_partida.id, p_pregunta_asignada_id, v_asignada.pregunta_id,
        p_opcion_id, (v_correcta = p_opcion_id), v_puntos
    )
    on conflict (partida_id, pregunta_asignada_id) do nothing;

    -- Contadores recalculados en la misma transaccion: nunca se suman dos
    -- veces gracias a la restriccion unica.
    update expotec_partidas
    set respondidas = (
            select count(*)::integer from expotec_respuestas where partida_id = v_partida.id
        ),
        correctas = (
            select count(*)::integer from expotec_respuestas
            where partida_id = v_partida.id and correcta
        ),
        incorrectas = (
            select count(*)::integer from expotec_respuestas
            where partida_id = v_partida.id and not correcta
        ),
        puntaje_cuestionario = (
            select coalesce(sum(puntos), 0)::integer from expotec_respuestas
            where partida_id = v_partida.id
        )
    where id = v_partida.id
    returning (config_snapshot -> 'desafio' ->> 'cantidad_preguntas')::integer into v_cantidad;

    if (select respondidas from expotec_partidas where id = v_partida.id) >= v_cantidad then
        update expotec_partidas
        set estado = 'cuestionario_completado',
            cuestionario_completado_at = now(),
            finalizado_at = null,
            tiempo_cuestionario_seg = round(
                extract(epoch from (now() - iniciado_at))::numeric, 2
            )
        where id = v_partida.id
          and estado in ('creada', 'en_cuestionario');
    end if;

    return expotec_progreso_partida_jsonb(v_partida.id, false);
end;
$$;

-- Progreso del cuestionario que ve el cliente: conteos agregados solamente.
-- Durante el cuestionario no se revela el desglose correcto/incorrecto.
create or replace function expotec_progreso_partida_jsonb(
    p_partida_id uuid,
    p_ya_registrada boolean
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_partida expotec_partidas;
begin
    select * into v_partida from expotec_partidas where id = p_partida_id;

    return jsonb_build_object(
        'ya_registrada', coalesce(p_ya_registrada, false),
        'respondidas', v_partida.respondidas,
        'pendientes', greatest(
            (v_partida.config_snapshot -> 'desafio' ->> 'cantidad_preguntas')::integer
              - v_partida.respondidas,
            0
        ),
        'completado', v_partida.estado in ('cuestionario_completado', 'en_juego', 'finalizada'),
        'respondido_at', now(),
        'servidor_at', now()
    );
end;
$$;

-- Arranca (o reanuda) Core Defender de una partida con el cuestionario listo.
create or replace function expotec_iniciar_juego(p_partida_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_partida expotec_partidas;
    v_sesion expotec_sesiones_juego;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para jugar';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = p_partida_id and p.usuario_id = v_usuario;

    if v_partida.id is null then
        raise exception 'La partida no existe o no te pertenece.';
    end if;

    if not expotec_evento_ventana_abierta(v_partida.evento_id) then
        raise exception 'El evento ya no está activo.';
    end if;

    if v_partida.estado = 'en_juego' then
        -- Reconexion: la sesion ya abierta se recupera sin reiniciar el tiempo.
        select * into v_sesion from expotec_sesiones_juego s where s.partida_id = v_partida.id;
        return jsonb_build_object(
            'sesion_id', v_sesion.id,
            'duracion_max_seg', (v_partida.config_snapshot -> 'desafio' ->> 'duracion_juego_seg')::integer,
            'vidas', (v_partida.config_snapshot -> 'desafio' ->> 'vidas_juego')::integer,
            'reanudada', true
        );
    end if;

    if v_partida.estado <> 'cuestionario_completado' then
        raise exception 'Antes de jugar hay que terminar el cuestionario.';
    end if;

    insert into expotec_sesiones_juego (partida_id, ticket)
    values (v_partida.id, gen_random_uuid())
    on conflict (partida_id) do nothing;

    select * into v_sesion from expotec_sesiones_juego s where s.partida_id = v_partida.id;

    update expotec_partidas
    set estado = 'en_juego'
    where id = v_partida.id and estado = 'cuestionario_completado';

    return jsonb_build_object(
        'sesion_id', v_sesion.id,
        'duracion_max_seg', (v_partida.config_snapshot -> 'desafio' ->> 'duracion_juego_seg')::integer,
        'vidas', (v_partida.config_snapshot -> 'desafio' ->> 'vidas_juego')::integer,
        'reanudada', false
    );
end;
$$;

-- Telemetria opcional del juego: marcas de progreso cada tantos segundos.
-- Conserva los checkpoints recibidos para la validacion final.
create or replace function expotec_checkpoint_juego(
    p_sesion_id uuid,
    p_checkpoints jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para enviar telemetria';
    end if;

    if p_checkpoints is null or jsonb_typeof(p_checkpoints) <> 'array' then
        raise exception 'Formato de checkpoints invalido';
    end if;

    update expotec_sesiones_juego s
    set checkpoints = coalesce(s.checkpoints, '[]'::jsonb) || p_checkpoints
    where s.id = p_sesion_id
      and s.estado = 'en_curso'
      and exists (
          select 1 from expotec_partidas p
          where p.id = s.partida_id and p.usuario_id = v_usuario
      );
end;
$$;

-- Limites de plausibilidad del juego (espejados en src/services/coreDefender.js):
--   MAX_DESTRUIDOS_POR_SEGUNDO: techo absoluto de destrucciones por segundo.
--   MARGEN_DESTRUIDOS: margen fijo para picos iniciales.
-- El servidor valida contra el tiempo REAL de la sesion medido en la base.
create or replace function expotec_tope_destruidos(p_duracion numeric)
returns integer
language sql
immutable
as $$
    select least(
        greatest(floor(p_duracion * 2.5 + 8)::integer, 0),
        2000
    );
$$;

-- Valida y registra el resultado final de Core Defender, cierra la partida de
-- manera atomica y publica el resultado oficial. Idempotente: una partida
-- finalizada no puede volver a abrirse ni sumar puntos otra vez.
create or replace function expotec_finalizar_juego(
    p_sesion_id uuid,
    p_meteoritos integer,
    p_impactos integer,
    p_duracion_seg numeric,
    p_checkpoints jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_sesion expotec_sesiones_juego;
    v_partida expotec_partidas;
    v_transcurrido numeric;
    v_techo integer;
    v_vidas integer;
    v_duracion_max integer;
    v_duracion numeric;
    v_impactos integer;
    v_meteoritos integer;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para finalizar el juego';
    end if;

    if p_meteoritos is null or p_meteoritos < 0 or p_impactos is null or p_impactos < 0
       or p_duracion_seg is null or p_duracion_seg < 0 then
        raise exception 'El resultado del juego no tiene un formato valido.';
    end if;

    select * into v_sesion
    from expotec_sesiones_juego s
    where s.id = p_sesion_id
      and exists (
          select 1 from expotec_partidas p
          where p.id = s.partida_id and p.usuario_id = v_usuario
      );

    if v_sesion.id is null then
        raise exception 'La sesion de juego no existe o no te pertenece.';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = v_sesion.partida_id;

    -- Partida ya finalizada: idempotencia, devuelve el mismo resultado.
    if v_partida.estado = 'finalizada' then
        return jsonb_build_object(
            'partida_id', v_partida.id,
            'estado', v_partida.estado,
            'puntaje_juego', v_partida.puntaje_juego,
            'puntaje_cuestionario', v_partida.puntaje_cuestionario,
            'puntaje_total', v_partida.puntaje_total,
            'correctas', v_partida.correctas,
            'incorrectas', v_partida.incorrectas,
            'tiempo_cuestionario_seg', v_partida.tiempo_cuestionario_seg,
            'finalizado_at', v_partida.finalizado_at
        );
    end if;

    if v_partida.estado <> 'en_juego' or v_sesion.estado <> 'en_curso' then
        raise exception 'La partida ya no está en juego.';
    end if;

    -- El cronometro manda el servidor: la duracion reportada no puede superar
    -- el tiempo real transcurrido desde el arranque de la sesion (con margen
    -- para latencia) ni el limite del desafio.
    v_transcurrido := extract(epoch from (now() - v_sesion.iniciado_at));
    v_duracion_max := (v_partida.config_snapshot -> 'desafio' ->> 'duracion_juego_seg')::integer;
    v_vidas := (v_partida.config_snapshot -> 'desafio' ->> 'vidas_juego')::integer;

    if p_duracion_seg > v_transcurrido + 2 then
        raise exception 'La duración reportada no coincide con el tiempo real.';
    end if;
    if p_duracion_seg > v_duracion_max then
        v_duracion := v_duracion_max::numeric;
    else
        v_duracion := p_duracion_seg;
    end if;

    -- Impactos plausibles: no se puede perder mas vidas que las permitidas,
    -- y cada impacto consume al menos una vida.
    v_impactos := least(p_impactos, v_vidas);

    -- Techo de meteoritos segun duracion y velocidad maxima del juego.
    v_techo := expotec_tope_destruidos(v_duracion);
    v_meteoritos := least(p_meteoritos, v_techo);

    if p_checkpoints is not null and jsonb_typeof(p_checkpoints) = 'array' then
        update expotec_sesiones_juego
        set checkpoints = coalesce(checkpoints, '[]'::jsonb) || p_checkpoints
        where id = v_sesion.id;
    end if;

    -- Cierre atomico de sesion y partida: solo la primera llamada cruza la
    -- condicion de estado; las repetidas no encuentran filas y son idempotentes.
    update expotec_sesiones_juego
    set estado = 'cerrada',
        finalizado_at = now(),
        duracion_seg = v_duracion,
        meteoritos = v_meteoritos,
        impactos = v_impactos
    where id = v_sesion.id
      and estado = 'en_curso'
      returning id into v_sesion.id;

    if v_sesion.id is not null then
        update expotec_partidas
        set estado = 'finalizada',
            finalizado_at = now(),
            puntaje_juego = v_meteoritos
        where id = v_partida.id
          and estado = 'en_juego'
          returning id, finalizado_at into v_partida.id, v_partida.finalizado_at;

        select * into v_partida from expotec_partidas p where p.id = v_partida.id;

        -- Resultado oficial minimo para el ranking publico. Solo vive aqui:
        -- el cliente no puede insertarlo ni modificarlo.
        insert into expotec_resultados_publicos (
            partida_id, evento_id, alias, alias_normalizado,
            correctas, incorrectas,
            puntaje_cuestionario, puntaje_juego, puntaje_total,
            tiempo_cuestionario_seg, finalizado_at
        )
        values (
            v_partida.id, v_partida.evento_id, v_partida.alias,
            expotec_alias_normalizado(v_partida.alias),
            v_partida.correctas, v_partida.incorrectas,
            v_partida.puntaje_cuestionario, v_partida.puntaje_juego,
            v_partida.puntaje_cuestionario + v_partida.puntaje_juego,
            v_partida.tiempo_cuestionario_seg,
            v_partida.finalizado_at
        )
        on conflict (partida_id) do nothing;
    end if;

    select * into v_partida from expotec_partidas p where p.id = v_partida.id;

    return jsonb_build_object(
        'partida_id', v_partida.id,
        'estado', v_partida.estado,
        'puntaje_juego', v_partida.puntaje_juego,
        'puntaje_cuestionario', v_partida.puntaje_cuestionario,
        'puntaje_total', v_partida.puntaje_total,
        'correctas', v_partida.correctas,
        'incorrectas', v_partida.incorrectas,
        'tiempo_cuestionario_seg', v_partida.tiempo_cuestionario_seg,
        'finalizado_at', v_partida.finalizado_at
    );
end;
$$;

-- Abandona el intento: queda como partida incompleta, sin resultado oficial.
create or replace function expotec_abandonar(p_partida_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_partida expotec_partidas;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para abandonar';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = p_partida_id and p.usuario_id = v_usuario;

    if v_partida.id is null then
        raise exception 'La partida no existe o no te pertenece.';
    end if;

    if v_partida.estado in ('finalizada', 'vencida', 'abandonada') then
        return jsonb_build_object('estado', v_partida.estado, 'abandonada', true);
    end if;

    if v_partida.estado = 'en_juego' then
        update expotec_sesiones_juego
        set estado = 'cerrada',
            finalizado_at = now()
        where partida_id = v_partida.id
          and estado = 'en_curso';
    end if;

    update expotec_partidas
    set estado = 'abandonada',
        finalizado_at = now()
    where id = v_partida.id
      and estado in ('creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego');

    return jsonb_build_object('estado', 'abandonada', 'abandonada', true, 'servidor_at', now());
end;
$$;

-- Soluciones autorizadas del cuestionario: solo con el intento FINALIZADO y
-- cuando el desafio permite mostrar resultados. Abandonadas y vencidas no las
-- reciben (no hay resultado oficial de un intento incompleto).
create or replace function expotec_obtener_soluciones(p_partida_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_partida expotec_partidas;
    v_permite boolean;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para consultar las soluciones';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = p_partida_id and p.usuario_id = v_usuario;

    if v_partida.id is null then
        raise exception 'La partida no existe o no te pertenece.';
    end if;

    if v_partida.estado <> 'finalizada' then
        raise exception 'Las soluciones aparecen al terminar el intento sin abandonar.';
    end if;

    select coalesce(d.mostrar_soluciones, true) into v_permite
    from expotec_desafios d
    where d.id = v_partida.desafio_id;

    if not v_permite then
        raise exception 'Este evento todavía no muestra las soluciones.';
    end if;

    return jsonb_build_object(
        'preguntas', coalesce((
            select jsonb_agg(
                jsonb_build_object(
                    'orden', a.orden,
                    'enunciado', q.enunciado,
                    'elegida', (
                        select jsonb_build_object('id', o.id, 'texto', o.texto)
                        from expotec_respuestas r
                        join opciones o on o.id = r.opcion_id
                        where r.partida_id = v_partida.id
                          and r.pregunta_asignada_id = a.id
                    ),
                    'correcta', (
                        select jsonb_build_object('id', o.id, 'texto', o.texto)
                        from soluciones s
                        join opciones o on o.id = s.opcion_correcta_id
                        where s.pregunta_id = a.pregunta_id
                    ),
                    'acerto', (
                        select r.correcta
                        from expotec_respuestas r
                        where r.partida_id = v_partida.id
                          and r.pregunta_asignada_id = a.id
                    ),
                    'sin_respuesta', not exists (
                        select 1 from expotec_respuestas r
                        where r.partida_id = v_partida.id
                          and r.pregunta_asignada_id = a.id
                    ),
                    'explicacion', (
                        select s.explicacion
                        from soluciones s
                        where s.pregunta_id = a.pregunta_id
                    )
                ) order by a.orden
            )
            from expotec_preguntas_asignadas a
            join preguntas q on q.id = a.pregunta_id
            where a.partida_id = v_partida.id
        ), '[]'::jsonb)
    );
end;
$$;

-- Mis partidas en un evento (para reconectar y para la pantalla de resultados).
create or replace function expotec_mis_partidas(p_evento_id uuid)
returns table (
    id uuid,
    estado varchar,
    alias varchar,
    iniciado_at timestamptz,
    finalizado_at timestamptz,
    respondidas integer,
    cantidad_preguntas integer,
    correctas integer,
    incorrectas integer,
    puntaje_cuestionario integer,
    puntaje_juego integer,
    puntaje_total integer
)
language sql
stable
security definer
set search_path = public
as $$
    select
        p.id, p.estado, p.alias, p.iniciado_at, p.finalizado_at,
        p.respondidas, (p.config_snapshot -> 'desafio' ->> 'cantidad_preguntas')::integer,
        p.correctas, p.incorrectas, p.puntaje_cuestionario, p.puntaje_juego, p.puntaje_total
    from expotec_partidas p
    where p.evento_id = p_evento_id
      and p.usuario_id = auth.uid()
    order by p.iniciado_at desc
    limit 50;
$$;

-- Resultado propio completo (sin las soluciones del cuestionario).
create or replace function expotec_resultado_propio(p_partida_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_partida expotec_partidas;
    v_puesto bigint;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para consultar el resultado';
    end if;

    select * into v_partida
    from expotec_partidas p
    where p.id = p_partida_id and p.usuario_id = v_usuario;

    if v_partida.id is null then
        raise exception 'La partida no existe o no te pertenece.';
    end if;

    select count(*) + 1 into v_puesto
    from expotec_resultados_publicos r
    where r.evento_id = v_partida.evento_id
      and (
          r.puntaje_total > v_partida.puntaje_total
          or (
              r.puntaje_total = v_partida.puntaje_total
              and coalesce(r.tiempo_cuestionario_seg, 1e9) < coalesce(v_partida.tiempo_cuestionario_seg, 1e9)
          )
          or (
              r.puntaje_total = v_partida.puntaje_total
              and r.tiempo_cuestionario_seg is not null
              and coalesce(r.tiempo_cuestionario_seg, 1e9) = coalesce(v_partida.tiempo_cuestionario_seg, 1e9)
              and r.puntaje_juego > v_partida.puntaje_juego
          )
          or (
              r.puntaje_total = v_partida.puntaje_total
              and coalesce(r.tiempo_cuestionario_seg, 1e9) = coalesce(v_partida.tiempo_cuestionario_seg, 1e9)
              and r.puntaje_juego = v_partida.puntaje_juego
              and r.finalizado_at < v_partida.finalizado_at
          )
      );

    return jsonb_build_object(
        'partida', jsonb_build_object(
            'id', v_partida.id,
            'estado', v_partida.estado,
            'alias', v_partida.alias,
            'correctas', v_partida.correctas,
            'incorrectas', v_partida.incorrectas,
            'respondidas', v_partida.respondidas,
            'puntaje_cuestionario', v_partida.puntaje_cuestionario,
            'puntaje_juego', v_partida.puntaje_juego,
            'puntaje_total', v_partida.puntaje_total,
            'tiempo_cuestionario_seg', v_partida.tiempo_cuestionario_seg,
            'iniciado_at', v_partida.iniciado_at,
            'finalizado_at', v_partida.finalizado_at,
            'config', v_partida.config_snapshot
        ),
        'puesto', case when v_partida.estado = 'finalizada' then v_puesto else null end
    );
end;
$$;

-- Ranking oficial del evento. Aplica las reglas documentadas:
--   * solo resultados oficiales (partidas finalizadas);
--   * mejor intento valido por participante (unico alias + mejores metricas);
--   * desempates ordenados: tiempo del cuestionario, puntos del juego,
--     fecha de envio (de menor a mayor).
create or replace function expotec_ranking(
    p_evento_id uuid,
    p_limite integer default 100
)
returns table (
    puesto bigint,
    alias varchar,
    puntaje_total integer,
    puntaje_cuestionario integer,
    puntaje_juego integer,
    correctas integer,
    incorrectas integer,
    tiempo_cuestionario_seg numeric,
    finalizado_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    with oficiales as (
        select r.*
        from expotec_resultados_publicos r
        join expotec_partidas p on p.id = r.partida_id
        where r.evento_id = p_evento_id
          and p.estado = 'finalizada'
    ), mejores as (
        select distinct on (alias_normalizado) *
        from oficiales
        order by alias_normalizado,
                 puntaje_total desc,
                 tiempo_cuestionario_seg asc nulls last,
                 puntaje_juego desc,
                 finalizado_at asc
    )
    select
        row_number() over (
            order by puntaje_total desc,
                     tiempo_cuestionario_seg asc nulls last,
                     puntaje_juego desc,
                     finalizado_at asc
        ),
        alias,
        puntaje_total,
        puntaje_cuestionario,
        puntaje_juego,
        correctas,
        incorrectas,
        tiempo_cuestionario_seg,
        finalizado_at
    from mejores
    order by puntaje_total desc,
             tiempo_cuestionario_seg asc nulls last,
             puntaje_juego desc,
             finalizado_at asc
    limit least(coalesce(p_limite, 100), 500);
$$;

-- ---------------------------------------------------------------------------
-- 8. RPC del panel de administracion
--
-- Prefijo expotec_admin_. Todas son SECURITY DEFINER con search_path fijado y
-- arrancan verificando es_administrador_expotec(): un usuario comun recibe
-- error antes de tocar nada. La identidad de administrador vive sola en la
-- tabla expotec_admins, poblada por SQL desde el dashboard: el cliente no
-- puede dar de alta administradores ni a si mismo.
-- ---------------------------------------------------------------------------

-- Bandera simple para la interfaz: la ruta /admin pregunta esto al entrar.
create or replace function expotec_admin_es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select es_administrador_expotec();
$$;

-- Guard reutilizado por todas las RPC de administracion.
create or replace function expotec_guard_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if not es_administrador_expotec() then
        raise exception 'Solo los administradores pueden usar el panel de ExpoTécnica.';
    end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8.1 Validadores de publicacion de contenido
--
-- Publicar exige contenido completo. Los helpers devuelven el primer
-- inconveniente como texto, o null cuando el contenido es publicable; las RPC
-- los usan al asignar estado_publicacion = 'publicado'.
-- ---------------------------------------------------------------------------

-- Inconveniente de una leccion al publicarse: explicacion y al menos una
-- pregunta publicada que ademas pase su propio validador.
create or replace function expotec_inconveniente_leccion(p_leccion_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_leccion record;
    v_publicadas integer;
    v_pregunta record;
    v_inconveniente text;
begin
    select * into v_leccion from lecciones where id = p_leccion_id;

    if v_leccion.id is null then
        return 'La lección no existe.';
    end if;
    if btrim(coalesce(v_leccion.explicacion, '')) = '' then
        return 'La lección necesita una explicación';
    end if;

    select count(*)::integer into v_publicadas
    from preguntas
    where leccion_id = p_leccion_id
      and estado_publicacion = 'publicado';

    if v_publicadas = 0 then
        return 'La lección necesita al menos una actividad publicada';
    end if;

    for v_pregunta in
        select id, enunciado
        from preguntas
        where leccion_id = p_leccion_id
          and estado_publicacion = 'publicado'
    loop
        v_inconveniente := expotec_inconveniente_pregunta(v_pregunta.id);
        if v_inconveniente is not null then
            return 'Actividad "' || left(coalesce(v_pregunta.enunciado, ''), 60)
                || '": ' || v_inconveniente;
        end if;
    end loop;

    return null;
end;
$$;

-- Inconveniente de una unidad al publicarse: al menos una leccion publicada y
-- valida.
create or replace function expotec_inconveniente_unidad(p_unidad_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_unidad record;
    v_publicadas integer;
    v_leccion record;
    v_inconveniente text;
begin
    select * into v_unidad from unidades where id = p_unidad_id;

    if v_unidad.id is null then
        return 'La unidad no existe.';
    end if;

    select count(*)::integer into v_publicadas
    from lecciones
    where unidad_id = p_unidad_id
      and estado_publicacion = 'publicado';

    if v_publicadas = 0 then
        return 'La unidad necesita al menos una clase publicada';
    end if;

    for v_leccion in
        select id, titulo
        from lecciones
        where unidad_id = p_unidad_id
          and estado_publicacion = 'publicado'
    loop
        v_inconveniente := expotec_inconveniente_leccion(v_leccion.id);
        if v_inconveniente is not null then
            return 'Clase "' || left(coalesce(v_leccion.titulo, ''), 60)
                || '": ' || v_inconveniente;
        end if;
    end loop;

    return null;
end;
$$;

-- Inconveniente de un curso al publicarse: al menos una unidad publicada y
-- valida.
create or replace function expotec_inconveniente_curso(p_curso_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_curso record;
    v_publicadas integer;
    v_unidad record;
    v_inconveniente text;
begin
    select * into v_curso from cursos where id = p_curso_id;

    if v_curso.id is null then
        return 'El curso no existe.';
    end if;

    select count(*)::integer into v_publicadas
    from unidades
    where curso_id = p_curso_id
      and estado_publicacion = 'publicado';

    if v_publicadas = 0 then
        return 'El curso necesita al menos una unidad publicada';
    end if;

    for v_unidad in
        select id, nombre
        from unidades
        where curso_id = p_curso_id
          and estado_publicacion = 'publicado'
    loop
        v_inconveniente := expotec_inconveniente_unidad(v_unidad.id);
        if v_inconveniente is not null then
            return 'Unidad "' || left(coalesce(v_unidad.nombre, ''), 60)
                || '": ' || v_inconveniente;
        end if;
    end loop;

    return null;
end;
$$;

-- Inconveniente de un desafio al activar su evento: configuracion completa,
-- cantidad suficiente de preguntas y cada una con contenido y solucion.
create or replace function expotec_inconveniente_desafio(p_desafio_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_desafio record;
    v_habilitadas integer;
    v_pregunta record;
    v_inconveniente text;
begin
    select * into v_desafio from expotec_desafios where id = p_desafio_id;

    if v_desafio.id is null then
        return 'El evento no tiene un desafío configurado.';
    end if;

    select count(*)::integer into v_habilitadas
    from expotec_desafio_preguntas dp
    join preguntas q on q.id = dp.pregunta_id
    where dp.desafio_id = p_desafio_id
      and q.estado_publicacion = 'publicado'
      and q.tipo = 'seleccion';

    if v_habilitadas < coalesce(v_desafio.cantidad_preguntas, 1) then
        return 'El desafío tiene ' || v_habilitadas
            || ' de ' || coalesce(v_desafio.cantidad_preguntas, 1)
            || ' preguntas habilitadas.';
    end if;

    for v_pregunta in
        select q.id, q.enunciado
        from expotec_desafio_preguntas dp
        join preguntas q on q.id = dp.pregunta_id
        where dp.desafio_id = p_desafio_id
          and q.estado_publicacion = 'publicado'
          and q.tipo = 'seleccion'
    loop
        select coalesce((
            select s.explicacion
            from soluciones s
            where s.pregunta_id = v_pregunta.id
              and s.opcion_correcta_id is not null
              and btrim(coalesce(s.explicacion, '')) <> ''
              and exists (
                  select 1 from opciones o
                  where o.id = s.opcion_correcta_id
                    and o.pregunta_id = v_pregunta.id
              )
        ), '') into v_inconveniente;

        if v_inconveniente = '' then
            return 'Pregunta "' || left(coalesce(v_pregunta.enunciado, ''), 60)
                || '": le falta la solución con su explicación.';
        end if;
    end loop;

    return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8.2 CRUD de contenido
--
-- Operaciones upsert con lista blanca de campos: el jsonb p_datos determina
-- que columnas se tocan (p_datos ? 'campo'). No existe borrado por RPC: la
-- despublicacion es siempre la via para retirar contenido, respetando las
-- FK restrict del esquema.
-- ---------------------------------------------------------------------------

create or replace function expotec_admin_guardar_curso(
    p_id uuid,
    p_datos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid;
    v_estado text;
    v_inconveniente text;
begin
    perform expotec_guard_admin();

    -- Alta: nombre obligatorio; el resto toma sus valores por defecto.
    if p_id is null then
        if p_datos is null or p_datos ->> 'nombre' is null
           or btrim(p_datos ->> 'nombre') = '' then
            raise exception 'El curso necesita un nombre.';
        end if;

        insert into cursos (nombre, descripcion, lema, monograma, logo,
                            color_acento, imagen_url, orden, estado_publicacion)
        values (
            btrim(p_datos ->> 'nombre'),
            p_datos ->> 'descripcion',
            p_datos ->> 'lema',
            p_datos ->> 'monograma',
            p_datos ->> 'logo',
            coalesce(p_datos ->> 'color_acento', '#8e05c2'),
            p_datos ->> 'imagen_url',
            coalesce((p_datos ->> 'orden')::integer, 0),
            coalesce(p_datos ->> 'estado_publicacion', 'borrador')
        )
        returning id into v_id;

        return v_id;
    end if;

    update cursos
    set
        nombre = case when p_datos ? 'nombre' then btrim(p_datos ->> 'nombre') else nombre end,
        descripcion = case when p_datos ? 'descripcion' then p_datos ->> 'descripcion' else descripcion end,
        lema = case when p_datos ? 'lema' then p_datos ->> 'lema' else lema end,
        monograma = case when p_datos ? 'monograma' then p_datos ->> 'monograma' else monograma end,
        logo = case when p_datos ? 'logo' then p_datos ->> 'logo' else logo end,
        color_acento = case when p_datos ? 'color_acento' then p_datos ->> 'color_acento' else color_acento end,
        imagen_url = case when p_datos ? 'imagen_url' then p_datos ->> 'imagen_url' else imagen_url end,
        orden = case when p_datos ? 'orden' then coalesce((p_datos ->> 'orden')::integer, 0) else orden end
    where id = p_id
    returning id into v_id;

    if v_id is null then
        raise exception 'El curso no existe.';
    end if;

    v_estado := p_datos ->> 'estado_publicacion';
    if v_estado is not null and v_estado in ('borrador', 'publicado', 'oculto') then
        if v_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_curso(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update cursos
        set estado_publicacion = v_estado
        where id = p_id;
    elsif v_estado is not null then
        raise exception 'El estado del curso debe ser borrador, publicado u oculto.';
    end if;

    return p_id;
end;
$$;

create or replace function expotec_admin_guardar_unidad(
    p_id uuid,
    p_datos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid;
    v_estado text;
    v_orden integer;
    v_inconveniente text;
begin
    perform expotec_guard_admin();

    if p_id is null then
        if p_datos is null or p_datos ->> 'curso_id' is null then
            raise exception 'La unidad necesita el curso al que pertenece.';
        end if;
        if p_datos ->> 'nombre' is null or btrim(p_datos ->> 'nombre') = '' then
            raise exception 'La unidad necesita un nombre.';
        end if;

        select coalesce(max(orden) + 1, 0)::integer into v_orden
        from unidades where curso_id = (p_datos ->> 'curso_id')::uuid;

        insert into unidades (curso_id, nombre, descripcion, orden, estado_publicacion)
        values (
            (p_datos ->> 'curso_id')::uuid,
            btrim(p_datos ->> 'nombre'),
            p_datos ->> 'descripcion',
            coalesce((p_datos ->> 'orden')::integer, v_orden),
            coalesce(p_datos ->> 'estado_publicacion', 'borrador')
        )
        returning id into v_id;

        return v_id;
    end if;

    update unidades
    set
        nombre = case when p_datos ? 'nombre' then btrim(p_datos ->> 'nombre') else nombre end,
        descripcion = case when p_datos ? 'descripcion' then p_datos ->> 'descripcion' else descripcion end,
        orden = case when p_datos ? 'orden' then coalesce((p_datos ->> 'orden')::integer, 0) else orden end
    where id = p_id
    returning id into v_id;

    if v_id is null then
        raise exception 'La unidad no existe.';
    end if;

    v_estado := p_datos ->> 'estado_publicacion';
    if v_estado is not null and v_estado in ('borrador', 'publicado', 'bloqueada', 'oculta') then
        if v_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_unidad(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update unidades
        set estado_publicacion = v_estado
        where id = p_id;
    elsif v_estado is not null then
        raise exception 'El estado de la unidad no es valido.';
    end if;

    return p_id;
end;
$$;

create or replace function expotec_admin_guardar_leccion(
    p_id uuid,
    p_datos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid;
    v_estado text;
    v_orden integer;
    v_inconveniente text;
begin
    perform expotec_guard_admin();

    if p_id is null then
        if p_datos is null or p_datos ->> 'unidad_id' is null then
            raise exception 'La clase necesita la unidad a la que pertenece.';
        end if;
        if p_datos ->> 'titulo' is null or btrim(p_datos ->> 'titulo') = '' then
            raise exception 'La clase necesita un título.';
        end if;
        if p_datos ->> 'explicacion' is null or btrim(p_datos ->> 'explicacion') = '' then
            raise exception 'La clase necesita su explicación.';
        end if;

        select coalesce(max(orden) + 1, 0)::integer into v_orden
        from lecciones where unidad_id = (p_datos ->> 'unidad_id')::uuid;

        insert into lecciones (unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
        values (
            (p_datos ->> 'unidad_id')::uuid,
            btrim(p_datos ->> 'titulo'),
            p_datos ->> 'explicacion',
            p_datos ->> 'ejemplo_codigo',
            coalesce((p_datos ->> 'orden')::integer, v_orden),
            coalesce(p_datos ->> 'estado_publicacion', 'borrador')
        )
        returning id into v_id;

        return v_id;
    end if;

    update lecciones
    set
        titulo = case when p_datos ? 'titulo' then btrim(p_datos ->> 'titulo') else titulo end,
        explicacion = case when p_datos ? 'explicacion' then p_datos ->> 'explicacion' else explicacion end,
        ejemplo_codigo = case when p_datos ? 'ejemplo_codigo' then p_datos ->> 'ejemplo_codigo' else ejemplo_codigo end,
        orden = case when p_datos ? 'orden' then coalesce((p_datos ->> 'orden')::integer, 0) else orden end
    where id = p_id
    returning id into v_id;

    if v_id is null then
        raise exception 'La clase no existe.';
    end if;

    v_estado := p_datos ->> 'estado_publicacion';
    if v_estado is not null and v_estado in ('borrador', 'publicado', 'bloqueada', 'oculta') then
        if v_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_leccion(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update lecciones
        set estado_publicacion = v_estado
        where id = p_id;
    elsif v_estado is not null then
        raise exception 'El estado de la clase no es valido.';
    end if;

    return p_id;
end;
$$;

create or replace function expotec_admin_guardar_pregunta(
    p_id uuid,
    p_datos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid;
    v_estado text;
    v_orden integer;
    v_inconveniente text;
begin
    perform expotec_guard_admin();

    if p_id is null then
        if p_datos is null or p_datos ->> 'leccion_id' is null then
            raise exception 'La actividad necesita la clase a la que pertenece.';
        end if;
        if p_datos ->> 'enunciado' is null or btrim(p_datos ->> 'enunciado') = '' then
            raise exception 'La actividad necesita un enunciado.';
        end if;

        select coalesce(max(orden) + 1, 0)::integer into v_orden
        from preguntas where leccion_id = (p_datos ->> 'leccion_id')::uuid;

        insert into preguntas (leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
        values (
            (p_datos ->> 'leccion_id')::uuid,
            p_datos ->> 'enunciado',
            coalesce(p_datos ->> 'tipo', 'seleccion'),
            p_datos -> 'datos',
            coalesce((p_datos ->> 'orden')::integer, v_orden),
            coalesce(p_datos ->> 'estado_publicacion', 'borrador')
        )
        returning id into v_id;

        return v_id;
    end if;

    update preguntas
    set
        enunciado = case when p_datos ? 'enunciado' then p_datos ->> 'enunciado' else enunciado end,
        datos = case when p_datos ? 'datos' then p_datos -> 'datos' else datos end,
        orden = case when p_datos ? 'orden' then coalesce((p_datos ->> 'orden')::integer, 0) else orden end
    where id = p_id
    returning id into v_id;

    if v_id is null then
        raise exception 'La actividad no existe.';
    end if;

    v_estado := p_datos ->> 'estado_publicacion';
    if v_estado is not null and v_estado in ('borrador', 'publicado', 'oculta') then
        if v_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_pregunta(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update preguntas
        set estado_publicacion = v_estado
        where id = p_id;
    elsif v_estado is not null then
        raise exception 'El estado de la actividad no es valido.';
    end if;

    return p_id;
end;
$$;

-- Alta atomica de una actividad de seleccion completa: pregunta, sus opciones
-- con orden 0..n-1 y asociado la solucion. Devuelve el id de la pregunta.
create or replace function expotec_admin_crear_pregunta_completa(
    p_leccion_id uuid,
    p_enunciado text,
    p_opciones jsonb,
    p_indice_correcta integer,
    p_explicacion text,
    p_orden integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_pregunta uuid;
    v_opciones_ids uuid[] := '{}';
    v_orden integer;
    v_indice integer;
    v_texto text;
begin
    perform expotec_guard_admin();

    if p_leccion_id is null or not exists (select 1 from lecciones where id = p_leccion_id) then
        raise exception 'La clase de origen no existe.';
    end if;
    if p_enunciado is null or btrim(p_enunciado) = '' then
        raise exception 'La actividad necesita un enunciado.';
    end if;
    if p_opciones is null or jsonb_typeof(p_opciones) <> 'array' then
        raise exception 'Las opciones deben venir en una lista.';
    end if;
    if (select count(*) from jsonb_array_elements_text(p_opciones) t(texto)) < 2 then
        raise exception 'La actividad necesita al menos dos opciones.';
    end if;
    if p_indice_correcta is null
       or p_indice_correcta < 0
       or p_indice_correcta >= jsonb_array_length(p_opciones) then
        raise exception 'El índice de la opción correcta no corresponde a la lista de opciones.';
    end if;
    if p_explicacion is null or btrim(p_explicacion) = '' then
        raise exception 'La actividad necesita su explicación.';
    end if;

    if p_orden is null then
        select coalesce(max(orden) + 1, 0)::integer into v_orden
        from preguntas where leccion_id = p_leccion_id;
    else
        v_orden := p_orden;
    end if;

    insert into preguntas (leccion_id, enunciado, tipo, orden, estado_publicacion)
    values (p_leccion_id, p_enunciado, 'seleccion', v_orden, 'borrador')
    returning id into v_pregunta;

    v_indice := 0;
    for v_texto in select elem::text from jsonb_array_elements_text(p_opciones) as elem
    loop
        if btrim(v_texto) = '' then
            raise exception 'Las opciones no pueden tener texto vacio.';
        end if;

        insert into opciones (pregunta_id, texto, orden)
        values (v_pregunta, btrim(v_texto), v_indice)
        returning id into v_opciones_ids[v_indice + 1];

        v_indice := v_indice + 1;
    end loop;

    insert into soluciones (pregunta_id, opcion_correcta_id, explicacion)
    values (
        v_pregunta,
        v_opciones_ids[p_indice_correcta + 1],
        p_explicacion
    );

    return v_pregunta;
end;
$$;

create or replace function expotec_admin_guardar_opcion(
    p_id uuid,
    p_datos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid;
    v_pregunta uuid;
    v_orden integer;
begin
    perform expotec_guard_admin();

    if p_id is null then
        if p_datos is null or p_datos ->> 'pregunta_id' is null then
            raise exception 'La opción necesita la actividad a la que pertenece.';
        end if;
        select coalesce(p_datos ->> 'pregunta_id', '')::uuid into v_pregunta;
        if not exists (select 1 from preguntas where id = v_pregunta) then
            raise exception 'La actividad no existe.';
        end if;

        select coalesce(max(orden) + 1, 0)::integer into v_orden
        from opciones where pregunta_id = v_pregunta;

        insert into opciones (pregunta_id, texto, orden)
        values (
            v_pregunta,
            coalesce(btrim(p_datos ->> 'texto'), 'Nueva opción'),
            coalesce((p_datos ->> 'orden')::integer, v_orden)
        )
        returning id into v_id;

        return v_id;
    end if;

    update opciones
    set
        texto = case when p_datos ? 'texto' then coalesce(btrim(p_datos ->> 'texto'), texto) else texto end,
        orden = case when p_datos ? 'orden' then coalesce((p_datos ->> 'orden')::integer, 0) else orden end
    where id = p_id
    returning id, pregunta_id into v_id, v_pregunta;

    if v_id is null then
        raise exception 'La opción no existe.';
    end if;

    return v_id;
end;
$$;

-- Upsert de la solucion de una actividad de seleccion: la opcion correcta debe
-- pertenecer a la pregunta y la explicacion no puede estar vacia.
create or replace function expotec_admin_definir_solucion(
    p_pregunta_id uuid,
    p_opcion_id uuid,
    p_explicacion text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    perform expotec_guard_admin();

    if not exists (select 1 from preguntas where id = p_pregunta_id) then
        raise exception 'La actividad no existe.';
    end if;
    if p_opcion_id is null
       or not exists (
            select 1 from opciones
            where id = p_opcion_id and pregunta_id = p_pregunta_id
       ) then
        raise exception 'La opción correcta debe pertenecer a la actividad.';
    end if;
    if p_explicacion is null or btrim(p_explicacion) = '' then
        raise exception 'La explicación de la solución no puede estar vacía.';
    end if;

    insert into soluciones (pregunta_id, opcion_correcta_id, explicacion)
    values (p_pregunta_id, p_opcion_id, p_explicacion)
    on conflict (pregunta_id) do update
        set opcion_correcta_id = excluded.opcion_correcta_id,
            explicacion = excluded.explicacion;
end;
$$;

-- Cambio de estado de publicacion por tipo de contenido. Publicar valida el
-- contenido: despublicar (borrador/oculto) es libre.
create or replace function expotec_admin_cambiar_estado_contenido(
    p_tipo text,
    p_id uuid,
    p_estado text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_inconveniente text;
begin
    perform expotec_guard_admin();

    if p_estado not in ('borrador', 'publicado', 'oculto', 'oculta', 'bloqueada') then
        raise exception 'El estado solicitado no es valido.';
    end if;

    if p_tipo = 'curso' then
        if p_estado not in ('borrador', 'publicado', 'oculto') then
            raise exception 'El curso no admite ese estado.';
        end if;
        if p_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_curso(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update cursos set estado_publicacion = p_estado where id = p_id;
    elsif p_tipo = 'unidad' then
        if p_estado not in ('borrador', 'publicado', 'oculta', 'bloqueada') then
            raise exception 'La unidad no admite ese estado.';
        end if;
        if p_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_unidad(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update unidades set estado_publicacion = p_estado where id = p_id;
    elsif p_tipo = 'leccion' then
        if p_estado not in ('borrador', 'publicado', 'oculta', 'bloqueada') then
            raise exception 'La clase no admite ese estado.';
        end if;
        if p_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_leccion(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update lecciones set estado_publicacion = p_estado where id = p_id;
    elsif p_tipo = 'pregunta' then
        if p_estado not in ('borrador', 'publicado', 'oculta') then
            raise exception 'La actividad no admite ese estado.';
        end if;
        if p_estado = 'publicado' then
            v_inconveniente := expotec_inconveniente_pregunta(p_id);
            if v_inconveniente is not null then
                raise exception '%', v_inconveniente;
            end if;
        end if;
        update preguntas set estado_publicacion = p_estado where id = p_id;
    else
        raise exception 'El tipo de contenido no existe.';
    end if;

    if not found then
        raise exception 'El contenido solicitado no existe.';
    end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8.3 Gestion de eventos
--
-- La unidad de competencia es el evento. Las reglas de transicion de estado
-- son estrictas: borrador -> programado -> activo -> cerrado. Activar exige el
-- desafio configurado y completo, y lo congela contra cambios.
-- ---------------------------------------------------------------------------

-- Un evento puede editarse mientras sea borrador o programado. Con partidas
-- en juego ya nada se toca tampoco: el desafio quedo congelado.
create or replace function expotec_evento_editable(p_evento_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_estado text;
begin
    if p_evento_id is null then
        return 'Falta el evento.';
    end if;

    select estado into v_estado
    from expotec_eventos where id = p_evento_id;

    if v_estado is null then
        return 'El evento no existe.';
    end if;

    if v_estado in ('activo', 'cerrado') then
        return 'El evento ya no admite cambios en su etapa ' || v_estado || '.';
    end if;

    return null;
end;
$$;

create or replace function expotec_admin_crear_evento(
    p_nombre text,
    p_descripcion text default null,
    p_fecha_inicio timestamptz default null,
    p_fecha_fin timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid;
begin
    perform expotec_guard_admin();

    if p_nombre is null or btrim(p_nombre) = '' then
        raise exception 'El evento necesita un nombre.';
    end if;
    if length(btrim(p_nombre)) > 120 then
        raise exception 'El nombre del evento no puede superar 120 caracteres.';
    end if;
    if p_fecha_inicio is not null and p_fecha_fin is not null
       and p_fecha_inicio > p_fecha_fin then
        raise exception 'La fecha de inicio no puede ser posterior a la fecha de cierre.';
    end if;

    insert into expotec_eventos (nombre, descripcion, fecha_inicio, fecha_fin, estado)
    values (btrim(p_nombre), p_descripcion, p_fecha_inicio, p_fecha_fin, 'borrador')
    returning id into v_id;

    return v_id;
end;
$$;

create or replace function expotec_admin_actualizar_evento(
    p_evento_id uuid,
    p_datos jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_inconveniente text;
    v_inicio timestamptz;
    v_fin timestamptz;
begin
    perform expotec_guard_admin();

    v_inconveniente := expotec_evento_editable(p_evento_id);
    if v_inconveniente is not null then
        raise exception '%', v_inconveniente;
    end if;

    if p_datos is null then
        raise exception 'Faltan los datos del evento.';
    end if;

    -- Las fechas vigentes se usan como base cuando solo cambia una de ellas.
    select min(e.fecha_inicio), max(e.fecha_fin)
    into v_inicio, v_fin
    from expotec_eventos e
    where e.id = p_evento_id;

    if p_datos ? 'fecha_inicio' then
        v_inicio := (p_datos ->> 'fecha_inicio')::timestamptz;
    end if;
    if p_datos ? 'fecha_fin' then
        v_fin := (p_datos ->> 'fecha_fin')::timestamptz;
    end if;

    if v_inicio is not null and v_fin is not null and v_inicio > v_fin then
        raise exception 'La fecha de inicio no puede ser posterior a la fecha de cierre.';
    end if;

    update expotec_eventos
    set
        nombre = case
            when p_datos ? 'nombre' then btrim(p_datos ->> 'nombre')
            else nombre
        end,
        descripcion = case
            when p_datos ? 'descripcion' then p_datos ->> 'descripcion'
            else descripcion
        end,
        fecha_inicio = case when p_datos ? 'fecha_inicio' then v_inicio else fecha_inicio end,
        fecha_fin = case when p_datos ? 'fecha_fin' then v_fin else fecha_fin end,
        updated_at = now()
    where id = p_evento_id;

    if not found then
        raise exception 'El evento no existe.';
    end if;
end;
$$;

create or replace function expotec_admin_cambiar_estado_evento(
    p_evento_id uuid,
    p_estado text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_actual text;
    v_inconveniente text;
    v_desafio uuid;
begin
    perform expotec_guard_admin();

    if p_estado not in ('borrador', 'programado', 'activo', 'cerrado') then
        raise exception 'El estado del evento no es valido.';
    end if;

    select estado into v_actual
    from expotec_eventos where id = p_evento_id;

    if v_actual is null then
        raise exception 'El evento no existe.';
    end if;

    if v_actual = p_estado then
        raise exception 'El evento ya se encuentra en ese estado.';
    end if;

    -- Transiciones permitidas y unica via: borrador -> programado -> activo ->
    -- cerrado. No se vuelve atras ni se salta etapas.
    if not (
        (v_actual = 'borrador' and p_estado = 'programado')
        or (v_actual = 'programado' and p_estado = 'activo')
        or (v_actual = 'activo' and p_estado = 'cerrado')
    ) then
        raise exception 'El evento no puede pasar de % a %.', v_actual, p_estado;
    end if;

    if p_estado = 'activo' then
        select id into v_desafio
        from expotec_desafios
        where evento_id = p_evento_id;

        v_inconveniente := expotec_inconveniente_desafio(v_desafio);
        if v_inconveniente is not null then
            raise exception '%', v_inconveniente;
        end if;

        update expotec_desafios
        set congelado_en = coalesce(congelado_en, now())
        where id = v_desafio;
    end if;

    update expotec_eventos
    set estado = p_estado,
        updated_at = now()
    where id = p_evento_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8.4 Configuracion del desafio
--
-- El desafio solo se configura mientras no existan partidas (el desafio
-- congelado con su primera partida). p_preguntas es la lista ordenada de uuid
-- de actividades tipo seleccion; las que superen la cantidad configurada se
-- descartan al azar en el servidor, por partida, en el momento de iniciar.
-- ---------------------------------------------------------------------------

create or replace function expotec_admin_configurar_desafio(
    p_evento_id uuid,
    p_params jsonb,
    p_preguntas uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_desafio_id uuid;
    v_actual record;
    v_pregunta uuid;
    v_inconveniente text;
    v_cantidad integer;
    v_puntos integer;
    v_tiempo integer;
    v_duracion integer;
    v_vidas integer;
    v_intentos integer;
    v_habilitadas integer;
begin
    perform expotec_guard_admin();

    if p_evento_id is null
       or not exists (select 1 from expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe.';
    end if;

    select * into v_actual from expotec_desafios where evento_id = p_evento_id;

    if v_actual.id is not null
       and (v_actual.congelado_en is not null
            or exists (select 1 from expotec_partidas where desafio_id = v_actual.id)) then
        raise exception 'El desafío ya está en juego: quedó congelado para proteger a los participantes.';
    end if;

    -- Valores: los vigentes (o el default) cuando el admin no envió el campo.
    v_cantidad := coalesce(
        (p_params ->> 'cantidad_preguntas')::integer,
        v_actual.cantidad_preguntas, 10
    );
    v_puntos := coalesce(
        (p_params ->> 'puntos_por_correcta')::integer,
        v_actual.puntos_por_correcta, 100
    );
    v_tiempo := coalesce(
        (p_params ->> 'tiempo_cuestionario_seg')::integer,
        case when p_params is not null and p_params ? 'tiempo_cuestionario_seg'
             then null::integer
             else v_actual.tiempo_cuestionario_seg end
    );
    v_duracion := coalesce(
        (p_params ->> 'duracion_juego_seg')::integer,
        v_actual.duracion_juego_seg, 180
    );
    v_vidas := coalesce(
        (p_params ->> 'vidas_juego')::integer,
        v_actual.vidas_juego, 3
    );
    v_intentos := coalesce(
        (p_params ->> 'intentos_permitidos')::integer,
        v_actual.intentos_permitidos, 1
    );

    if not (v_cantidad between 1 and 50) then
        raise exception 'El desafío debe tener entre 1 y 50 preguntas.';
    end if;
    if not (v_puntos between 1 and 10000) then
        raise exception 'El puntaje por acierto debe estar entre 1 y 10000.';
    end if;
    if v_tiempo is not null and not (v_tiempo between 30 and 7200) then
        raise exception 'El tiempo del cuestionario debe estar entre 30 y 7200 segundos.';
    end if;
    if not (v_duracion between 20 and 900) then
        raise exception 'La duración del juego debe estar entre 20 y 900 segundos.';
    end if;
    if not (v_vidas between 1 and 10) then
        raise exception 'Las vidas deben ser entre 1 y 10.';
    end if;
    if not (v_intentos between 1 and 20) then
        raise exception 'Los intentos permitidos deben ser entre 1 y 20.';
    end if;

    if p_preguntas is null or array_length(p_preguntas, 1) is null then
        raise exception 'El desafío necesita su lista de preguntas.';
    end if;

    v_habilitadas := 0;
    foreach v_pregunta in array array(select distinct x from unnest(p_preguntas) x)
    loop
        if not exists (
            select 1 from preguntas
            where id = v_pregunta
              and tipo = 'seleccion'
              and estado_publicacion = 'publicado'
        ) then
            raise exception 'Hay preguntas que no habilitan: falta alguna, está oculta o no son de selección.';
        end if;

        v_inconveniente := expotec_inconveniente_pregunta(v_pregunta);
        if v_inconveniente is not null then
            raise exception 'Pregunta [%]: %', left(v_pregunta::text, 8), v_inconveniente;
        end if;

        v_habilitadas := v_habilitadas + 1;
    end loop;

    if v_habilitadas < v_cantidad then
        raise exception 'Configuraste % preguntas para un desafío de %.',
            v_habilitadas, v_cantidad;
    end if;

    if v_actual.id is null then
        insert into expotec_desafios (
            evento_id, nombre, version, cantidad_preguntas, puntos_por_correcta,
            tiempo_cuestionario_seg, duracion_juego_seg, vidas_juego,
            intentos_permitidos, mostrar_soluciones
        ) values (
            p_evento_id,
            coalesce(p_params ->> 'nombre', 'Desafío ExpoTécnica'),
            coalesce((p_params ->> 'version')::integer, 1),
            v_cantidad, v_puntos, v_tiempo, v_duracion, v_vidas, v_intentos,
            coalesce((p_params ->> 'mostrar_soluciones')::boolean, true)
        )
        returning id into v_desafio_id;
    else
        update expotec_desafios
        set
            nombre = coalesce(p_params ->> 'nombre', nombre),
            version = coalesce((p_params ->> 'version')::integer, version),
            cantidad_preguntas = v_cantidad,
            puntos_por_correcta = v_puntos,
            tiempo_cuestionario_seg = v_tiempo,
            duracion_juego_seg = v_duracion,
            vidas_juego = v_vidas,
            intentos_permitidos = v_intentos,
            mostrar_soluciones = coalesce(
                (p_params ->> 'mostrar_soluciones')::boolean,
                mostrar_soluciones
            )
        where id = v_actual.id
        returning id into v_desafio_id;
    end if;

    -- Reordenado limpio del conjunto: borrado previo (el desafio no tiene
    -- partidas en este punto) y alta con orden secuencial.
    delete from expotec_desafio_preguntas where desafio_id = v_desafio_id;

    insert into expotec_desafio_preguntas (desafio_id, pregunta_id, orden)
    select v_desafio_id, p_preguntas[i], i - 1
    from generate_series(1, array_length(p_preguntas, 1)) as i;

    return v_desafio_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8.5 Estadisticas y resultados para el panel
-- ---------------------------------------------------------------------------

create or replace function expotec_admin_estadisticas_evento(p_evento_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_resultado jsonb;
begin
    perform expotec_guard_admin();

    if p_evento_id is null
       or not exists (select 1 from expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe.';
    end if;

    select jsonb_build_object(
        'participantes', (select count(*)::integer from expotec_participantes
                            where evento_id = p_evento_id),
        'partidas', (select count(*)::integer from expotec_partidas
                       where evento_id = p_evento_id),
        'por_estado', coalesce((
            select jsonb_object_agg(estado, cuenta)
            from (
                select estado, count(*)::integer cuenta
                from expotec_partidas
                where evento_id = p_evento_id
                group by estado
            ) e
        ), '{}'::jsonb),
        'resultados_publicados', (select count(*)::integer
            from expotec_resultados_publicos where evento_id = p_evento_id),
        'puntaje_promedio', (select round(avg(puntaje_total)::numeric, 2)
            from expotec_resultados_publicos where evento_id = p_evento_id),
        'acierto_promedio', (select round(
            100.0 * sum(correctas) / nullif(sum(correctas + incorrectas), 0),
            1)::numeric
            from expotec_resultados_publicos where evento_id = p_evento_id),
        'tiempo_cuestionario_promedio', (select round(avg(tiempo_cuestionario_seg)::numeric, 2)
            from expotec_resultados_publicos
            where evento_id = p_evento_id
              and tiempo_cuestionario_seg is not null)
    ) into v_resultado;

    return v_resultado;
end;
$$;

-- Partidas del evento con sus datos compactos para tablas del panel.
create or replace function expotec_admin_resultados_evento(
    p_evento_id uuid,
    p_estado text default null,
    p_limite integer default 100
)
returns table (
    partida_id uuid,
    alias varchar,
    estado varchar,
    grupo integer,
    estado_anterior varchar,
    respondidas integer,
    correctas integer,
    incorrectas integer,
    puntaje_cuestionario integer,
    puntaje_juego integer,
    puntaje_total integer,
    tiempo_cuestionario_seg numeric,
    iniciado_at timestamptz,
    finalizado_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    -- En funciones language sql no existe perform: el guard se invoca con
    -- select y devuelve error a quien no es administrador.
    select expotec_guard_admin();

    select
        p.id, p.alias, p.estado, p.grupo, p.estado_anterior,
        p.respondidas, p.correctas, p.incorrectas,
        p.puntaje_cuestionario, p.puntaje_juego, p.puntaje_total,
        p.tiempo_cuestionario_seg, p.iniciado_at, p.finalizado_at
    from expotec_partidas p
    where p.evento_id = p_evento_id
      and (p_estado is null or p.estado = p_estado)
    order by p.grupo desc, p.iniciado_at desc
    limit least(coalesce(p_limite, 100), 500);
$$;

-- Deshabilita o rehabilita una partida ya cerrada. Se guarda el estado previo
-- para que al devolverla no se convierta en 'finalizada' una partida que antes
-- era 'vencida' o 'abandonada'. Las partidas en curso no son candidatas.
create or replace function expotec_admin_cambiar_estado_partida(
    p_partida_id uuid,
    p_deshabilitar boolean
)
returns varchar
language plpgsql
security definer
set search_path = public
as $$
declare
    v_estado varchar;
    v_estado_anterior varchar;
    v_nuevo_estado varchar;
begin
    perform expotec_guard_admin();

    select estado, estado_anterior into v_estado, v_estado_anterior
    from expotec_partidas
    where id = p_partida_id;

    if v_estado is null then
        raise exception 'La partida no existe';
    end if;

    if p_deshabilitar and v_estado in ('finalizada', 'vencida', 'abandonada') then
        v_nuevo_estado := 'deshabilitada';
        update expotec_partidas
        set estado = v_nuevo_estado, estado_anterior = v_estado
        where id = p_partida_id;
        return v_nuevo_estado;
    end if;

    if not p_deshabilitar and v_estado = 'deshabilitada' then
        v_nuevo_estado := coalesce(v_estado_anterior, 'finalizada');
        update expotec_partidas
        set estado = v_nuevo_estado, estado_anterior = null
        where id = p_partida_id;
        return v_nuevo_estado;
    end if;

    raise exception 'Solo se pueden habilitar o deshabilitar partidas ya cerradas';
end;
$$;

-- Reinicia el ranking por grupos (tandas): deshabilita todos los intentos
-- cerrados hasta ahora (incluidos los de grupos rehabilitados) y mueve los
-- intentos en curso al grupo siguiente. Los datos no se borran: al rehabilitar
-- un grupo sus partidas vuelven a su estado original.
-- Devuelve cuantas partidas se deshabilitaron.
create or replace function expotec_admin_reiniciar_ranking(p_evento_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_grupo_actual integer;
    v_grupo_siguiente integer;
    v_count integer;
begin
    perform expotec_guard_admin();

    if not exists (select 1 from expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe';
    end if;

    select coalesce(max(grupo), 1) into v_grupo_actual
    from expotec_partidas
    where evento_id = p_evento_id;
    v_grupo_siguiente := v_grupo_actual + 1;

    -- Cerrados: salen del ranking pero conservan grupo y estado previo.
    update expotec_partidas
    set estado = 'deshabilitada', estado_anterior = estado
    where evento_id = p_evento_id
      and estado in ('finalizada', 'vencida', 'abandonada');

    get diagnostics v_count = row_count;

    -- En curso: pertenecen a la siguiente tanda y siguen jugando sin cortes.
    update expotec_partidas
    set grupo = v_grupo_siguiente
    where evento_id = p_evento_id
      and estado in ('creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego');

    return v_count;
end;
$$;

-- Rehabilita un grupo completo: devuelve sus partidas al ranking con el
-- estado que tenian antes de deshabilitarlas. Devuelve cuantas se devolvieron.
create or replace function expotec_admin_rehabilitar_grupo(
    p_evento_id uuid,
    p_grupo integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count integer;
begin
    perform expotec_guard_admin();

    if not exists (select 1 from expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe';
    end if;
    if p_grupo is null or p_grupo < 1 then
        raise exception 'El grupo no es valido';
    end if;

    update expotec_partidas
    set estado = coalesce(estado_anterior, 'finalizada'),
        estado_anterior = null
    where evento_id = p_evento_id
      and grupo = p_grupo
      and estado = 'deshabilitada';

    get diagnostics v_count = row_count;
    return v_count;
end;
$$;

-- Rehabilita todos los grupos deshabilitados del evento (atajo del panel).
create or replace function expotec_admin_rehabilitar_ranking(p_evento_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count integer;
begin
    perform expotec_guard_admin();

    if not exists (select 1 from expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe';
    end if;

    update expotec_partidas
    set estado = coalesce(estado_anterior, 'finalizada'),
        estado_anterior = null
    where evento_id = p_evento_id
      and estado = 'deshabilitada';

    get diagnostics v_count = row_count;
    return v_count;
end;
$$;

-- Cambia el alias de una partida (aplicable a habilitadas y deshabilitadas).
-- Valida reglas del alias igual que el resto del sistema y exige que el
-- nuevo alias normalizado no este tomado por otro participante del mismo
-- evento. Se propaga a la tabla publica de resultados.
create or replace function expotec_admin_renombrar_alias(
    p_partida_id uuid,
    p_nuevo_alias text
)
returns varchar
language plpgsql
security definer
set search_path = public
as $$
declare
    v_evento uuid;
    v_partida_alias varchar;
    v_norm text;
    v_error text;
    v_alias varchar;
begin
    perform expotec_guard_admin();

    v_error := expotec_alias_inconveniente(p_nuevo_alias);
    if v_error is not null then
        raise exception '%', v_error;
    end if;

    v_norm := expotec_alias_normalizado(p_nuevo_alias);

    select p.evento_id, p.alias
    into v_evento, v_partida_alias
    from expotec_partidas p
    where p.id = p_partida_id;

    if v_evento is null then
        raise exception 'La partida no existe';
    end if;

    if exists (
        select 1
        from expotec_partidas p
        where p.evento_id = v_evento
          and p.id <> p_partida_id
          and expotec_alias_normalizado(p.alias) = v_norm
    ) then
        raise exception 'Ese nombre ya esta en uso en este evento';
    end if;

    v_alias := btrim(p_nuevo_alias);

    update expotec_partidas
    set alias = v_alias
    where id = p_partida_id;

    update expotec_resultados_publicos
    set alias = v_alias,
        alias_normalizado = v_norm
    where partida_id = p_partida_id;

    return v_alias;
end;
$$;

-- Renombra el perfil de un usuario (visible en toda la app). Es una accion de
-- moderacion del equipo de Kodigo. El propio usuario puede seguir editando
-- su nombre desde la app despues de la correccion.
create or replace function expotec_admin_renombrar_perfil(
    p_usuario_id uuid,
    p_nombre text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    v_nombre text;
begin
    perform expotec_guard_admin();

    v_nombre := btrim(coalesce(p_nombre, ''));
    if length(v_nombre) < 2 or length(v_nombre) > 60 then
        raise exception 'El nombre debe tener entre 2 y 60 caracteres';
    end if;

    update perfiles
    set nombre_visible = v_nombre,
        updated_at = now()
    where id = p_usuario_id;

    return found;
end;
$$;

-- Lista de usuarios para la moderacion: paginada y con busqueda en nombre y
-- usuario. Solo admins; no expone datos sensibles (ni correo ni XP detallado).
create or replace function expotec_admin_lista_usuarios(
    p_busqueda text default '',
    p_limite integer default 50
)
returns table (
    usuario_id uuid,
    nombre_usuario text,
    nombre_visible text,
    nivel integer,
    experiencia integer,
    racha_dias integer,
    created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_q text;
begin
    perform expotec_guard_admin();

    v_q := lower(btrim(coalesce(p_busqueda, '')));

    return query
    select
        p.id, p.nombre_usuario, p.nombre_visible, p.nivel, p.experiencia,
        p.racha_dias, p.created_at
    from perfiles p
    where v_q = ''
       or lower(coalesce(p.nombre_usuario, '')) like '%' || v_q || '%'
       or lower(coalesce(p.nombre_visible, '')) like '%' || v_q || '%'
    order by p.created_at desc
    limit least(coalesce(p_limite, 50), 200);
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Grants de ejecucion
--
-- Supabase concede EXECUTE a PUBLIC por defecto en cada funcion nueva, asi
-- que cada RPC relevante recibe revoke de PUBLIC y grant solo a los roles que
-- la van a llamar desde la app. Los helpers internos no quedan ejecutables
-- desde el cliente.
-- ---------------------------------------------------------------------------

revoke all on function expotec_evento_activo() from public;

revoke all on function expotec_alias_disponible(uuid, text) from public;

revoke all on function expotec_iniciar_partida(uuid, text) from public;

revoke all on function expotec_estado_partida(uuid) from public;

revoke all on function expotec_responder(uuid, uuid, uuid) from public;

revoke all on function expotec_iniciar_juego(uuid) from public;

revoke all on function expotec_checkpoint_juego(uuid, jsonb) from public;

revoke all on function expotec_finalizar_juego(uuid, integer, integer, numeric, jsonb) from public;

revoke all on function expotec_abandonar(uuid) from public;

revoke all on function expotec_obtener_soluciones(uuid) from public;

revoke all on function expotec_mis_partidas(uuid) from public;

revoke all on function expotec_resultado_propio(uuid) from public;

revoke all on function expotec_ranking(uuid, integer) from public;

-- Panel de administracion: todos autenticados pueden ejecutarlas, el guard
-- interno distingue a los administradores y devuelve error al resto.
revoke all on function expotec_admin_es_admin() from public;

revoke all on function expotec_admin_guardar_curso(uuid, jsonb) from public;

revoke all on function expotec_admin_guardar_unidad(uuid, jsonb) from public;

revoke all on function expotec_admin_guardar_leccion(uuid, jsonb) from public;

revoke all on function expotec_admin_guardar_pregunta(uuid, jsonb) from public;

revoke all on function expotec_admin_crear_pregunta_completa(uuid, text, jsonb, integer, text, integer) from public;

revoke all on function expotec_admin_guardar_opcion(uuid, jsonb) from public;

revoke all on function expotec_admin_definir_solucion(uuid, uuid, text) from public;

revoke all on function expotec_admin_cambiar_estado_contenido(text, uuid, text) from public;

revoke all on function expotec_admin_crear_evento(text, text, timestamptz, timestamptz) from public;

revoke all on function expotec_admin_actualizar_evento(uuid, jsonb) from public;

revoke all on function expotec_admin_cambiar_estado_evento(uuid, text) from public;

revoke all on function expotec_admin_configurar_desafio(uuid, jsonb, uuid[]) from public;

revoke all on function expotec_admin_estadisticas_evento(uuid) from public;

revoke all on function expotec_admin_resultados_evento(uuid, text, integer) from public;

revoke all on function expotec_admin_cambiar_estado_partida(uuid, boolean) from public;

revoke all on function expotec_admin_reiniciar_ranking(uuid) from public;

revoke all on function expotec_admin_rehabilitar_ranking(uuid) from public;

revoke all on function expotec_admin_rehabilitar_grupo(uuid, integer) from public;

revoke all on function expotec_admin_renombrar_alias(uuid, text) from public;

revoke all on function expotec_admin_renombrar_perfil(uuid, text) from public;

revoke all on function expotec_admin_lista_usuarios(text, integer) from public;

-- Helpers internos: solo los consumen las demas funciones del servidor.
revoke all on function expotec_alias_normalizado(text) from public;
revoke all on function expotec_alias_inconveniente(text) from public;
revoke all on function expotec_evento_ventana_abierta(uuid) from public;
revoke all on function expotec_desafio_congelado(uuid) from public;
revoke all on function expotec_registrar_participante(uuid, text) from public;
revoke all on function expotec_intentos_gastados(uuid, uuid) from public;
revoke all on function expotec_progreso_partida_jsonb(uuid, boolean) from public;
revoke all on function expotec_tope_destruidos(numeric) from public;
revoke all on function expotec_guard_admin() from public;
-- expotec_inconveniente_pregunta se crea mas tarde: sus permisos van ahi.
revoke all on function expotec_inconveniente_leccion(uuid) from public;
revoke all on function expotec_inconveniente_unidad(uuid) from public;
revoke all on function expotec_inconveniente_curso(uuid) from public;
revoke all on function expotec_inconveniente_desafio(uuid) from public;
revoke all on function expotec_evento_editable(uuid) from public;

-- ---------------------------------------------------------------------------
-- 10. Datos iniciales
--
-- Evento y desafio listos para ExpoTecncia 2026, mas un curso interno oculto
-- con la unidad, la clase y las 10 actividades del cuestionario. Todos los
-- ids son deterministas para poder volver a correr el script.
--
-- Alta de administradores (manual, desde el dashboard):
--
--     insert into expotec_admins (usuario_id)
--     values ('<uuid del perfil>')
--     on conflict (usuario_id) do nothing;
-- ---------------------------------------------------------------------------

insert into cursos (id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion)
values (
    uuid(md5('kodigo:curso:expotec')),
    'Preparación ExpoTécnica',
    'Contenido interno con las actividades del cuestionario competitivo de la ExpoTécnica. No se publica en el catálogo.',
    'El camino hacia la ExpoTécnica',
    'EXP',
    null,
    '#700b97',
    0,
    'oculto'
)
on conflict (id) do nothing;

insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion)
values (
    uuid(md5('kodigo:unidad:expotec:u01')),
    uuid(md5('kodigo:curso:expotec')),
    'Cuestionario ExpoTécnica',
    'Las actividades que el desafío, la competencia, sortea cada partida.',
    0,
    'oculta'
)
on conflict (id) do nothing;

insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion)
values (
    uuid(md5('kodigo:leccion:expotec:l01')),
    uuid(md5('kodigo:unidad:expotec:u01')),
    'JavaScript para el desafío',
    'Repaso de los conceptos que se tocan en el cuestionario: operadores, tipos, arrays, funciones y objetos. Cada partida elige 10 actividades y mezcla sus opciones.',
    '// Un repaso rapido
const limite = 10;
const puntos = limite * 100;
const [a, b] = [1, "2"];
// 1 + "2" es "12": concatena cuando hay textos',
    0,
    'oculta'
)
on conflict (id) do nothing;

insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion)
select
    uuid(md5('kodigo:preg:expo:' || v.clave)),
    uuid(md5('kodigo:leccion:expotec:l01')),
    v.enunciado,
    'seleccion',
    v.orden,
    'publicado'
from (values
    ('q01', '¿Qué devuelve 2 + "2" en JavaScript?', 0),
    ('q02', '¿Qué palabra clave crea una variable que no se puede reasignar?', 1),
    ('q03', '¿Qué texto imprime typeof [] en la consola?', 2),
    ('q04', '¿Qué operador compara valor y tipo sin hacer conversiones?', 3),
    ('q05', '¿Qué devuelve [1, 2, 3].map(x => x * 2)?', 4),
    ('q06', '¿Qué método agrega un elemento al final de un array?', 5),
    ('q07', '¿Cómo se escribe una función flecha que devuelve x al cuadrado?', 6),
    ('q08', '¿Qué hace break dentro de un switch?', 7),
    ('q09', '¿Cómo se define un parámetro con valor por defecto en una función?', 8),
    ('q10', '¿Qué estructura repite su código mientras la condición sea verdadera?', 9)
) as v(clave, enunciado, orden)
on conflict (id) do nothing;

insert into opciones (id, pregunta_id, texto, orden)
select
    uuid(md5('kodigo:opt:expo:' || v.clave)),
    uuid(md5('kodigo:preg:expo:' || v.clave_preg)),
    v.texto,
    v.orden
from (values
    ('q01:o0', 'q01', 'El texto "22"', 0),
    ('q01:o1', 'q01', 'El número 4', 1),
    ('q01:o2', 'q01', 'NaN', 2),
    ('q01:o3', 'q01', 'Lanza un error de tipo', 3),
    ('q02:o0', 'q02', 'const', 0),
    ('q02:o1', 'q02', 'let', 1),
    ('q02:o2', 'q02', 'var', 2),
    ('q02:o3', 'q02', 'final', 3),
    ('q03:o0', 'q03', '"object"', 0),
    ('q03:o1', 'q03', '"array"', 1),
    ('q03:o2', 'q03', '"list"', 2),
    ('q03:o3', 'q03', 'Lanza un error', 3),
    ('q04:o0', 'q04', '===', 0),
    ('q04:o1', 'q04', '==', 1),
    ('q04:o2', 'q04', '=', 2),
    ('q04:o3', 'q04', '=>', 3),
    ('q05:o0', 'q05', 'El array [2, 4, 6]', 0),
    ('q05:o1', 'q05', 'El array original sin cambios', 1),
    ('q05:o2', 'q05', 'undefined', 2),
    ('q05:o3', 'q05', 'El número 6', 3),
    ('q06:o0', 'q06', 'push()', 0),
    ('q06:o1', 'q06', 'pop()', 1),
    ('q06:o2', 'q06', 'shift()', 2),
    ('q06:o3', 'q06', 'join()', 3),
    ('q07:o0', 'q07', 'x => x * x', 0),
    ('q07:o1', 'q07', 'function x * x', 1),
    ('q07:o2', 'q07', 'lambda(x) { x * x }', 2),
    ('q07:o3', 'q07', 'arrow(x) x * x', 3),
    ('q08:o0', 'q08', 'Termina el bloque switch', 0),
    ('q08:o1', 'q08', 'Continúa con el siguiente case', 1),
    ('q08:o2', 'q08', 'Reinicia el switch desde el principio', 2),
    ('q08:o3', 'q08', 'Lanza un error', 3),
    ('q09:o0', 'q09', 'function f(a = 5)', 0),
    ('q09:o1', 'q09', 'function f(a == 5)', 1),
    ('q09:o2', 'q09', 'function f(a -> 5)', 2),
    ('q09:o3', 'q09', 'function f(a: 5)', 3),
    ('q10:o0', 'q10', 'while', 0),
    ('q10:o1', 'q10', 'if', 1),
    ('q10:o2', 'q10', 'switch', 2),
    ('q10:o3', 'q10', 'try', 3)
) as v(clave, clave_preg, texto, orden)
on conflict (id) do nothing;

insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion)
select
    uuid(md5('kodigo:sol:expo:' || v.clave_preg)),
    uuid(md5('kodigo:preg:expo:' || v.clave_preg)),
    uuid(md5('kodigo:opt:expo:' || v.clave_opcion)),
    v.explicacion
from (values
    ('q01', 'q01:o0', 'El operador + concatena cuando un valor es texto: número sobre texto da la cadena "22".'),
    ('q02', 'q02:o0', 'const crea un enlace que no se puede reasignar; let y var sí lo permiten.'),
    ('q03', 'q03:o0', 'Los arrays son objetos: typeof no distingue y devuelve "object".'),
    ('q04', 'q04:o0', '=== compara valor y tipo; == hace conversiones antes de comparar y = es asignación.'),
    ('q05', 'q05:o0', 'map devuelve un array nuevo con cada elemento transformado; el array original queda igual.'),
    ('q06', 'q06:o0', 'push agrega al final; pop quita del final; shift quita del principio.'),
    ('q07', 'q07:o0', 'La flecha => desarrolla la función y su cuerpo es el valor devuelto.'),
    ('q08', 'q08:o0', 'break corta la ejecución del switch; sin break, cae en el siguiente case.'),
    ('q09', 'q09:o0', 'El valor por defecto se asigna con = en la firma: function f(a = 5).'),
    ('q10', 'q10:o0', 'while repite su bloque mientras la condición siga siendo verdadera.')
) as v(clave_preg, clave_opcion, explicacion)
on conflict (pregunta_id) do nothing;

insert into expotec_eventos (id, nombre, descripcion, fecha_inicio, fecha_fin, estado)
values (
    uuid(md5('kodigo:evento:expotec-2026')),
    'ExpoTécnica 2026',
    'El desafío competitivo de Kodigo: 10 preguntas de JavaScript y una partida de Core Defender para quedarse con el podio.',
    null,
    null,
    'activo'
)
on conflict (id) do nothing;

insert into expotec_desafios (
    evento_id, nombre, version, cantidad_preguntas, puntos_por_correcta,
    tiempo_cuestionario_seg, duracion_juego_seg, vidas_juego,
    intentos_permitidos, mostrar_soluciones
)
select
    e.id,
    'Desafío ExpoTécnica 2026',
    1,
    10,
    100,
    900,
    180,
    3,
    1,
    true
from expotec_eventos e
where e.id = uuid(md5('kodigo:evento:expotec-2026'))
on conflict (evento_id) do nothing;

insert into expotec_desafio_preguntas (desafio_id, pregunta_id, orden)
select
    d.id,
    q.id,
    v.orden
from (values
    ('q01', 0), ('q02', 1), ('q03', 2), ('q04', 3), ('q05', 4),
    ('q06', 5), ('q07', 6), ('q08', 7), ('q09', 8), ('q10', 9)
) as v(clave, orden)
join expotec_desafios d
    on d.evento_id = uuid(md5('kodigo:evento:expotec-2026'))
join preguntas q
    on q.id = uuid(md5('kodigo:preg:expo:' || v.clave))
on conflict (desafio_id, pregunta_id) do nothing;

-- ===========================================================================
-- ETAPA 8 - Actividades ampliadas, progreso individual, logros y estadisticas
--
-- Este bloque se ejecuta al final del script para poder reemplazar funciones
-- ya definidas sin duplicar la logica base. Es idempotente y no borra datos.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Tipos de actividad
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- 2. Columnas nuevas (compatibles con bases existentes)
-- ---------------------------------------------------------------------------

alter table perfiles add column if not exists ultima_actividad_en date;

alter table logros add column if not exists clave varchar(80);
alter table logros add column if not exists criterio jsonb;
alter table logros add column if not exists orden integer not null default 0;

create unique index if not exists logros_clave_idx
on logros (clave)
where clave is not null;

-- ---------------------------------------------------------------------------
-- 3. Progreso individual de unidades
--
-- Las unidades siguen teniendo su estado editorial global (publicado,
-- bloqueada, borrador...), pero el desbloqueo deja de modificarlo. Cada fila
-- de progreso_unidades es una unidad habilitada para ESE usuario.
-- ---------------------------------------------------------------------------

create table if not exists progreso_unidades (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references perfiles(id) on delete cascade,
    unidad_id uuid not null references unidades(id) on delete cascade,
    desbloqueada_en timestamptz not null default now(),
    completada_en timestamptz,
    constraint progreso_unidades_unique unique (usuario_id, unidad_id)
);

create index if not exists progreso_unidades_usuario_idx
on progreso_unidades (usuario_id);

alter table progreso_unidades enable row level security;

drop policy if exists "progreso de unidades propio visible" on progreso_unidades;
create policy "progreso de unidades propio visible"
on progreso_unidades
for select
to authenticated
using (usuario_id = auth.uid());

-- Sin politicas de insert/update/delete: el unico camino de escritura es
-- desbloquear_siguiente_unidad(), que es security definer.

-- ---------------------------------------------------------------------------
-- 4. Diccionario
-- ---------------------------------------------------------------------------

create table if not exists diccionario (
    id uuid primary key default gen_random_uuid(),
    termino varchar(80) not null,
    definicion text not null,
    categoria varchar(40) not null default 'general',
    ejemplo text,
    orden integer not null default 0,
    created_at timestamptz not null default now(),
    constraint diccionario_orden_check check (orden >= 0)
);

create unique index if not exists diccionario_termino_idx
on diccionario (lower(termino));

alter table diccionario enable row level security;

drop policy if exists "diccionario publico" on diccionario;
create policy "diccionario publico"
on diccionario
for select
to anon, authenticated
using (true);

-- ---------------------------------------------------------------------------
-- 5. Helpers de correccion
-- ---------------------------------------------------------------------------

create or replace function normalizar_codigo_respuesta(p_texto text)
returns text
language sql
immutable
as $$
    select case
        when p_texto is null then null
        else btrim(regexp_replace(replace(p_texto, E'\r\n', E'\n'), '\s+', ' ', 'g'))
    end;
$$;

create or replace function codigo_coincide_respuesta(
    p_enviado text,
    p_esperado text,
    p_estricto boolean default true
)
returns boolean
language sql
immutable
as $$
    select normalizar_codigo_respuesta(
               case when p_estricto then p_enviado else lower(p_enviado) end
           ) = normalizar_codigo_respuesta(
               case when p_estricto then p_esperado else lower(p_esperado) end
           );
$$;

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

-- Permisos de la sobrecarga jsonb recien creada.
revoke all on function comprobar_respuesta(uuid, jsonb) from public;

-- ---------------------------------------------------------------------------
-- 9. Nivel, racha, XP y logros
-- ---------------------------------------------------------------------------

create or replace function nivel_por_experiencia(p_experiencia integer)
returns integer
language sql
immutable
as $$
    select greatest(1, 1 + floor(greatest(coalesce(p_experiencia, 0), 0) / 100)::integer);
$$;

-- Calcula el avance real de un criterio de logro. Se usa tanto para otorgar
-- logros como para mostrar cuanto falta en la pantalla.
create or replace function progreso_logro(
    p_usuario_id uuid,
    p_criterio jsonb
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_tipo text;
    v_valor integer := 0;
begin
    if p_usuario_id is null or p_criterio is null then
        return 0;
    end if;

    v_tipo := p_criterio ->> 'tipo';

    if v_tipo = 'lecciones_aprobadas' then
        select count(*)::integer into v_valor
        from progreso_lecciones
        where usuario_id = p_usuario_id and aprobada;

    elsif v_tipo = 'unidades_completadas' then
        select count(*)::integer into v_valor
        from progreso_unidades
        where usuario_id = p_usuario_id and completada_en is not null;

    elsif v_tipo = 'cursos_completados' then
        select count(*)::integer into v_valor
        from cursos c
        where c.estado_publicacion = 'publicado'
          and exists (
              select 1
              from unidades u
              join lecciones l on l.unidad_id = u.id
              where u.curso_id = c.id and l.estado_publicacion = 'publicado'
          )
          and not exists (
              select 1
              from unidades u
              join lecciones l on l.unidad_id = u.id
              where u.curso_id = c.id
                and l.estado_publicacion = 'publicado'
                and not exists (
                    select 1 from progreso_lecciones p
                    where p.usuario_id = p_usuario_id
                      and p.leccion_id = l.id
                      and p.aprobada
                )
          );

    elsif v_tipo = 'actividades_realizadas' then
        select count(*)::integer into v_valor
        from respuestas_intento r
        join intentos i on i.id = r.intento_id
        where i.usuario_id = p_usuario_id;

    elsif v_tipo = 'respuestas_correctas' then
        select count(*)::integer into v_valor
        from respuestas_intento r
        join intentos i on i.id = r.intento_id
        where i.usuario_id = p_usuario_id and r.correcta;

    elsif v_tipo = 'racha_dias' then
        select coalesce(max(racha_dias), 0)::integer into v_valor
        from perfiles where id = p_usuario_id;

    elsif v_tipo = 'nivel' then
        select coalesce(max(nivel), 0)::integer into v_valor
        from perfiles where id = p_usuario_id;

    elsif v_tipo = 'experiencia' then
        select coalesce(max(experiencia), 0)::integer into v_valor
        from perfiles where id = p_usuario_id;

    end if;

    return coalesce(v_valor, 0);
end;
$$;

create or replace function evaluar_logros(p_usuario_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_logro record;
    v_objetivo integer;
    v_actual integer;
begin
    if p_usuario_id is null then
        return;
    end if;

    for v_logro in
        select id, criterio, experiencia_recompensa
        from logros
        where clave is not null and criterio is not null
    loop
        v_objetivo := coalesce((v_logro.criterio ->> 'objetivo')::integer, 0);
        v_actual := progreso_logro(p_usuario_id, v_logro.criterio);

        if v_objetivo > 0 and v_actual >= v_objetivo then
            insert into logros_usuario (usuario_id, logro_id)
            values (p_usuario_id, v_logro.id)
            on conflict (usuario_id, logro_id) do nothing;

            -- La recompensa se paga una sola vez: el insert recien ocurre la
            -- primera vez que se cumple el criterio.
            if found and coalesce(v_logro.experiencia_recompensa, 0) > 0 then
                update perfiles
                set experiencia = experiencia + v_logro.experiencia_recompensa,
                    nivel = nivel_por_experiencia(experiencia + v_logro.experiencia_recompensa),
                    updated_at = now()
                where id = p_usuario_id;
            end if;
        end if;
    end loop;
end;
$$;

create or replace function obtener_logros()
returns table (
    id uuid,
    clave varchar,
    nombre varchar,
    descripcion text,
    icono_url text,
    experiencia_recompensa integer,
    orden integer,
    obtenido boolean,
    obtenido_en timestamptz,
    actual integer,
    objetivo integer
)
language sql
stable
security definer
set search_path = public
as $$
    select l.id,
           l.clave,
           l.nombre,
           l.descripcion,
           l.icono_url,
           l.experiencia_recompensa,
           l.orden,
           lu.id is not null as obtenido,
           lu.obtenido_at as obtenido_en,
           progreso_logro(auth.uid(), l.criterio) as actual,
           coalesce((l.criterio ->> 'objetivo')::integer, 0) as objetivo
    from logros l
    left join logros_usuario lu
      on lu.logro_id = l.id and lu.usuario_id = auth.uid()
    where l.clave is not null
    order by l.orden, l.nombre;
$$;

-- ---------------------------------------------------------------------------
-- 10. Estadisticas reales
-- ---------------------------------------------------------------------------

create or replace function obtener_estadisticas()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_perfil record;
    v_cursos_iniciados integer := 0;
    v_cursos_completados integer := 0;
    v_unidades_completadas integer := 0;
    v_lecciones_completadas integer := 0;
    v_lecciones_aprobadas integer := 0;
    v_actividades integer := 0;
    v_correctas integer := 0;
    v_incorrectas integer := 0;
    v_intentos integer := 0;
    v_tiempo_seg integer := 0;
    v_logros integer := 0;
begin
    if v_usuario is null then
        return '{}'::jsonb;
    end if;

    select nivel, experiencia, racha_dias into v_perfil
    from perfiles where id = v_usuario;

    select count(distinct u.curso_id)::integer into v_cursos_iniciados
    from progreso_lecciones p
    join lecciones l on l.id = p.leccion_id
    join unidades u on u.id = l.unidad_id
    where p.usuario_id = v_usuario;

    select count(*)::integer into v_cursos_completados
    from cursos c
    where c.estado_publicacion = 'publicado'
      and exists (
          select 1 from unidades u
          join lecciones l on l.unidad_id = u.id
          where u.curso_id = c.id and l.estado_publicacion = 'publicado'
      )
      and not exists (
          select 1 from unidades u
          join lecciones l on l.unidad_id = u.id
          where u.curso_id = c.id
            and l.estado_publicacion = 'publicado'
            and not exists (
                select 1 from progreso_lecciones p
                where p.usuario_id = v_usuario
                  and p.leccion_id = l.id
                  and p.aprobada
            )
      );

    select count(*)::integer into v_unidades_completadas
    from progreso_unidades
    where usuario_id = v_usuario and completada_en is not null;

    select count(*) filter (where completada)::integer,
           count(*) filter (where aprobada)::integer
    into v_lecciones_completadas, v_lecciones_aprobadas
    from progreso_lecciones
    where usuario_id = v_usuario;

    select count(*)::integer,
           count(*) filter (where correcta)::integer,
           count(*) filter (where not correcta)::integer
    into v_actividades, v_correctas, v_incorrectas
    from respuestas_intento r
    join intentos i on i.id = r.intento_id
    where i.usuario_id = v_usuario;

    select count(*)::integer into v_intentos
    from intentos where usuario_id = v_usuario;

    select coalesce(sum(
               greatest(extract(epoch from (finalizado_at - iniciado_at)), 0)
           ), 0)::integer
    into v_tiempo_seg
    from intentos
    where usuario_id = v_usuario and finalizado_at is not null;

    select count(*)::integer into v_logros
    from logros_usuario where usuario_id = v_usuario;

    return jsonb_build_object(
        'cursos_iniciados', v_cursos_iniciados,
        'cursos_completados', v_cursos_completados,
        'unidades_completadas', v_unidades_completadas,
        'lecciones_completadas', v_lecciones_completadas,
        'lecciones_aprobadas', v_lecciones_aprobadas,
        'actividades_realizadas', v_actividades,
        'respuestas_correctas', v_correctas,
        'respuestas_incorrectas', v_incorrectas,
        'precision', case when v_actividades > 0
            then round(v_correctas::numeric * 100 / v_actividades, 1)
            else 0 end,
        'xp', coalesce(v_perfil.experiencia, 0),
        'nivel', coalesce(v_perfil.nivel, 1),
        'racha', coalesce(v_perfil.racha_dias, 0),
        'intentos', v_intentos,
        'tiempo_aprendizaje_seg', v_tiempo_seg,
        'logros_obtenidos', v_logros
    );
end;
$$;

create or replace function obtener_revision()
returns table (
    leccion_id uuid,
    leccion_titulo varchar,
    unidad_id uuid,
    unidad_nombre varchar,
    curso_id uuid,
    curso_nombre varchar,
    mejor_porcentaje numeric,
    ultimo_porcentaje numeric,
    aprobada boolean,
    intentos integer,
    actualizado_en timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    select p.leccion_id,
           l.titulo,
           u.id,
           u.nombre,
           c.id,
           c.nombre,
           p.mejor_porcentaje,
           p.ultimo_porcentaje,
           p.aprobada,
           p.intentos,
           p.updated_at
    from progreso_lecciones p
    join lecciones l on l.id = p.leccion_id
    join unidades u on u.id = l.unidad_id
    join cursos c on c.id = u.curso_id
    where p.usuario_id = auth.uid()
    order by p.updated_at desc;
$$;

-- ---------------------------------------------------------------------------
-- 11. Amistades (funcionalidad minima real sobre la tabla existente)
-- ---------------------------------------------------------------------------

create or replace function obtener_amistades()
returns table (
    amistad_id uuid,
    alias varchar,
    nivel integer,
    experiencia integer,
    racha_dias integer,
    estado varchar,
    direccion varchar,
    creada_en timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    select a.id,
           p.nombre_usuario,
           p.nivel,
           p.experiencia,
           p.racha_dias,
           a.estado,
           case when a.usuario_id = auth.uid() then 'enviada' else 'recibida' end,
           a.created_at
    from amistades a
    join perfiles p
      on p.id = case when a.usuario_id = auth.uid() then a.amigo_id else a.usuario_id end
    where a.usuario_id = auth.uid() or a.amigo_id = auth.uid()
    order by a.estado, a.created_at desc;
$$;

create or replace function enviar_solicitud_amistad(p_alias text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_amigo uuid;
    v_id uuid;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para enviar solicitudes';
    end if;

    if btrim(coalesce(p_alias, '')) = '' then
        raise exception 'Indica el nombre de usuario';
    end if;

    select id into v_amigo
    from perfiles
    where lower(nombre_usuario) = lower(btrim(p_alias));

    if v_amigo is null then
        raise exception 'No encontramos a esa persona';
    end if;

    if v_amigo = v_usuario then
        raise exception 'No puedes agregarte a ti mismo';
    end if;

    if exists (
        select 1 from amistades
        where (usuario_id = v_usuario and amigo_id = v_amigo)
           or (usuario_id = v_amigo and amigo_id = v_usuario)
    ) then
        raise exception 'Ya existe una solicitud o amistad con esa persona';
    end if;

    insert into amistades (usuario_id, amigo_id, estado)
    values (v_usuario, v_amigo, 'pendiente')
    returning id into v_id;

    return v_id;
end;
$$;

create or replace function responder_solicitud_amistad(
    p_amistad_id uuid,
    p_aceptar boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'Se necesita una sesion para responder solicitudes';
    end if;

    update amistades
    set estado = case when p_aceptar then 'aceptada' else 'rechazada' end
    where id = p_amistad_id
      and amigo_id = auth.uid()
      and estado = 'pendiente';

    if not found then
        raise exception 'La solicitud no existe o no te pertenece';
    end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 12. Finalizar intento: XP una sola vez, racha, nivel y logros
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 13. Validacion y administracion de todas las modalidades
-- ---------------------------------------------------------------------------

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

-- Guarda o actualiza una actividad de cualquier modalidad. Las opciones solo
-- se tocan si la actividad no tiene respuestas registradas, para no romper el
-- historial de los estudiantes.
create or replace function expotec_admin_guardar_actividad(
    p_id uuid,
    p_datos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id uuid := p_id;
    v_tipo text;
    v_leccion uuid;
    v_enunciado text;
    v_explicacion text;
    v_datos_pub jsonb;
    v_solucion jsonb;
    v_estado text;
    v_orden integer;
    v_opciones jsonb;
    v_indice integer;
    v_total integer;
    v_inconveniente text;
    v_usar_opciones boolean;
    v_opcion_id uuid;
begin
    perform expotec_guard_admin();

    v_tipo := coalesce(p_datos ->> 'tipo', 'seleccion');
    if v_tipo not in (
        'seleccion', 'verdadero_falso', 'completar_texto', 'completar_codigo',
        'ordenar', 'relacionar', 'escribir_codigo', 'corregir_codigo',
        'salida_codigo', 'predecir', 'bloques'
    ) then
        raise exception 'El tipo de actividad no existe: %.', v_tipo;
    end if;

    v_enunciado := btrim(coalesce(p_datos ->> 'enunciado', ''));
    if v_enunciado = '' then
        raise exception 'La actividad necesita un enunciado.';
    end if;

    v_explicacion := coalesce(p_datos ->> 'explicacion', '');
    v_datos_pub := coalesce(p_datos -> 'datos', '{}'::jsonb);
    v_solucion := coalesce(p_datos -> 'solucion', '{}'::jsonb);
    v_estado := coalesce(p_datos ->> 'estado_publicacion', 'borrador');

    if v_estado not in ('borrador', 'publicado', 'oculta') then
        raise exception 'El estado de la actividad no es valido.';
    end if;

    v_usar_opciones := v_tipo in ('seleccion', 'verdadero_falso', 'ordenar')
        or (v_tipo in ('salida_codigo', 'predecir')
            and coalesce(v_datos_pub ->> 'modo', 'texto') = 'opciones');

    if v_id is null then
        v_leccion := (p_datos ->> 'leccion_id')::uuid;
        if v_leccion is null then
            raise exception 'La actividad necesita la clase a la que pertenece.';
        end if;

        select coalesce(max(orden) + 1, 0)::integer into v_orden
        from preguntas where leccion_id = v_leccion;

        insert into preguntas (leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
        values (v_leccion, v_enunciado, v_tipo, v_datos_pub, v_orden, 'borrador')
        returning id into v_id;
    else
        select leccion_id into v_leccion from preguntas where id = v_id;
        if v_leccion is null then
            raise exception 'La actividad no existe.';
        end if;

        update preguntas
        set enunciado = v_enunciado,
            tipo = v_tipo,
            datos = v_datos_pub,
            estado_publicacion = 'borrador'
        where id = v_id;
    end if;

    if v_usar_opciones then
        v_opciones := coalesce(p_datos -> 'opciones', '[]'::jsonb);
        if jsonb_typeof(v_opciones) <> 'array' or jsonb_array_length(v_opciones) < 2 then
            raise exception 'La actividad necesita al menos dos opciones.';
        end if;

        v_indice := coalesce((p_datos ->> 'indice_correcta')::integer, 0);
        v_total := jsonb_array_length(v_opciones);

        if v_tipo = 'ordenar' then
            v_indice := -1;
        elsif v_indice < 0 or v_indice >= v_total then
            raise exception 'La opcion correcta no es valida.';
        end if;

        if exists (select 1 from respuestas_intento where pregunta_id = v_id) then
            raise exception 'No se pueden cambiar las opciones de una actividad que ya tiene respuestas. Crea una actividad nueva.';
        end if;

        delete from soluciones where pregunta_id = v_id;
        delete from opciones where pregunta_id = v_id;

        insert into opciones (pregunta_id, texto, orden)
        select v_id, btrim(value), (row_number() over () - 1)::integer
        from jsonb_array_elements_text(v_opciones);

        if v_tipo = 'ordenar' then
            insert into soluciones (pregunta_id, solucion, explicacion)
            values (
                v_id,
                jsonb_build_object('orden', (
                    select jsonb_agg(id order by orden)
                    from opciones where pregunta_id = v_id
                )),
                v_explicacion
            );
        else
            select id into v_opcion_id
            from opciones
            where pregunta_id = v_id and orden = v_indice;

            insert into soluciones (pregunta_id, opcion_correcta_id, solucion, explicacion)
            values (v_id, v_opcion_id, v_solucion, v_explicacion);
        end if;
    else
        if exists (select 1 from respuestas_intento where pregunta_id = v_id) then
            raise exception 'La actividad ya tiene respuestas de estudiantes. Crea una actividad nueva en lugar de editarla.';
        end if;
        -- Al pasar de una modalidad con opciones a una sin opciones se borran
        -- las filas huerfanas para que no queden opciones obsoletas visibles.
        delete from opciones where pregunta_id = v_id;
        insert into soluciones (pregunta_id, opcion_correcta_id, solucion, explicacion)
        values (v_id, null, v_solucion, v_explicacion)
        on conflict (pregunta_id) do update
            set opcion_correcta_id = null,
                solucion = excluded.solucion,
                explicacion = excluded.explicacion;
    end if;

    if v_estado = 'publicado' then
        v_inconveniente := expotec_inconveniente_pregunta(v_id);
        if v_inconveniente is not null then
            raise exception '%', v_inconveniente;
        end if;
        update preguntas set estado_publicacion = 'publicado' where id = v_id;
    elsif v_estado = 'oculta' then
        update preguntas set estado_publicacion = 'oculta' where id = v_id;
    end if;

    return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 14. Backfill de desbloqueos para usuarios existentes
-- ---------------------------------------------------------------------------

-- Ultima actividad real de cada perfil: la racha nueva se apoya en esta fecha
-- para no reiniciar rachas ya ganadas al migrar.
update perfiles p
set ultima_actividad_en = sub.ultimo
from (
    select usuario_id, max(finalizado_at)::date as ultimo
    from intentos
    where finalizado_at is not null
    group by usuario_id
) sub
where sub.usuario_id = p.id
  and p.ultima_actividad_en is null;

insert into progreso_unidades (usuario_id, unidad_id, completada_en)
select p.id, u.id,
       case
           when not exists (
               select 1
               from lecciones l
               where l.unidad_id = u.id
                 and l.estado_publicacion = 'publicado'
                 and not exists (
                     select 1 from progreso_lecciones pl
                     where pl.usuario_id = p.id
                       and pl.leccion_id = l.id
                       and pl.aprobada
                 )
           ) then now()
           else null
       end
from perfiles p
join unidades u on true
where u.estado_publicacion = 'publicado'
   or (
       u.estado_publicacion = 'bloqueada'
       and not exists (
           select 1
           from lecciones l
           where l.unidad_id = u.id
             and l.estado_publicacion = 'publicado'
             and not exists (
                 select 1 from progreso_lecciones pl
                 where pl.usuario_id = p.id
                   and pl.leccion_id = l.id
                   and pl.aprobada
             )
       )
   )
on conflict (usuario_id, unidad_id) do nothing;

-- ---------------------------------------------------------------------------
-- 15. Permisos
-- ---------------------------------------------------------------------------

revoke all on function normalizar_codigo_respuesta(text) from public;
revoke all on function codigo_coincide_respuesta(text, text, boolean) from public;
revoke all on function nivel_por_experiencia(integer) from public;
revoke all on function progreso_logro(uuid, jsonb) from public;
revoke all on function evaluar_logros(uuid) from public;

revoke all on function obtener_logros() from public;

revoke all on function obtener_estadisticas() from public;

revoke all on function obtener_revision() from public;

revoke all on function obtener_amistades() from public;

revoke all on function enviar_solicitud_amistad(text) from public;

revoke all on function responder_solicitud_amistad(uuid, boolean) from public;

revoke all on function expotec_admin_guardar_actividad(uuid, jsonb) from public;

-- ===========================================================================
-- 16. Logros, diccionario y consulta de unidades desbloqueadas
-- ===========================================================================

-- Unidades que ESTE usuario tiene habilitadas. La pantalla de curso la usa
-- para decidir si puede entrar; el servidor la vuelve a validar al iniciar
-- un intento.
create or replace function obtener_unidades_desbloqueadas()
returns table (
    unidad_id uuid,
    completada boolean
)
language sql
stable
security definer
set search_path = public
as $$
    select pu.unidad_id, pu.completada_en is not null
    from progreso_unidades pu
    where pu.usuario_id = auth.uid();
$$;

revoke all on function obtener_unidades_desbloqueadas() from public;

create or replace function obtener_diccionario()
returns table (
    termino varchar,
    definicion text,
    categoria varchar,
    ejemplo text
)
language sql
stable
security definer
set search_path = public
as $$
    select d.termino, d.definicion, d.categoria, d.ejemplo
    from diccionario d
    order by d.categoria, d.orden, d.termino;
$$;

revoke all on function obtener_diccionario() from public;

-- ---------------------------------------------------------------------------
-- 16.1 Catalogo de logros (se auto-otorgan al cerrar un intento)
-- ---------------------------------------------------------------------------

insert into logros (nombre, descripcion, icono_url, experiencia_recompensa, clave, criterio, orden)
values
(
    'Primer paso',
    'Aprobá tu primera lección.',
    'looks_one',
    10,
    'primera_leccion',
    '{"tipo": "lecciones_aprobadas", "objetivo": 1}'::jsonb,
    10
),
(
    'Constancia',
    'Aprobá 5 lecciones.',
    'trending_up',
    25,
    'cinco_lecciones',
    '{"tipo": "lecciones_aprobadas", "objetivo": 5}'::jsonb,
    20
),
(
    'Estudioso',
    'Aprobá 10 lecciones.',
    'school',
    50,
    'diez_lecciones',
    '{"tipo": "lecciones_aprobadas", "objetivo": 10}'::jsonb,
    30
),
(
    'Unidad conquistada',
    'Completá tu primera unidad.',
    'flag',
    40,
    'primera_unidad',
    '{"tipo": "unidades_completadas", "objetivo": 1}'::jsonb,
    40
),
(
    'Explorador',
    'Completá 3 unidades.',
    'map',
    80,
    'tres_unidades',
    '{"tipo": "unidades_completadas", "objetivo": 3}'::jsonb,
    50
),
(
    'Curso completo',
    'Aprobá todas las lecciones publicadas de un curso.',
    'workspace_premium',
    150,
    'curso_completado',
    '{"tipo": "cursos_completados", "objetivo": 1}'::jsonb,
    60
),
(
    'Cincuenta prácticas',
    'Respondé 50 actividades.',
    'bolt',
    50,
    'cincuenta_actividades',
    '{"tipo": "actividades_realizadas", "objetivo": 50}'::jsonb,
    70
),
(
    'Cien aciertos',
    'Acumulá 100 respuestas correctas.',
    'verified',
    100,
    'cien_correctas',
    '{"tipo": "respuestas_correctas", "objetivo": 100}'::jsonb,
    80
),
(
    'Racha de 3',
    'Practicá 3 días seguidos.',
    'local_fire_department',
    30,
    'racha_3',
    '{"tipo": "racha_dias", "objetivo": 3}'::jsonb,
    90
),
(
    'Racha de 7',
    'Practicá 7 días seguidos.',
    'whatshot',
    70,
    'racha_7',
    '{"tipo": "racha_dias", "objetivo": 7}'::jsonb,
    100
),
(
    'Nivel 5',
    'Alcanzá el nivel 5.',
    'military_tech',
    100,
    'nivel_5',
    '{"tipo": "nivel", "objetivo": 5}'::jsonb,
    110
),
(
    '500 de experiencia',
    'Acumulá 500 puntos de experiencia.',
    'stars',
    100,
    'xp_500',
    '{"tipo": "experiencia", "objetivo": 500}'::jsonb,
    120
)
on conflict (nombre) do update
set descripcion = excluded.descripcion,
    icono_url = excluded.icono_url,
    experiencia_recompensa = excluded.experiencia_recompensa,
    clave = excluded.clave,
    criterio = excluded.criterio,
    orden = excluded.orden;

-- ---------------------------------------------------------------------------
-- 16.2 Glosario real (diccionario del curso de JavaScript)
-- ---------------------------------------------------------------------------

insert into diccionario (termino, definicion, categoria, ejemplo, orden)
values
('variable', 'Espacio con nombre donde se guarda un valor que puede cambiar durante el programa.', 'Bases', 'let edad = 15;', 1),
('constante', 'Variable cuyo valor no se reasigna después de declararla. Se declara con const.', 'Bases', 'const nombre = "Fury";', 2),
('string', 'Tipo de dato de texto. Se escribe entre comillas simples, dobles o backticks.', 'Tipos de dato', '"Kodigo"', 3),
('number', 'Tipo de dato numérico. Incluye enteros y decimales.', 'Tipos de dato', '42 / 3.14', 4),
('boolean', 'Tipo de dato que solo puede ser true o false.', 'Tipos de dato', 'let activo = true;', 5),
('null', 'Valor que representa la ausencia intencional de un dato.', 'Tipos de dato', 'let dato = null;', 6),
('undefined', 'Valor que tiene una variable declarada a la que todavía no se le asignó nada.', 'Tipos de dato', 'let x; // undefined', 7),
('array', 'Lista ordenada de valores a los que se accede por su índice, empezando en 0.', 'Estructuras', 'const notas = [8, 9, 10];', 8),
('objeto', 'Estructura que guarda datos con nombre (propiedades) y funciones (métodos).', 'Estructuras', 'const perro = { nombre: "Fury" };', 9),
('propiedad', 'Par nombre-valor dentro de un objeto.', 'Estructuras', 'perro.nombre', 10),
('método', 'Función que pertenece a un objeto o a un tipo de dato.', 'Estructuras', '"kodigo".toUpperCase()', 11),
('función', 'Bloque de código reutilizable que recibe datos y puede devolver un resultado.', 'Funciones', 'function sumar(a, b) { return a + b; }', 12),
('parámetro', 'Nombre del dato que recibe una función en su definición.', 'Funciones', 'function saludar(nombre) { }', 13),
('argumento', 'Valor concreto que se pasa a una función al llamarla.', 'Funciones', 'saludar("Ana")', 14),
('retorno', 'Valor que devuelve una función con la palabra clave return.', 'Funciones', 'return total;', 15),
('operador', 'Símbolo que realiza una operación entre valores: suma, comparación, lógica.', 'Operadores', 'a + b, a === b, a && b', 16),
('condicional', 'Estructura que decide qué camino ejecutar según una condición.', 'Control de flujo', 'if (edad >= 18) { }', 17),
('bucle', 'Estructura que repite un bloque de código mientras se cumpla una condición.', 'Control de flujo', 'for (let i = 0; i < 3; i++) { }', 18),
('índice', 'Posición numérica de un elemento dentro de un array o string.', 'Estructuras', 'notas[0]', 19),
('expresión', 'Combinación de valores y operadores que produce un resultado.', 'Bases', '2 * (3 + 4)', 20),
('bloque', 'Conjunto de instrucciones agrupadas entre llaves.', 'Bases', '{ console.log("hola"); }', 21),
('consola', 'Herramienta para mostrar mensajes y revisar resultados mientras programás.', 'Bases', 'console.log("hola");', 22)
on conflict (lower(termino)) do update
set definicion = excluded.definicion,
    categoria = excluded.categoria,
    ejemplo = excluded.ejemplo,
    orden = excluded.orden;

-- ===========================================================================
-- 17. Proteccion de respuestas historicas
--
-- Las actividades viejas guardaban el valor correcto dentro de preguntas.datos,
-- que es legible por cualquiera con la pregunta publicada. Se mueve la
-- respuesta a soluciones (que tiene RLS sin policies de lectura) y se limpia
-- datos. La correccion mantiene el fallback para no romper nada.
-- ===========================================================================

update soluciones s
set solucion = coalesce(nullif(s.solucion, 'null'::jsonb), '{}'::jsonb)
    || jsonb_build_object(
        'valor', p.datos -> 'valor',
        'alternativas', coalesce(p.datos -> 'alternativas', '[]'::jsonb)
    )
from preguntas p
where p.id = s.pregunta_id
  and p.tipo = 'completar_texto'
  and p.datos ? 'valor'
  and not (coalesce(s.solucion, '{}'::jsonb) ? 'valor');

update preguntas p
set datos = p.datos - 'valor' - 'alternativas'
where p.tipo = 'completar_texto'
  and (p.datos ? 'valor' or p.datos ? 'alternativas')
  and exists (
      select 1 from soluciones s
      where s.pregunta_id = p.id and s.solucion ? 'valor'
  );

update soluciones s
set solucion = coalesce(nullif(s.solucion, 'null'::jsonb), '{}'::jsonb)
    || jsonb_build_object('blancos', p.datos -> 'blancos')
from preguntas p
where p.id = s.pregunta_id
  and p.tipo = 'completar_codigo'
  and p.datos ? 'blancos'
  and not (coalesce(s.solucion, '{}'::jsonb) ? 'blancos');

update preguntas p
set datos = p.datos - 'blancos'
where p.tipo = 'completar_codigo'
  and p.datos ? 'blancos'
  and exists (
      select 1 from soluciones s
      where s.pregunta_id = p.id and s.solucion ? 'blancos'
  );

-- ===========================================================================
-- 18. Practica ampliada de JavaScript (nuevas modalidades)
--
-- Se agrega en un bloque aparte para no alterar el seed original de 53
-- actividades. Cada leccion suma practica con escribir_codigo,
-- corregir_codigo, salida_codigo, predecir, bloques y completar_*, con
-- dificultad creciente por unidad. Las respuestas viven en soluciones.
-- ===========================================================================

with lecciones_num as (
  select id, row_number() over (order by id) as n
  from lecciones
  where id between '30000000-0000-0000-0000-000000000001'::uuid
               and '30000000-0000-0000-0000-000000000010'::uuid
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:js2:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  -- Unidad 1 - Variables y tipos de datos
  ('js2:l01:a1', 1,
   E'¿Que imprime este programa?\nlet puntos = 4;\npuntos = puntos + 3;\nconsole.log(puntos);',
   'predecir',
   '{"codigo": "let puntos = 4;\npuntos = puntos + 3;\nconsole.log(puntos);", "modo": "texto", "instrucciones": "Segui el valor de la variable paso a paso."}'::jsonb,
   101),
  ('js2:l01:a2', 1,
   '¿Que tipo de dato es true?',
   'completar_texto',
   '{"estricta": false, "instrucciones": "Escribi el nombre del tipo, sin comillas."}'::jsonb,
   102),
  ('js2:l01:a3', 1,
   'Declara una constante llamada curso con el texto Kodigo y mostrala en consola.',
   'escribir_codigo',
   '{"instrucciones": "Usa const y comillas para el texto.", "pruebas": [{"entrada": "sin datos", "esperado": "Kodigo"}]}'::jsonb,
   103),

  -- Unidad 1 - Operadores y calculo
  ('js2:l02:a1', 2,
   E'¿Que imprime esta expresion?\nconsole.log(2 + 3 * 4);',
   'salida_codigo',
   '{"codigo": "console.log(2 + 3 * 4);", "modo": "texto", "instrucciones": "Recorda la prioridad de los operadores."}'::jsonb,
   101),
  ('js2:l02:a2', 2,
   E'El area del rectangulo debe ser base por altura, pero el codigo suma.\nCorregi la operacion.',
   'corregir_codigo',
   '{"codigo_inicial": "const base = 10;\nconst altura = 4;\nconst area = base + altura;\nconsole.log(area);"}'::jsonb,
   102),

  -- Unidad 1 - Condicionales
  ('js2:l03:a1', 3,
   'Arma el condicional que muestra Mayor si edad es 18 o mas y Menor en caso contrario.',
   'bloques',
   '{"bloques": [{"id": "b1", "texto": "if (edad >= 18) {"}, {"id": "b2", "texto": "  console.log(\"Mayor\");"}, {"id": "b3", "texto": "} else {"}, {"id": "b4", "texto": "  console.log(\"Menor\");"}, {"id": "b5", "texto": "}"}, {"id": "b6", "texto": "while (edad >= 18) {"}, {"id": "b7", "texto": "  console.log(\"Igual\");"}], "instrucciones": "Sobra mas de un bloque."}'::jsonb,
   101),
  ('js2:l03:a2', 3,
   E'¿Que imprime este operador ternario?\nconst edad = 15;\nconsole.log(edad >= 18 ? "Mayor" : "Menor");',
   'predecir',
   '{"codigo": "const edad = 15;\nconsole.log(edad >= 18 ? \"Mayor\" : \"Menor\");", "modo": "texto"}'::jsonb,
   102),

  -- Unidad 2 - Bucles for
  ('js2:l04:a1', 4,
   'Arma el bucle que muestra los numeros 0, 1 y 2.',
   'bloques',
   '{"bloques": [{"id": "b1", "texto": "for (let i = 0; i < 3; i++) {"}, {"id": "b2", "texto": "  console.log(i);"}, {"id": "b3", "texto": "}"}, {"id": "b4", "texto": "for (let i = 0; i < 3; i--) {"}, {"id": "b5", "texto": "  console.log(3);"}], "instrucciones": "Elegi el encabezado y el cuerpo correctos."}'::jsonb,
   101),
  ('js2:l04:a2', 4,
   E'¿Que muestra este bucle?\nfor (let i = 1; i <= 3; i++) {\n  console.log(i * 2);\n}',
   'salida_codigo',
   '{"codigo": "for (let i = 1; i <= 3; i++) {\n  console.log(i * 2);\n}", "modo": "texto", "instrucciones": "Escribi los tres valores separados por espacio."}'::jsonb,
   102),

  -- Unidad 2 - Bucles while
  ('js2:l05:a1', 5,
   E'Suma los numeros del 1 al 5 con un while y muestra el total.',
   'escribir_codigo',
   '{"instrucciones": "Declara el contador y el acumulador antes del while.", "pruebas": [{"entrada": "1..5", "esperado": "15"}]}'::jsonb,
   101),
  ('js2:l05:a2', 5,
   'Completa la condicion para que el while se ejecute mientras i sea menor que 3.',
   'completar_codigo',
   '{"codigo": "let i = 0;\nwhile (i {b1} 3) {\n  i++;\n}", "blancos": [{"clave": "b1"}], "candidatos": ["<", "<=", ">", "==="]}'::jsonb,
   102),

  -- Unidad 2 - Funciones
  ('js2:l06:a1', 6,
   'Escribi la funcion sumar(a, b) que devuelve la suma de sus dos parametros.',
   'escribir_codigo',
   '{"instrucciones": "No uses console.log dentro de la funcion: usa return.", "pruebas": [{"entrada": "sumar(2, 3)", "esperado": "5"}]}'::jsonb,
   101),
  ('js2:l06:a2', 6,
   E'¿Que imprime?\nfunction doble(n) {\n  return n * 2;\n}\nconsole.log(doble(4) + 1);',
   'predecir',
   '{"codigo": "function doble(n) {\n  return n * 2;\n}\nconsole.log(doble(4) + 1);", "modo": "texto"}'::jsonb,
   102),

  -- Unidad 2 - Arrays
  ('js2:l07:a1', 7,
   'Completa el recorrido para mostrar cada fruta del array.',
   'escribir_codigo',
   '{"plantilla": "const frutas = [\"pera\", \"uva\"];", "instrucciones": "Usa un for con indice y el largo del array."}'::jsonb,
   101),
  ('js2:l07:a2', 7,
   E'¿Que imprime?\nconst nums = [3, 5, 7];\nconsole.log(nums[1] + nums.length);',
   'salida_codigo',
   '{"codigo": "const nums = [3, 5, 7];\nconsole.log(nums[1] + nums.length);", "modo": "texto", "instrucciones": "El primer indice es 0."}'::jsonb,
   102),

  -- Unidad 3 - Objetos
  ('js2:l08:a1', 8,
   'Completa la notacion para leer la propiedad nota del objeto alumno.',
   'completar_codigo',
   '{"codigo": "const alumno = { nombre: \"Ana\", nota: 9 };\nconsole.log(alumno.{b1});", "blancos": [{"clave": "b1"}], "candidatos": ["nota", "nombre", "length", "valor"]}'::jsonb,
   101),
  ('js2:l08:a2', 8,
   E'¿Que imprime?\nconst perro = { nombre: "Fury" };\nperro.edad = 3;\nconsole.log(perro.edad);',
   'predecir',
   '{"codigo": "const perro = { nombre: \"Fury\" };\nperro.edad = 3;\nconsole.log(perro.edad);", "modo": "texto"}'::jsonb,
   102),

  -- Unidad 3 - Cadenas de texto
  ('js2:l09:a1', 9,
   E'¿Que imprime?\nconsole.log("kodigo".toUpperCase());',
   'salida_codigo',
   '{"codigo": "console.log(\"kodigo\".toUpperCase());", "modo": "texto", "estricta": true}'::jsonb,
   101),
  ('js2:l09:a2', 9,
   'El mensaje conserva espacios de mas. Corregi el codigo para limpiarlos.',
   'corregir_codigo',
   '{"codigo_inicial": "const mensaje = \"  hola  \";\nconsole.log(mensaje);"}'::jsonb,
   102),

  -- Unidad 3 - Proyecto de cierre
  ('js2:l10:a1', 10,
   'Calcula el promedio de las notas usando reduce y mostralo en consola.',
   'escribir_codigo',
   '{"plantilla": "const notas = [10, 6, 8, 9, 5];", "instrucciones": "Suma con reduce y divide por notas.length.", "pruebas": [{"entrada": "notas", "esperado": "7.6"}]}'::jsonb,
   101),
  ('js2:l10:a2', 10,
   'Arma la linea que suma todas las notas con reduce.',
   'bloques',
   '{"bloques": [{"id": "b1", "texto": "const total = notas.reduce((suma, n) => suma + n, 0);"}, {"id": "b2", "texto": "const total = notas.reduce((suma, n) => suma * n, 0);"}, {"id": "b3", "texto": "const total = notas.map((suma, n) => suma + n, 0);"}, {"id": "b4", "texto": "const promedio = total / notas.length;"}], "instrucciones": "Solo una linea calcula la suma; la ultima calcula el promedio."}'::jsonb,
   102)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;

-- Soluciones de la practica ampliada. Todo lo que corrige vive aca y no en
-- preguntas.datos, que es legible por los estudiantes.
insert into soluciones (pregunta_id, opcion_correcta_id, solucion, explicacion)
select
  uuid(md5('kodigo:preg:js2:' || c.clave)),
  null,
  c.solucion,
  c.explicacion
from (values
  ('js2:l01:a1', '{"valor": "7"}'::jsonb,
   'La variable arranca en 4 y se le suman 3: el resultado es 7.'),
  ('js2:l01:a2', '{"valor": "boolean", "alternativas": ["booleano"]}'::jsonb,
   'true y false son los dos unicos valores del tipo boolean.'),
  ('js2:l01:a3', '{"soluciones": ["const curso = \"Kodigo\";\nconsole.log(curso);", "const curso = ''Kodigo'';\nconsole.log(curso);"], "estricto": false}'::jsonb,
   'const declara una constante y las comillas convierten Kodigo en un string. console.log lo muestra.'),

  ('js2:l02:a1', '{"valor": "14"}'::jsonb,
   'La multiplicacion se resuelve antes que la suma: 3 * 4 = 12 y 2 + 12 = 14.'),
  ('js2:l02:a2', '{"soluciones": ["const base = 10;\nconst altura = 4;\nconst area = base * altura;\nconsole.log(area);"], "estricto": false}'::jsonb,
   'El area se calcula multiplicando base por altura, no sumandolas.'),

  ('js2:l03:a1', '{"orden": ["b1", "b2", "b3", "b4", "b5"]}'::jsonb,
   'if evalua la condicion, else cubre el caso contrario y las llaves cierran cada bloque.'),
  ('js2:l03:a2', '{"valor": "Menor", "alternativas": ["menor"]}'::jsonb,
   '15 no es mayor ni igual que 18, entonces el ternario devuelve Menor.'),

  ('js2:l04:a1', '{"orden": ["b1", "b2", "b3"]}'::jsonb,
   'El for arranca en 0, sigue mientras i sea menor que 3 y suma 1 en cada vuelta.'),
  ('js2:l04:a2', '{"valor": "2 4 6", "alternativas": ["2,4,6", "2\n4\n6", "2 4 6\n"]}'::jsonb,
   'El bucle multiplica por 2 cada valor de i: 2, 4 y 6.'),

  ('js2:l05:a1', '{"soluciones": ["let i = 1;\nlet total = 0;\nwhile (i <= 5) {\n  total = total + i;\n  i++;\n}\nconsole.log(total);", "let total = 0;\nfor (let i = 1; i <= 5; i++) {\n  total += i;\n}\nconsole.log(total);"], "estricto": false}'::jsonb,
   'Se acumula cada numero del 1 al 5 y se muestra el total: 15.'),
  ('js2:l05:a2', '{"blancos": [{"clave": "b1", "valor": "<", "alternativas": ["<"], "estricta": true}]}'::jsonb,
   'Mientras i sea menor que 3 el bucle sigue; cuando llega a 3 termina.'),

  ('js2:l06:a1', '{"soluciones": ["function sumar(a, b) {\n  return a + b;\n}", "const sumar = (a, b) => a + b;"], "estricto": false}'::jsonb,
   'Una funcion recibe parametros y devuelve un resultado con return.'),
  ('js2:l06:a2', '{"valor": "9"}'::jsonb,
   'doble(4) devuelve 8 y luego se le suma 1: el resultado es 9.'),

  ('js2:l07:a1', '{"soluciones": ["const frutas = [\"pera\", \"uva\"];\nfor (let i = 0; i < frutas.length; i++) {\n  console.log(frutas[i]);\n}", "const frutas = [\"pera\", \"uva\"];\nfor (const fruta of frutas) {\n  console.log(fruta);\n}"], "estricto": false}'::jsonb,
   'Se recorre el array y se muestra cada elemento usando su indice.'),
  ('js2:l07:a2', '{"valor": "8"}'::jsonb,
   'nums[1] vale 5 y el largo del array es 3: 5 + 3 = 8.'),

  ('js2:l08:a1', '{"blancos": [{"clave": "b1", "valor": "nota", "alternativas": ["nota"], "estricta": true}]}'::jsonb,
   'La notacion punto lee la propiedad nota del objeto alumno.'),
  ('js2:l08:a2', '{"valor": "3"}'::jsonb,
   'Se agrega la propiedad edad al objeto y despues se lee: 3.'),

  ('js2:l09:a1', '{"valor": "KODIGO", "alternativas": ["KODIGO"]}'::jsonb,
   'toUpperCase devuelve el texto en mayusculas.'),
  ('js2:l09:a2', '{"soluciones": ["const mensaje = \"  hola  \";\nconsole.log(mensaje.trim());"], "estricto": false}'::jsonb,
   'trim quita los espacios de los extremos sin tocar los del medio.'),

  ('js2:l10:a1', '{"soluciones": ["const notas = [10, 6, 8, 9, 5];\nconst total = notas.reduce((suma, nota) => suma + nota, 0);\nconsole.log(total / notas.length);", "const notas = [10, 6, 8, 9, 5];\nlet total = 0;\nfor (const nota of notas) {\n  total += nota;\n}\nconsole.log(total / notas.length);"], "estricto": false}'::jsonb,
   'reduce acumula la suma y dividir por el largo del array da el promedio.'),
  ('js2:l10:a2', '{"orden": ["b1", "b4"]}'::jsonb,
   'reduce con acumulador suma todas las notas; despues se divide por la cantidad.')
) as c(clave, solucion, explicacion)
where exists (
  select 1 from preguntas p where p.id = uuid(md5('kodigo:preg:js2:' || c.clave))
)
on conflict (pregunta_id) do update
set solucion = excluded.solucion,
    explicacion = excluded.explicacion;

-- ===========================================================================
-- 18.1. Practica ampliada de JavaScript — variantes con opciones
--
-- Dos actividades para cubrir la variante de salida/prediccion con opciones
-- en lugar de respuesta escrita. Mismo esquema de ids deterministicos.
-- ===========================================================================

with lecciones_num as (
  select id, row_number() over (order by id) as n
  from lecciones
  where id between '30000000-0000-0000-0000-000000000001'::uuid
               and '30000000-0000-0000-0000-000000000010'::uuid
)
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion)
select
  uuid(md5('kodigo:preg:js2:' || c.clave)),
  l.id,
  c.enunciado,
  c.tipo,
  c.datos,
  c.orden,
  'publicado'
from (values
  ('js2:l03:a3', 3,
   E'¿Qué valor tiene x al final del programa?\nlet x = 1;\nx = x + 2;\nx = x * 10;',
   'predecir',
   '{"codigo": "let x = 1;\nx = x + 2;\nx = x * 10;", "modo": "opciones", "instrucciones": "Seguí el valor de x paso a paso."}'::jsonb,
   103),
  ('js2:l09:a3', 9,
   E'¿Qué muestra console.log?\nconst nombre = "  kodigo  ";\nconsole.log(nombre.trim().toUpperCase());',
   'salida_codigo',
   '{"codigo": "const nombre = \"  kodigo  \";\nconsole.log(nombre.trim().toUpperCase());", "modo": "opciones", "instrucciones": "trim quita espacios de los extremos; toUpperCase pasa todo a mayúsculas."}'::jsonb,
   103)
) as c(clave, leccion, enunciado, tipo, datos, orden)
join lecciones_num l on l.n = c.leccion
on conflict (id) do nothing;

insert into opciones (id, pregunta_id, texto, orden)
select
  uuid(md5('kodigo:opt:js2:' || c.clave_preg || ':o' || c.opo)),
  p.id,
  c.texto,
  c.opo
from (values
  ('js2:l03:a3', 1, '30'),
  ('js2:l03:a3', 2, '33'),
  ('js2:l03:a3', 3, '21'),
  ('js2:l03:a3', 4, '12'),
  ('js2:l09:a3', 1, 'KODIGO'),
  ('js2:l09:a3', 2, '  kodigo  '),
  ('js2:l09:a3', 3, 'kodigo'),
  ('js2:l09:a3', 4, 'Kodigo')
) as c(clave_preg, opo, texto)
join preguntas p on p.id = uuid(md5('kodigo:preg:js2:' || c.clave_preg))
on conflict (id) do nothing;

insert into soluciones (id, pregunta_id, opcion_correcta_id, solucion, explicacion)
select
  uuid(md5('kodigo:sol:js2:' || s.clave_preg)),
  p.id,
  o.id,
  '{}'::jsonb,
  s.explicacion
from (values
  ('js2:l03:a3', '30',
   'Primero x pasa de 1 a 3 (1 + 2) y después de 3 a 30 (3 * 10).'),
  ('js2:l09:a3', 'KODIGO',
   'trim quita los espacios de los extremos: "kodigo". toUpperCase devuelve el texto en mayúsculas: KODIGO.')
) as s(clave_preg, correcta, explicacion)
join preguntas p on p.id = uuid(md5('kodigo:preg:js2:' || s.clave_preg))
join opciones o on o.texto = s.correcta and o.pregunta_id = p.id
on conflict (pregunta_id) do nothing;

-- ===========================================================================
-- 19. Endurecimiento de privilegios sobre perfiles
--
-- La policy "usuario modifica su perfil" permite actualizar cualquier columna
-- de la propia fila. Con los default privileges de Supabase, authenticated
-- tiene UPDATE sobre toda la tabla, lo que dejaria escribir experiencia,
-- nivel, racha_dias o created_at a gusto del cliente. Se revoca el UPDATE
-- general y se concede solo sobre las columnas del perfil editorial. Las
-- funciones security definer (finalizar_intento, evaluar_logros) siguen
-- pudiendo escribir XP, nivel y racha porque corren como su propietario.
-- ===========================================================================

revoke update on public.perfiles from authenticated, anon;
grant update (nombre_usuario, nombre_visible, avatar_url) on public.perfiles to authenticated;

-- ===========================================================================
-- 21. Permisos explicitos de funciones
--
-- Los default privileges del proyecto conceden EXECUTE sobre cada funcion
-- recien creada a anon, authenticated y service_role. El REVOKE FROM PUBLIC
-- interno no alcanza. Se revoca de forma explicita a anon y authenticated y
-- se vuelve a conceder solo lo que la app necesita.
--   anon:         las RPC publicas por diseno y la comprobacion de respuestas.
--   authenticated:lo que la app consume con sesion (la autoriniacion real la
--                 hace cada funcion validando auth.uid(); admins validados
--                 aparte por expotec_guard_admin()).
--   Internas:     quedan sin EXECUTE para nadie; las invocan otras funciones
--                 del servidor (owner).
-- ===========================================================================

revoke execute on all functions in schema public from anon;
revoke execute on all functions in schema public from authenticated;

-- Publicas (sin sesion).
grant execute on function comprobar_respuesta(uuid, uuid) to anon, authenticated;
grant execute on function comprobar_respuesta(uuid, jsonb) to anon, authenticated;
grant execute on function es_administrador_expotec() to anon, authenticated;
grant execute on function cantidad_preguntas_publicadas(uuid) to anon, authenticated;
grant execute on function es_leccion_publicada(uuid) to anon, authenticated;
grant execute on function obtener_diccionario() to anon, authenticated;
grant execute on function expotec_evento_activo() to anon, authenticated;
grant execute on function expotec_ranking(uuid, integer) to anon, authenticated;
grant execute on function expotec_alias_disponible(uuid, text) to anon, authenticated;

-- Autenticadas (app con sesion).
grant execute on function iniciar_intento(uuid, uuid) to authenticated;
grant execute on function registrar_respuesta(uuid, uuid, uuid) to authenticated;
grant execute on function registrar_respuesta(uuid, uuid, jsonb) to authenticated;
grant execute on function finalizar_intento(uuid) to authenticated;
grant execute on function obtener_progreso() to authenticated;
grant execute on function obtener_unidades_desbloqueadas() to authenticated;
grant execute on function obtener_logros() to authenticated;
grant execute on function obtener_estadisticas() to authenticated;
grant execute on function obtener_revision() to authenticated;
grant execute on function obtener_amistades() to authenticated;
grant execute on function enviar_solicitud_amistad(text) to authenticated;
grant execute on function responder_solicitud_amistad(uuid, boolean) to authenticated;
grant execute on function expotec_iniciar_partida(uuid, text) to authenticated;
grant execute on function expotec_estado_partida(uuid) to authenticated;
grant execute on function expotec_responder(uuid, uuid, uuid) to authenticated;
grant execute on function expotec_iniciar_juego(uuid) to authenticated;
grant execute on function expotec_checkpoint_juego(uuid, jsonb) to authenticated;
grant execute on function expotec_finalizar_juego(uuid, integer, integer, numeric, jsonb) to authenticated;
grant execute on function expotec_abandonar(uuid) to authenticated;
grant execute on function expotec_obtener_soluciones(uuid) to authenticated;
grant execute on function expotec_resultado_propio(uuid) to authenticated;
grant execute on function expotec_mis_partidas(uuid) to authenticated;
grant execute on function expotec_admin_es_admin() to authenticated;
grant execute on function expotec_admin_guardar_curso(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_guardar_unidad(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_guardar_leccion(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_guardar_pregunta(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_crear_pregunta_completa(uuid, text, jsonb, integer, text, integer) to authenticated;
grant execute on function expotec_admin_guardar_opcion(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_definir_solucion(uuid, uuid, text) to authenticated;
grant execute on function expotec_admin_cambiar_estado_contenido(text, uuid, text) to authenticated;
grant execute on function expotec_admin_guardar_actividad(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_crear_evento(text, text, timestamptz, timestamptz)
    to authenticated;
grant execute on function expotec_admin_actualizar_evento(uuid, jsonb) to authenticated;
grant execute on function expotec_admin_cambiar_estado_evento(uuid, text) to authenticated;
grant execute on function expotec_admin_configurar_desafio(uuid, jsonb, uuid[])
    to authenticated;
grant execute on function expotec_admin_estadisticas_evento(uuid) to authenticated;
grant execute on function expotec_admin_resultados_evento(uuid, text, integer)
    to authenticated;
grant execute on function expotec_admin_cambiar_estado_partida(uuid, boolean) to authenticated;
grant execute on function expotec_admin_reiniciar_ranking(uuid) to authenticated;
grant execute on function expotec_admin_rehabilitar_ranking(uuid) to authenticated;
grant execute on function expotec_admin_rehabilitar_grupo(uuid, integer) to authenticated;
grant execute on function expotec_admin_renombrar_alias(uuid, text) to authenticated;
grant execute on function expotec_admin_renombrar_perfil(uuid, text) to authenticated;
grant execute on function expotec_admin_lista_usuarios(text, integer) to authenticated;


-- ===========================================================================
-- 22. Curso Pensamiento Logico (actividades de tipo robot)
-- ===========================================================================


-- ===========================================================================
-- 22. Curso Pensamiento Logico (actividades de tipo robot)
-- ===========================================================================

-- ===========================================================================
-- 22. Curso Pensamiento Logico (actividades de tipo robot)
-- ===========================================================================


insert into cursos (id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion) values ('10000000-0000-0000-0000-000000000003', 'Pensamiento Lógico', 'Adquirí las habilidades de pensamiento computacional que todo programador necesita: secuencias ordenadas, descomposición de problemas, patrones y algoritmos simples.', 'Razoná antes de actuar', 'PL', 'pensarLogo', '#700b97', 3, 'publicado') on conflict (id) do nothing;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Primer contacto', 'Conocé al robot, respondé a los obstáculos y alcanzá la estrella.', 1, 'publicado') on conflict (id) do nothing;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', 'Pensar antes de actuar', 'Planeá recorridos, encontrando el atajo, rodeos y correcciones sin errores.', 2, 'bloqueada') on conflict (id) do nothing;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Nuevas formas de resolver', 'Repeticiones y tomas de decisiones para resolver desafíos reales.', 3, 'bloqueada') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'Despegue', 'Hoy arranca tu primera mision: llevar al robot desde el inicio hasta la estrella. Avanza hacia donde mira hasta salir del tablero.', 'Cada avance cuenta como una instrucción en la secuencia.', 1, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'Primeros giros', 'Girar no te mueve de la casilla: sólo cambia hacia dónde mira el robot. Orientá primero y después avanzá.', 'Girá a la izquierda para mirar hacia arriba.', 2, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000001', 'Recorrido clásico', 'Combiná giros y avances: avanzá cuatro casillas, girá a la derecha y avanzá hasta la estrella.', 'Orientá el robot primero, después avanzá paso a paso.', 3, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000001', 'El primer salto', 'Habrá un bloqueo que jamás podrás rodear: la casilla siguiente está cerrada y no hay espacio de costado. El salto te lleva dos casillas adelante saltando por encima.', 'Salta el muro: Avanzar, Saltar, Avanzar.', 4, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000001', 'Tres bloqueos', 'Tres obstáculos te separan de la estrella. Analizá el tablero antes de escribir tu secuencia.', 'Pensá el recorrido completo antes de tocar las instrucciones.', 5, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000006', '40000000-0000-0000-0000-000000000002', 'El atajo tapado', 'El camino directo está bloqueado. Mirá dos veces el mapa: hay una ruta por la derecha que evita los obstáculos.', 'Cuando un camino se cierra, buscá el rodeo.', 1, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000007', '40000000-0000-0000-0000-000000000002', 'Rodeo obligatorio', 'No hay atajo: la única ruta posible rodea el bloqueo por arriba. Este es el nivel con más giros de la unidad.', 'Cada giro también cuenta como una instrucción.', 2, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000008', '40000000-0000-0000-0000-000000000002', 'Corregí el algoritmo', 'Este algoritmo está incompleto: avanza sólo tres casillas y se detiene antes de la estrella. Corregilo agregando el avance que falta.', 'Editá la secuencia hasta que el robot llegue a la estrella.', 3, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-000000000009', '40000000-0000-0000-0000-000000000002', 'Precisión milimétrica', 'La ruta correcta se resuelve con 10 instrucciones mínimas si cada giro está bien pensado. Cada giro cuenta también como una instrucción.', 'Contá las casillas y los giros antes de ejecutar.', 4, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-00000000000f', '40000000-0000-0000-0000-000000000002', 'Jefe de la unidad 2', 'El desafío definitivo de la unidad: un tablero con cinco obstáculos y sólo 12 instrucciones como límite. Pensá, planificá y ejecutá.', 'Los mejores recorridos se planean antes de pulsar Ejecutar.', 5, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000003', 'Repetir instrucciones', 'Escribir una instrucción muchas veces es un trabajo aburrido; usá un bucle para repetir avances.', 'Un bucle de 4 avances ocupa 2 instrucciones, no 4.', 1, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-00000000000b', '40000000-0000-0000-0000-000000000003', 'Secuencias eficientes', 'Reemplazá una secuencia larga por un solo bucle. Cada bucle se ejecuta el número de veces indicado.', 'Cuatro avances equivalen a: bucle ×4 avances.', 2, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-00000000000c', '40000000-0000-0000-0000-000000000003', 'Tomar decisiones', 'Mirá la orientación del robot: aunque no entienda condiciones, podés decidir qué giro conviene según tu posición.', 'Mirando a la izquierda o a la derecha podés decidir el próximo giro.', 3, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-00000000000d', '40000000-0000-0000-0000-000000000003', 'Si sucede esto...', 'Antícipate: si un camino no está libre, girá antes de avanzar. Tu secuencia debe adaptarse al mapa.', 'Elegí qué instrucción agregar según la orientación.', 4, 'publicado') on conflict (id) do nothing;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('50000000-0000-0000-0000-00000000000e', '40000000-0000-0000-0000-000000000003', 'Desafío final', 'Combiná avances, giros y obstáculos para resolver el tablero completo con el menor número de instrucciones.', 'Cada instrucción importa. Optimizá, no recorras dos veces el mismo camino.', 5, 'publicado') on conflict (id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('5fe4d9b4-d9cf-8864-d9a9-6a0949750a00', '50000000-0000-0000-0000-000000000001', 'Avanzá en línea recta hasta la estrella. Fácil de ver, fácil de lograr.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 0, "meta": 0, "muros": []}, "instrucciones": ["avanzar"], "maxInstrucciones": 5, "objetivo": "Llegá a la estrella.", "tutorial": "tutorial-avanzar", "modo": "normal", "ejemplo": "Avanzá cuatro veces."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('fb6c2c04-3a3c-3cfd-e755-677eab526d96', '5fe4d9b4-d9cf-8864-d9a9-6a0949750a00', '{"objetivo": "Llegá a la estrella."}'::jsonb, 'Cuatro avances seguidos te llevan directo a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('55a41b1d-fdaa-9b02-5b91-cf6f749cd707', '50000000-0000-0000-0000-000000000002', 'El robot mira hacia la derecha. Girá y llegá a la estrella.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 1, "meta": 0, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Girá y llegá a la estrella.", "tutorial": "tutorial-giros", "modo": "normal", "ejemplo": "Un giro a la izquierda deja al robot mirando hacia arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('bbde6619-f014-6993-a01d-302769ac4a83', '55a41b1d-fdaa-9b02-5b91-cf6f749cd707', '{"objetivo": "Girá y llegá a la estrella."}'::jsonb, 'Un giro a la izquierda y cuatro avances te llevan a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('fb4ebd1c-4723-4baa-fe8c-d25bdb6554bc', '50000000-0000-0000-0000-000000000003', 'Combiná avances y giros para salir del inicio y llegar a la estrella.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 0, "meta": 4, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 20, "objetivo": "Alcanzá la estrella con el menor número de pasos.", "modo": "normal", "ejemplo": "Cuatro avances, un giro derecha y cuatro avances."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('c928c411-b8bf-69b4-a8ae-d2ffce890ca4', 'fb4ebd1c-4723-4baa-fe8c-d25bdb6554bc', '{"objetivo": "Alcanzá la estrella con el menor número de pasos."}'::jsonb, 'Cuatro avances hacia arriba, un giro a la derecha y cuatro avances alcanzan la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('a6556a96-a6a0-8878-c6d0-583f40dc6a4b', '50000000-0000-0000-0000-000000000004', 'Un muro bloquea el camino. Usa el salto para superarlo y llegá a la estrella (dos casillas adelante).', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 22, "rumbo": 0, "meta": 2, "muros": [12]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar"], "maxInstrucciones": 5, "objetivo": "Usa el salto para superar el obstáculo.", "tutorial": "tutorial-salto", "modo": "normal", "ejemplo": "Avanzá, saltá por encima del muro y seguí avanzando."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('9c4c3db4-f456-8987-778d-871ff8d90968', 'a6556a96-a6a0-8878-c6d0-583f40dc6a4b', '{"objetivo": "Evitá los obstáculos."}'::jsonb, 'Avanzá hasta 23, girá a la izquierda, subí por la columna y girá a la derecha para entrar en la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('74f851fb-8567-ac96-cd53-01d96d883425', '50000000-0000-0000-0000-000000000005', 'Tres obstáculos bloquean el camino directo. Planificá tu recorrido.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 3, "meta": 0, "muros": [23, 18, 12]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"], "maxInstrucciones": 25, "objetivo": "Rodeá los tres obstáculos.", "modo": "normal", "ejemplo": "El bloqueo central obliga a rodear por arriba y a cruzar la fila superior."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('8abb72ad-e263-4a86-77e5-24d67bf8308c', '74f851fb-8567-ac96-cd53-01d96d883425', '{"objetivo": "Rodeá los tres obstáculos."}'::jsonb, 'Girá a la derecha, subí por la columna derecha y cruzá la fila superior hacia la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('e36f60a9-6a34-8d26-6034-c95b3029ea3d', '50000000-0000-0000-0000-000000000006', 'El camino directo está tapado. Encontrá el atajo por la derecha.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 11, "rumbo": 1, "meta": 14, "muros": [13, 8, 18, 3]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar"], "maxInstrucciones": 15, "objetivo": "Elegí la ruta correcta.", "modo": "normal", "ejemplo": "El salto puede ahorrarte un rodeo entero: miraló desde arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('1272ae10-bcf5-1d38-c22b-98c5c41601fb', 'e36f60a9-6a34-8d26-6034-c95b3029ea3d', '{"objetivo": "Elegí la ruta correcta."}'::jsonb, 'El atajo: avanzá, bajá por la derecha, doblé a la izquierda y cruzá por abajo.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('ef09b43d-fb5b-85a1-fdd2-de9e174b2b5d', '50000000-0000-0000-0000-000000000007', 'No hay atajos: la única ruta posible rodea el bloqueo por arriba.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 16, "rumbo": 0, "meta": 24, "muros": [22, 17, 12, 2]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar"], "maxInstrucciones": 15, "objetivo": "Encontrá la ruta válida.", "modo": "normal", "ejemplo": "Si el camino está cerrado, saltá por encima."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('c989aa42-4b25-f7ae-51ec-812f19cb254e', 'ef09b43d-fb5b-85a1-fdd2-de9e174b2b5d', '{"objetivo": "Encontrá la ruta válida."}'::jsonb, 'Sólo hay una ruta: subir y cruzar por la derecha hacia la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('1fd72277-543a-a0fb-fb97-1923b229c24b', '50000000-0000-0000-0000-000000000008', 'Este algoritmo está incompleto: no alcanza la estrella. Corregilo para que funcione.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 15, "rumbo": 1, "meta": 19, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 30, "objetivo": "Corregí el algoritmo defectuoso.", "modo": "corregir", "errores": ["Avanzar → Avanzar → Avanzar", "A la secuencia le falta un avance: el robot se detiene una casilla antes de la estrella."], "ejemplo": "Editá la secuencia hasta que el robot llegue a la estrella."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('467d463a-e7d7-b4af-b962-37e8d41bef36', '1fd72277-543a-a0fb-fb97-1923b229c24b', '{"objetivo": "Corregí el algoritmo defectuoso."}'::jsonb, 'La secuencia original avanza sólo tres casillas; agregá un cuarto avance para llegar a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('f670f5d2-7e64-ad42-e6e7-7af8f0c54619', '50000000-0000-0000-0000-000000000009', 'Construí la secuencia exacta: 10 instrucciones mínimas. Cada giro también cuenta.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 10, "rumbo": 2, "meta": 8, "muros": [12, 7, 17]}, "instrucciones": ["avanzar", "izquierda", "derecha"], "maxInstrucciones": 12, "objetivo": "Llegá con precisión.", "modo": "normal", "ejemplo": "Bajá y hacé un rodeo por la izquierda."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('76e439d3-5806-7516-2e03-198a5bd32553', 'f670f5d2-7e64-ad42-e6e7-7af8f0c54619', '{"objetivo": "Llegá con precisión."}'::jsonb, 'La solución: avanzar, avanzar, girar izquierda, avanzar, avanzar, avanzar, girar izquierda, avanzar, avanzar y avanzar.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('b1de3c13-55b4-d8f8-873a-9dac4f97a487', '50000000-0000-0000-0000-00000000000f', 'Cinco obstáculos y sólo 12 instrucciones. Pensá, planificá y ejecutá.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 13, "rumbo": 1, "meta": 10, "muros": [11, 7, 2, 16, 6]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar"], "maxInstrucciones": 12, "objetivo": "Resolvé el tablero con el menor número de instrucciones.", "modo": "normal", "ejemplo": "El centro está bloqueado: saltá un muro clave o rodeá por abajo o por arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('d64c03d3-8754-3663-1e06-48fd0a08af7d', 'b1de3c13-55b4-d8f8-873a-9dac4f97a487', '{"objetivo": "Resolvé el tablero con el menor número de instrucciones."}'::jsonb, 'La ruta mínima: girá a la derecha, avanzá, avanzá, girá a la izquierda, avanzá, avanzá, avanzá, girá a la derecha, avanzá y avanzá.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('acdb920b-7e50-965d-a0b3-b491a14acb33', '50000000-0000-0000-0000-00000000000a', 'Usá un bucle para repetir avances en vez de escribir varios en cadena.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 0, "meta": 9, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"], "maxInstrucciones": 10, "objetivo": "Usá un bucle para repetir avances.", "tutorial": "tutorial-bucles", "modo": "normal", "ejemplo": "Repetir + Avanzar ejecuta tres avances de una sola vez."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('4edbe5e4-43d3-bc80-0a20-e7434822f1cc', 'acdb920b-7e50-965d-a0b3-b491a14acb33', '{"objetivo": "Usá un bucle para repetir avances."}'::jsonb, 'Repetir seguido de Avanzar deja al robot exactamente en la estrella (24 → 19 → 14 → 9).') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('c1df8d57-3806-6140-2442-4927dfeb3710', '50000000-0000-0000-0000-00000000000b', 'Reemplazá una secuencia larga de avances por un solo bucle con número.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 22, "rumbo": 0, "meta": 7, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"], "maxInstrucciones": 10, "objetivo": "Optimizá usando un bucle o un procedimiento.", "tutorial": "tutorial-procedimientos", "modo": "normal", "ejemplo": "Repetir + Avanzar cubre los tres avances que necesitás."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('64803df1-cab3-ca3d-1b4f-90d41bf77f90', 'c1df8d57-3806-6140-2442-4927dfeb3710', '{"objetivo": "Optimizá usando un bucle."}'::jsonb, 'Repetir seguido de Avanzar ejecuta los tres avances que hacen falta: 22 → 17 → 12 → 7.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('e00bbbb9-5c28-3998-0cf1-835fe4c84412', '50000000-0000-0000-0000-00000000000c', 'Tomá decisiones: mirá la orientación antes de definir tu giro.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 19, "rumbo": 1, "meta": 23, "muros": []}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"], "maxInstrucciones": 10, "objetivo": "Tomá decisiones: mirá qué hay antes de girar.", "tutorial": "tutorial-decisiones", "modo": "normal", "ejemplo": "Como no hay condición si, mirar la orientación ya te dice qué giro conviene."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('5c845949-ca2a-551b-9226-341db986e81d', 'e00bbbb9-5c28-3998-0cf1-835fe4c84412', '{"objetivo": "Tomá decisiones: mirá qué hay antes de girar."}'::jsonb, 'Girá a la derecha para bajar, avanzá una casilla, girá otra vez a la derecha y avanzá hasta la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('e4e9c827-7d64-9c8c-dd14-7acde3806ff6', '50000000-0000-0000-0000-00000000000d', 'Si sucede esto, hacé esto otro: anticipate y corregí tu secuencia.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 24, "rumbo": 3, "meta": 0, "muros": [22, 17, 12]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"], "maxInstrucciones": 15, "objetivo": "Si hay un obstáculo, girá y seguí.", "modo": "normal", "ejemplo": "El camino central está bloqueado; saltá o subí por la derecha y cruzá por arriba."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('a4ebc30d-7d29-3d50-d88d-a9ce1e48a7d2', 'e4e9c827-7d64-9c8c-dd14-7acde3806ff6', '{"objetivo": "Si hay un obstáculo, girá y seguí."}'::jsonb, 'Girá a la derecha y subí por el costado derecho; después girá a la izquierda, cruzá la fila superior y entrá a la estrella.') on conflict (pregunta_id) do nothing;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('b2085b3e-b6f0-b13e-7780-c864e30047dd', '50000000-0000-0000-0000-00000000000e', 'Desafío final: combiná todo lo que ya sabés en un solo recorrido.', 'robot', '{"tablero": {"dimensiones": 5, "inicio": 20, "rumbo": 1, "meta": 0, "muros": [7, 12, 17]}, "instrucciones": ["avanzar", "izquierda", "derecha", "saltar", "llamar", "bucle2", "bucle3", "bucle4", "bucle5", "fin"], "maxInstrucciones": 20, "objetivo": "Resolvé el tablero completo combinando todo lo aprendido.", "tutorial": "tutorial-procedimientos", "modo": "normal", "ejemplo": "Combiná giros, bucles y saltos para superar los tres obstáculos."}'::jsonb, 1, 'publicado') on conflict (id) do nothing;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('98a53068-5404-393e-0a32-f45794f7309d', 'b2085b3e-b6f0-b13e-7780-c864e30047dd', '{"objetivo": "Resolvé el tablero completo."}'::jsonb, 'El camino final combina giros y bucles para evitar los tres obstáculos.') on conflict (pregunta_id) do nothing;
-- ===============================================================
-- Capítulo 22b: Ampliacion JS y HTML a 5 unidades x 5 lecciones
-- (corresponde a la migracion _migracion-v3 aplicada en produccion)
-- ===============================================================

-- Paso 0: corrido temporal de los orden (idempotente)
update lecciones set orden = orden + 1000 where unidad_id in ('20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000005', '65223173-50c1-47fc-6123-b5b094d85a34', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', '185cf7ac-af6f-4daf-11da-41ac2b744411', '70000000-0000-0000-0000-000000000100', '70000000-0000-0000-0000-000000000101') and orden < 1000;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'Funciones y estructuras', 'Organizá tu código en bloques reutilizables: funciones, parámetros, retornos y arrays.', 4, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'Objetos y aplicaciones', 'Objetos, cadenas, métodos y un proyecto completo con DOM y eventos.', 5, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000100', '10000000-0000-0000-0000-000000000002', 'Formularios', 'Armá formularios funcionales con inputs, labels y botones.', 4, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000101', '10000000-0000-0000-0000-000000000002', 'Integración y buenas prácticas', 'Tablas, multimedia, accesibilidad y un proyecto final.', 5, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('20000000-0000-0000-0000-000000000001', (select curso_id from unidades where id = '20000000-0000-0000-0000-000000000001'), 'Introducción a JavaScript', 'Conocé qué es, variables, tipos, operadores y tu primer Hola mundo.', 1, 'publicado') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('20000000-0000-0000-0000-000000000002', (select curso_id from unidades where id = '20000000-0000-0000-0000-000000000002'), 'Condicionales y lógica', 'Elegí qué camino sigue tu programa con if, else if, else y booleanos.', 2, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('20000000-0000-0000-0000-000000000003', (select curso_id from unidades where id = '20000000-0000-0000-0000-000000000003'), 'Repeticiones', 'Hacé que la computadora repita con for y while.', 3, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('65223173-50c1-47fc-6123-b5b094d85a34', (select curso_id from unidades where id = '65223173-50c1-47fc-6123-b5b094d85a34'), 'Primeros pasos con HTML', 'Estructura, etiquetas y elementos para empezar con las páginas web.', 1, 'publicado') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', (select curso_id from unidades where id = '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa'), 'Contenido y enlaces', 'Listas, enlaces, rutas e imágenes para organizar contenido.', 2, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into unidades (id, curso_id, nombre, descripcion, orden, estado_publicacion) values ('185cf7ac-af6f-4daf-11da-41ac2b744411', (select curso_id from unidades where id = '185cf7ac-af6f-4daf-11da-41ac2b744411'), 'Organización de páginas', 'Contenedores, semántica y estructuras completas.', 3, 'bloqueada') on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000001', 'Qué es JavaScript', 'JavaScript es el lenguaje de la web. Permite hacer que las páginas sean interactivas y dinámicas.', 'console.log("¡Hola, mundo!");', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Variables y tipos de datos', 'Una variable guarda un dato para usarlo después. Con let o const declarás la variable y le asignás un valor.', 'const nombre = "Ana";
let edad = 18;
const esAlumno = true;', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Operadores y cálculo', 'Los operadores combinan valores y hacen cálculos. Suma, resta, multiplicación y división son las más comunes.', 'let total = 2 + 3 * 4;
console.log(total);', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000012', '20000000-0000-0000-0000-000000000001', 'Expresiones y tipos de datos', 'Una expresión es cualquier código que produce un valor: una operación, una comparación o una combinación.', 'const a = 10, b = 4;
console.log(a * b);', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000013', '20000000-0000-0000-0000-000000000001', 'Repaso integrador 1', 'Repasá lo aprendido: variables, tipos y operadores.', 'let s = "Hola";
console.log(s + ", Kodigo!");', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000014', '20000000-0000-0000-0000-000000000002', 'Comparaciones y booleanos', 'Una comparación produce un booleano: true o false. Operadores comunes: ==, ===, !=, <, >, <=, >=.', 'console.log(5 > 3);
console.log(2 === 3);', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000015', '20000000-0000-0000-0000-000000000002', 'Operadores lógicos', 'Los operadores lógicos combinan booleanos: && (and), || (or) y ! (not).', 'console.log(true && false);
console.log(true || false);', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'Condicionales con if', 'if ejecuta un bloque sólo cuando una condición es verdadera. Sirve para tomar decisiones.', 'if (edad >= 18) {
  console.log("mayor");
}', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000016', '20000000-0000-0000-0000-000000000002', 'else if y condiciones anidadas', 'else if permite evaluar varias condiciones en orden; else se ejecuta cuando ninguna se cumple.', 'if (n >= 9) { x = "A"; }
else if (n >= 7) { x = "B"; }
else { x = "C"; }', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000017', '20000000-0000-0000-0000-000000000002', 'Repaso integrador 2', 'Condicionales y lógica con múltiples decisiones ordenadas.', 'if (nota >= 9) console.log("A");
else if (nota >= 7) console.log("B");', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000003', 'Bucles for', 'for repite un bloque de código una cantidad conocida de veces.', 'for (let i = 0; i < 3; i++) {
  console.log(i);
}', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000003', 'Bucles while', 'while repite mientras la condición sea verdadera; útil cuando no sabés cuántas veces.', 'let i = 0;
while (i < 3) { i = i + 1; }', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000018', '20000000-0000-0000-0000-000000000003', 'Contadores y acumuladores', 'Un contador lleva la cuenta; un acumulador suma valores.', 'let s = 0;
for (let i = 1; i <= 5; i++) s = s + i;
console.log(s);', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000019', '20000000-0000-0000-0000-000000000003', 'Cuándo terminan los bucles', 'Un bucle necesita una condición que eventualmente sea falsa.', 'let x = 1;
while (x < 100) x = x * 2;', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000020', '20000000-0000-0000-0000-000000000003', 'Repaso integrador 3', 'Repasá bucles, contadores y acumuladores con ejercicios integradores.', 'let t = 0;
for (let i = 0; i < 5; i++) t = t + 2;', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000004', 'Funciones', 'Una función es un bloque de código reutilizable con un nombre.', 'function saludar(nombre) {
  return "Hola, " + nombre;
}', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000021', '20000000-0000-0000-0000-000000000004', 'Parámetros y argumentos', 'Parámetros son los nombres en la declaración; argumentos son los valores que enviás.', 'function doble(x) {
  return x * 2;
}', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000022', '20000000-0000-0000-0000-000000000004', 'Retorno de valores', 'return devuelve el valor de la función; sin return la función devuelve undefined.', 'function area(w, h) {
  return w * h;
}', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000004', 'Arrays', 'Un array es una lista ordenada de valores. Accedés por posición empezando en 0.', 'const n = [10, 20, 30];
console.log(n[0]);', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000023', '20000000-0000-0000-0000-000000000004', 'Recorridos y manipulación de arrays', 'for recorre los índices de un array; map transforma y filter selecciona.', 'const n = [1, 2, 3];
console.log(n.map(x => x * 2));', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000005', 'Objetos', 'Un objeto agrupa propiedades con nombre y valor: datos y comportamiento juntos.', 'const p = { nombre: "Ana", edad: 20 };
console.log(p.edad);', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000009', '20000000-0000-0000-0000-000000000005', 'Cadenas de texto', 'Las cadenas son textos. JavaScript trae métodos: length, toUpperCase, includes, slice, trim.', 'console.log("Kodigo".length);', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000024', '20000000-0000-0000-0000-000000000005', 'Propiedades y métodos', 'Las propiedades guardan datos; los métodos son funciones del objeto.', 'const o = { n: 5, d() { return this.n * 2; } };', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000025', '20000000-0000-0000-0000-000000000005', 'DOM: la página como árbol', 'DOM significa Document Object Model; cada etiqueta HTML es un nodo. JavaScript puede leer y cambiar esos nodos.', 'const b = document.querySelector("#enviar");
b.addEventListener("click", () => console.log("clic"));', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('30000000-0000-0000-0000-000000000010', '20000000-0000-0000-0000-000000000005', 'Proyecto: notas de clase', 'Proyecto integrador: notas, DOM y eventos. Un mini-proyecto completo con HTML, CSS y JS.', 'const notas = [];
function guardar(n) {
  notas.push({ id: Date.now(), texto: n });
  render();
}', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000001', '65223173-50c1-47fc-6123-b5b094d85a34', '¿Qué es HTML?', 'HTML es el lenguaje de marcado de la web. No es un lenguaje de programación: es una descripción de la estructura del contenido.', '<h1>Hola</h1>', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('707e84f0-fc33-bb22-2e7c-97bf32d4c0ed', '65223173-50c1-47fc-6123-b5b094d85a34', 'El documento HTML', 'Un documento HTML tiene una cabecera (head) con metadatos y un cuerpo (body) con el contenido visible.', '<!DOCTYPE html>
<html lang="es">
<head></head>
<body></body>
</html>', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('4bfdf59b-4b84-10c9-20f0-f095ce26f405', '65223173-50c1-47fc-6123-b5b094d85a34', 'Etiquetas y elementos', 'Las etiquetas son marcas como <p> y </p>. Cada elemento tiene apertura y cierre (salvo etiquetas vacías como <img> o <input>).', '<p>Párrafo</p>', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000002', '65223173-50c1-47fc-6123-b5b094d85a34', 'Encabezados y estructura', 'Los encabezados h1-h6 organizan y jerarquizan el contenido; los p son contenedores de bloques de texto.', '<h1>Título</h1>
<h2>Subtítulo</h2>
<p>Contenido</p>', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000003', '65223173-50c1-47fc-6123-b5b094d85a34', 'Repaso integrador 1', 'Repasá lo aprendido: estructura, etiquetas, encabezados y elementos.', '<h1>Kodigo</h1>', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('3e8ffb80-ab9d-66e0-47e1-fd1eb7948f66', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 'Listas y enlaces', 'Las listas ul y ol estructuran elementos en serie. Los enlaces (<a>) navegan entre páginas.', '<ul>
  <li>Opción 1</li>
</ul>', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000004', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 'Enlaces y rutas relativas', 'Las rutas relativas indican dónde encontrar el archivo desde el documento actual; las absolutas usan la URL completa.', '<a href="contacto.html">Contacto</a>', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('92153c83-c8e8-3f06-ca75-2d205d4eea72', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 'Imágenes', 'La etiqueta <img> incrusta imágenes con atributos src y alt.', '<img src="foto.jpg" alt="Descripción">', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000005', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 'Listas ordenadas y organización', 'Las listas anidan y organizan contenidos similares; sirven para menús y pasos de procesos.', '<ol>
  <li>Paso 1</li>
</ol>', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000006', '7aaa8eab-6c93-5662-e26b-0cd345b6e4fa', 'Repaso integrador 2', 'Repasá listas, enlaces e imágenes con ejercicios integradores.', '<a href="menu.html">Menú</a>', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000007', '185cf7ac-af6f-4daf-11da-41ac2b744411', 'Contenedores y agrupación', 'Las etiquetas block agrupan contenido; los div son contenedores genéricos.', '<div>
  <p>Bloque</p>
</div>', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000008', '185cf7ac-af6f-4daf-11da-41ac2b744411', 'Header, main y footer', 'header es el encabezado; main es el contenido principal; footer es el pie.', '<header>Kodigo</header>
<main>Contenido</main>
<footer>2026</footer>', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-000000000009', '185cf7ac-af6f-4daf-11da-41ac2b744411', 'Secciones y artículos', 'section agrupa contenidos temáticos; article es contenido independiente.', '<article>
  <h2>Artículo</h2>
</article>', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('d14606e6-b4bb-8499-e4c8-dffb7b31170f', '185cf7ac-af6f-4daf-11da-41ac2b744411', 'Etiquetas semánticas', 'HTML5 introdujo etiquetas con significado semántico: nav, aside, section, article, figure.', '<nav>Menú</nav>', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-00000000000a', '185cf7ac-af6f-4daf-11da-41ac2b744411', 'Repaso integrador 3', 'Repasá organización y semántica con ejercicios integradores.', '<main><article>Texto</article></main>', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('bf446ed2-3603-f4cf-71a3-4c3975379935', '70000000-0000-0000-0000-000000000100', 'Formularios e inputs', 'Los formularios recopilan datos del usuario con <form> y campos como <input>, <label> y <button>.', '<form>
  <label>Nombre:</label>
  <input type="text" name="nombre">
</form>', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-00000000000b', '70000000-0000-0000-0000-000000000100', 'Labels y accesibilidad', '<label> vincula un texto con un campo; mejora la usabilidad y la accesibilidad.', '<label for="nombre">Nombre</label>
<input id="nombre" name="nombre">', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-00000000000c', '70000000-0000-0000-0000-000000000100', 'Botones y tipos de campo', '<button> y <input type="text|email|password|number|checkbox|radio|submit"> cubren distintos tipos de datos.', '<input type="email" name="correo" required>', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('256fb823-7c87-b186-8820-43dd4c2734c9', '70000000-0000-0000-0000-000000000100', 'Formularios avanzados', 'Los formularios admiten validación HTML5 (required, pattern, type) y múltiples tipos de campo.', '<input type="email" pattern=".+@.+\..+" required>', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-00000000000d', '70000000-0000-0000-0000-000000000100', 'Repaso integrador 4', 'Repasá formularios, labels y accesibilidad con ejercicios integradores.', '<form></form>', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('1011b119-e854-cbc3-9561-0afe891a11eb', '70000000-0000-0000-0000-000000000101', 'Tablas', 'Las tablas organizan datos en filas y columnas: <table>, <tr>, <td>, <th>.', '<table>
  <tr><th>Nombre</th></tr>
</table>', 1, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('9745df43-9522-1db7-395b-1fd810c05c28', '70000000-0000-0000-0000-000000000101', 'Atributos y clases', 'class vincula una etiqueta con estilos CSS; id a uno único en la página.', '<p class="destaca">Texto</p>', 2, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-00000000000e', '70000000-0000-0000-0000-000000000101', 'Multimedia básica', '<audio> y <video> incrustan multimedia con sus atributos controls y src.', '<audio controls><source src="a.mp3" type="audio/mpeg"></audio>', 3, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('70000000-0000-0000-0000-00000000000f', '70000000-0000-0000-0000-000000000101', 'Accesibilidad básica', 'HTML semántico mejora el acceso: jerarquía de headings, alt descriptivo, labels y roles ARIA.', '<img src="mapa.png" alt="Mapa del campus">', 4, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into lecciones (id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion) values ('8caf4505-8287-cc71-c800-dcf8c454cf22', '70000000-0000-0000-0000-000000000101', 'Proyecto integrador final', 'Proyecto integral: armá una página completa con encabezado, contenido, formulario, tabla e imágenes.', '<main><article>…</article></main>', 5, 'publicado') on conflict (id) do update set unidad_id = excluded.unidad_id, titulo = excluded.titulo, explicacion = excluded.explicacion, ejemplo_codigo = excluded.ejemplo_codigo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('3f89d754-5dc3-5048-790b-0c62c4d1612a', '30000000-0000-0000-0000-000000000011', '¿Para qué sirve JavaScript?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('34d56a7f-1f08-c417-2de3-71553e3f651d', '3f89d754-5dc3-5048-790b-0c62c4d1612a', 'Para darle interactividad a las páginas web.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('142e5b41-8f44-b7e6-1717-f10f1fe892ac', '3f89d754-5dc3-5048-790b-0c62c4d1612a', 'Para diseñar logotipos.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('0881852a-5850-4184-19b4-52ca4588f747', '3f89d754-5dc3-5048-790b-0c62c4d1612a', 'Para programar impresoras 3-D.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e2f8d620-f722-9e7f-69e4-99f56c91887b', '3f89d754-5dc3-5048-790b-0c62c4d1612a', '34d56a7f-1f08-c417-2de3-71553e3f651d', 'JavaScript es el lenguaje que da dinamismo y comportamiento a las páginas web.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('efbdb00c-ef0d-fce2-75df-4ccdfbbc94a2', '30000000-0000-0000-0000-000000000011', 'JavaScript es un lenguaje de programación.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('768c6443-fe75-1757-46e6-7db8045609cb', 'efbdb00c-ef0d-fce2-75df-4ccdfbbc94a2', 'JavaScript es el lenguaje web del comportamiento.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('de47dd9e-15a5-35e3-d913-4b5c50c59428', 'efbdb00c-ef0d-fce2-75df-4ccdfbbc94a2', 'No, no es un lenguaje de programación.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('32191f34-b6ce-a092-753d-777de4d48d99', 'efbdb00c-ef0d-fce2-75df-4ccdfbbc94a2', '768c6443-fe75-1757-46e6-7db8045609cb', 'JS permite hacer páginas interactivas y se usa en el navegador y en el servidor (Node.js).') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('aada7c53-7c79-cabd-39c6-c5f4dd06b7a8', '30000000-0000-0000-0000-000000000011', '¿Quién creó JavaScript?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('5a427568-2d13-2222-6637-fd549540d4c5', 'aada7c53-7c79-cabd-39c6-c5f4dd06b7a8', 'Brendan Eich, en Netscape, en 1995.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c65395fb-5a91-ba2d-5ddf-4679d73c784d', 'aada7c53-7c79-cabd-39c6-c5f4dd06b7a8', 'Microsoft, en 2001.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1b9849ff-3d27-6bd8-1ccd-97469db506c4', 'aada7c53-7c79-cabd-39c6-c5f4dd06b7a8', 'Google, en 2009.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('9b5ea888-32d3-8681-2e9c-5d4c6a786fc9', 'aada7c53-7c79-cabd-39c6-c5f4dd06b7a8', '5a427568-2d13-2222-6637-fd549540d4c5', 'JavaScript fue creado por Brendan Eich en Netscape en 1995.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('116557b5-ca61-9f78-0344-8ce49a664bbe', '30000000-0000-0000-0000-000000000011', '¿Dónde se puede ejecutar JavaScript?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('a2f4c842-f80a-71b3-6bf9-a58a40b02c1f', '116557b5-ca61-9f78-0344-8ce49a664bbe', 'En navegadores y en servidores con Node.js.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('32f0e987-f589-97d6-8d44-b5a36b5b1c3f', '116557b5-ca61-9f78-0344-8ce49a664bbe', 'Sólo en navegadores.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4add95af-b1f8-2513-d63b-90466f34c8e9', '116557b5-ca61-9f78-0344-8ce49a664bbe', 'Sólo en servidores.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('034131f1-6a19-d7b0-3a5a-164057afbb89', '116557b5-ca61-9f78-0344-8ce49a664bbe', 'a2f4c842-f80a-71b3-6bf9-a58a40b02c1f', 'JS corre en navegadores (Chrome, Firefox, Edge) y también en servidores (Node.js).') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('3681bd27-1fe7-1c25-3b74-9dce88a20d0f', '30000000-0000-0000-0000-000000000012', '¿Qué imprime este código? console.log(4 + 3);', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7a44418b-58be-39cc-0b9e-9a37b4c17265', '3681bd27-1fe7-1c25-3b74-9dce88a20d0f', '7', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('cefa2492-accd-43e3-07e5-3869280d4dda', '3681bd27-1fe7-1c25-3b74-9dce88a20d0f', '43', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('897f0f05-2832-abee-e1e3-4a5a76c036e0', '3681bd27-1fe7-1c25-3b74-9dce88a20d0f', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('12231629-9bb0-a471-426e-5bcfa47d1d86', '3681bd27-1fe7-1c25-3b74-9dce88a20d0f', '7a44418b-58be-39cc-0b9e-9a37b4c17265', 'Es una operación con números: 4 + 3 = 7.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('a026c851-14e5-4cca-2ed0-48c360df955c', '30000000-0000-0000-0000-000000000012', '¿Qué tipo es la variable en: const x = "42"?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7ea27890-c6b3-8040-a926-2e8915ce0740', 'a026c851-14e5-4cca-2ed0-48c360df955c', 'string', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b6b95e86-454b-a36c-7879-d2c530f3c412', 'a026c851-14e5-4cca-2ed0-48c360df955c', 'number', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('ad83ff73-89ae-bed9-a72d-66024d9228b5', 'a026c851-14e5-4cca-2ed0-48c360df955c', 'boolean', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e11b641a-e9b5-1e7b-f44c-143fe52454f0', 'a026c851-14e5-4cca-2ed0-48c360df955c', '7ea27890-c6b3-8040-a926-2e8915ce0740', '"42" está entre comillas: es un string.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c09a2b0d-d6ee-3fc8-8b9e-b2891ceee934', '30000000-0000-0000-0000-000000000012', '¿Qué imprime este código? const a = [1, 2, 3]; console.log(a.length);', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7fd4c7d9-e16d-1fcf-0a90-bb982951eed3', 'c09a2b0d-d6ee-3fc8-8b9e-b2891ceee934', '3', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('3cb9048d-7c72-6c44-ffb0-0660c6903b24', 'c09a2b0d-d6ee-3fc8-8b9e-b2891ceee934', '2', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('ebf37f87-3ae0-fb1b-92c9-f1cdf56a0bd1', 'c09a2b0d-d6ee-3fc8-8b9e-b2891ceee934', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('250e4afc-7d12-7aaf-ec47-407c1dbc1706', 'c09a2b0d-d6ee-3fc8-8b9e-b2891ceee934', '7fd4c7d9-e16d-1fcf-0a90-bb982951eed3', 'length devuelve la cantidad de elementos del array: 3.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('3dfbd2da-e3a6-83d7-4d1f-2c9847367b62', '30000000-0000-0000-0000-000000000012', 'typeof 3.14 devuelve:', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('c8b1e417-052c-acc5-e531-c85cce91ef45', '3dfbd2da-e3a6-83d7-4d1f-2c9847367b62', '"number"', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('303c307b-676c-caf9-601b-074f285a3b6a', '3dfbd2da-e3a6-83d7-4d1f-2c9847367b62', '"float"', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('3f8996e8-e444-2b3f-4bce-1a90ada2a842', '3dfbd2da-e3a6-83d7-4d1f-2c9847367b62', '"double"', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('3282494e-dd27-1f0d-a0b1-714d47fd1349', '3dfbd2da-e3a6-83d7-4d1f-2c9847367b62', '"decimal"', 4) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('3c33f755-2132-116a-6242-88235992a8bb', '3dfbd2da-e3a6-83d7-4d1f-2c9847367b62', 'c8b1e417-052c-acc5-e531-c85cce91ef45', 'JavaScript tiene un único tipo numérico: number.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('1b379069-16ad-1787-aa37-44a5e3a5e716', '30000000-0000-0000-0000-000000000013', '¿Qué imprime este código? let x = 5; let y = 2; console.log(x + y);', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('e7faa692-896c-b7aa-14f8-d61d4b737086', '1b379069-16ad-1787-aa37-44a5e3a5e716', '7', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5907ab67-ea06-644e-d8b7-0836a1f7710a', '1b379069-16ad-1787-aa37-44a5e3a5e716', '52', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('66df1687-93cb-2455-5d1b-6e816c1781f7', '1b379069-16ad-1787-aa37-44a5e3a5e716', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('3b9eea01-b55a-0c69-b4c5-933df68721ed', '1b379069-16ad-1787-aa37-44a5e3a5e716', 'e7faa692-896c-b7aa-14f8-d61d4b737086', 'Suma de números: 5 + 2 = 7.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('cf5c364c-23b4-b517-9351-686f1568f025', '30000000-0000-0000-0000-000000000013', 'La declaración de una función con const es válida en JavaScript.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('a6c13e65-7cbb-563e-6e2b-d59a87403da5', 'cf5c364c-23b4-b517-9351-686f1568f025', 'const f = () => 42;', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('36c4c627-5f77-7b81-34dd-93010a4b025c', 'cf5c364c-23b4-b517-9351-686f1568f025', 'Sólo la palabra function.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('efaa1431-f315-03e1-27d1-e7a358a12454', 'cf5c364c-23b4-b517-9351-686f1568f025', 'a6c13e65-7cbb-563e-6e2b-d59a87403da5', 'La función puede ser asignación a const o declaración con function.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('517a57de-d894-57fb-b7e1-942add4b67c6', '30000000-0000-0000-0000-000000000013', '¿Qué imprime este código? const a = 10, b = 4; console.log(a * b);', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('34c439c7-1b85-4e67-a75a-a4ceaefc1325', '517a57de-d894-57fb-b7e1-942add4b67c6', '40', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('89569303-d874-459e-7620-9252567242ee', '517a57de-d894-57fb-b7e1-942add4b67c6', '14', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1b4867a4-2f84-8711-6418-93ab2147e17b', '517a57de-d894-57fb-b7e1-942add4b67c6', '104', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('dca8d384-7476-8690-4976-72e95d139ccc', '517a57de-d894-57fb-b7e1-942add4b67c6', '34c439c7-1b85-4e67-a75a-a4ceaefc1325', 'Multiplicación: 10 * 4 = 40.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('af6057ab-b6a9-5e1f-e2d4-6a82635cc856', '30000000-0000-0000-0000-000000000013', '¿Qué imprime este código? const saludo = "Hola"; console.log(saludo + ", Kodigo!");', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('828eaf6e-6ed4-929d-9db9-721541394417', 'af6057ab-b6a9-5e1f-e2d4-6a82635cc856', 'Hola, Kodigo!', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c63283f4-b63a-9c2c-1485-744f4812edfb', 'af6057ab-b6a9-5e1f-e2d4-6a82635cc856', 'HolaKodigo!', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('897b47e9-9faa-20cb-3f78-8ddca6e27045', 'af6057ab-b6a9-5e1f-e2d4-6a82635cc856', 'Hola, Kodigo', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('09e98927-a29a-f967-3a61-39d09b4b8789', 'af6057ab-b6a9-5e1f-e2d4-6a82635cc856', '828eaf6e-6ed4-929d-9db9-721541394417', 'La concatenación agrega el texto a la cadena.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ebc59715-3e88-f344-9352-5651bae7c6f3', '30000000-0000-0000-0000-000000000013', '¿Qué imprime este código? console.log("JavaScri".length);', 'seleccion', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('d262a627-1802-4589-72df-c542e6cc44c6', 'ebc59715-3e88-f344-9352-5651bae7c6f3', '7', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('151b9de1-4886-0c64-4b51-311035206798', 'ebc59715-3e88-f344-9352-5651bae7c6f3', '8', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4b59e989-1aed-8d7c-fd95-89efae2a2166', 'ebc59715-3e88-f344-9352-5651bae7c6f3', '6', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d0782e34-0c71-12da-d589-5dee6ca33c8a', 'ebc59715-3e88-f344-9352-5651bae7c6f3', '9', 4) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8adc4abe-e87c-1285-63cc-1481428c088f', 'ebc59715-3e88-f344-9352-5651bae7c6f3', '151b9de1-4886-0c64-4b51-311035206798', '"JavaScri" son 8 caracteres (J-a-v-a-S-c-r-i).') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('772fb961-9fa0-44a8-8774-e2a567bbaab0', '30000000-0000-0000-0000-000000000014', '¿Qué es un booleano en JavaScript?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('55a67463-04a5-308d-5bb8-4ffdaf92d1f8', '772fb961-9fa0-44a8-8774-e2a567bbaab0', 'Un valor que es verdadero o falso (true/false).', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d570dda7-9c2d-3cdb-3e8a-eeec63a0257e', '772fb961-9fa0-44a8-8774-e2a567bbaab0', 'Un tipo de número decimal.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('49db580b-3f9a-9a2e-290a-401445624cf4', '772fb961-9fa0-44a8-8774-e2a567bbaab0', 'Un texto entre comillas.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('959e2322-a113-4f79-fb9b-704179cd5175', '772fb961-9fa0-44a8-8774-e2a567bbaab0', '55a67463-04a5-308d-5bb8-4ffdaf92d1f8', 'boolean = true o false.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c3835c98-1db2-f3be-e025-ff4cf22fd7b0', '30000000-0000-0000-0000-000000000014', '5 == "5" devuelve true en JavaScript.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('6bed9454-45e7-6bd0-18b3-6818dc0992c4', 'c3835c98-1db2-f3be-e025-ff4cf22fd7b0', '== compara sólo el valor, no el tipo.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8893ef60-154e-50ea-f3fb-a7a4abf0cda6', 'c3835c98-1db2-f3be-e025-ff4cf22fd7b0', '== compara también el tipo.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4efc9d34-fe31-95ae-cd1d-2b31e72c6deb', 'c3835c98-1db2-f3be-e025-ff4cf22fd7b0', '6bed9454-45e7-6bd0-18b3-6818dc0992c4', '== compara valor; === compara valor y tipo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('56ba3bf5-941d-7305-d56f-66b8e30eacd5', '30000000-0000-0000-0000-000000000014', '¿Qué operador compara valor y tipo al mismo tiempo?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7fdb5574-65b5-9f31-67fd-5a43aaa80870', '56ba3bf5-941d-7305-d56f-66b8e30eacd5', '===', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4da5792a-c8e4-1875-62b5-861772ecb33d', '56ba3bf5-941d-7305-d56f-66b8e30eacd5', '==', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('24e862b9-48cb-e8dd-1e02-e2d15a44b2d5', '56ba3bf5-941d-7305-d56f-66b8e30eacd5', '!=', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a4de8e79-7771-4849-fda5-afb9c6451249', '56ba3bf5-941d-7305-d56f-66b8e30eacd5', '==!', 4) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('766b4843-5de6-0c96-e69d-9d589a419c85', '56ba3bf5-941d-7305-d56f-66b8e30eacd5', '7fdb5574-65b5-9f31-67fd-5a43aaa80870', '=== compara valor y tipo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('3f5ab769-6b1d-bd58-be83-1403964dd458', '30000000-0000-0000-0000-000000000014', '¿Qué imprime este código? console.log(4 > 3);', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7e57f00a-0680-8a11-fb7c-1db43b5f2cd4', '3f5ab769-6b1d-bd58-be83-1403964dd458', 'true', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('15368154-07c4-4aac-81b8-8d4e21861c54', '3f5ab769-6b1d-bd58-be83-1403964dd458', 'false', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('acd762e1-eae6-ab8e-8310-bb2df979701f', '3f5ab769-6b1d-bd58-be83-1403964dd458', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('29e8cb02-7312-65b1-cc55-bede528e3961', '3f5ab769-6b1d-bd58-be83-1403964dd458', '7e57f00a-0680-8a11-fb7c-1db43b5f2cd4', '4 es mayor que 3.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('7feaa064-9e71-17a8-fdf1-c8b0be872995', '30000000-0000-0000-0000-000000000015', '¿Qué imprime este código? console.log(true && false);', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('da96163e-8151-f4e6-ec15-46f46961c4b0', '7feaa064-9e71-17a8-fdf1-c8b0be872995', 'false', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('84a6a5ea-c52e-ceb7-1c35-b35973afb0c7', '7feaa064-9e71-17a8-fdf1-c8b0be872995', 'true', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('572b11a3-94c9-c708-be32-4dd53d254237', '7feaa064-9e71-17a8-fdf1-c8b0be872995', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('9b7299f0-64f4-c156-fab6-65a92e93f6ba', '7feaa064-9e71-17a8-fdf1-c8b0be872995', 'da96163e-8151-f4e6-ec15-46f46961c4b0', '&& sólo es verdadero si ambos operandos lo son.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('f0b22d53-7bbc-a544-4c18-9f8f913eafa7', '30000000-0000-0000-0000-000000000015', '¿Qué imprime este código? console.log(true || false);', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('b4c05b05-3bb8-c225-caad-4be4e8c2bd14', 'f0b22d53-7bbc-a544-4c18-9f8f913eafa7', 'true', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('9d446bb8-e5c5-d714-df1a-c14a618317a3', 'f0b22d53-7bbc-a544-4c18-9f8f913eafa7', 'false', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('2d9712c5-afb4-a05b-6cb8-459ec30c28c4', 'f0b22d53-7bbc-a544-4c18-9f8f913eafa7', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('5df896f3-3c06-aad1-e594-5cb9d5f690d3', 'f0b22d53-7bbc-a544-4c18-9f8f913eafa7', 'b4c05b05-3bb8-c225-caad-4be4e8c2bd14', '|| es verdadero si al menos uno es verdadero.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('89a470dd-70be-5d51-683d-94e3f9983f95', '30000000-0000-0000-0000-000000000015', '¿Qué imprime este código? console.log(!true);', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('63c901f9-9260-c654-078a-7832e526ed7d', '89a470dd-70be-5d51-683d-94e3f9983f95', 'false', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('946afcaa-26a7-3d36-8ae2-6d1530c1b19b', '89a470dd-70be-5d51-683d-94e3f9983f95', 'true', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('7d516fbb-ee9c-7b20-9ea5-dc19bbffbcc9', '89a470dd-70be-5d51-683d-94e3f9983f95', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('252272ba-0ba9-c49e-98ee-06e25e4e953c', '89a470dd-70be-5d51-683d-94e3f9983f95', '63c901f9-9260-c654-078a-7832e526ed7d', '! invierte el booleano.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('fbb1585b-bfb5-3c12-4d9f-19482b6168a6', '30000000-0000-0000-0000-000000000015', 'La expresión x || y devuelve el primer valor truthy.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('e8944445-aceb-6b51-d103-1308ceca6bf3', 'fbb1585b-bfb5-3c12-4d9f-19482b6168a6', 'O evalúa x y devuelve y si x es falsy.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('638b96ed-9f2b-1e88-27fd-70c11d433c86', 'fbb1585b-bfb5-3c12-4d9f-19482b6168a6', 'Siempre devuelve y.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('b4c6d5a0-dd72-5d57-2c47-15626a61e2a7', 'fbb1585b-bfb5-3c12-4d9f-19482b6168a6', 'e8944445-aceb-6b51-d103-1308ceca6bf3', '|| usa cortocircuito: devuelve el primer truthy.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('75bf37e4-0b56-6814-50a3-61893bce933e', '30000000-0000-0000-0000-000000000016', '¿Qué imprime este código? let nota = 8; if (nota >= 9) console.log("A"); else if (nota >= 7) console.log("B"); else console.log("C");', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('3ae7f3ff-a2d2-4e66-c7ec-b24548afaf59', '75bf37e4-0b56-6814-50a3-61893bce933e', 'B', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('2b32664a-9b77-3f8a-bf24-129e67fe2d69', '75bf37e4-0b56-6814-50a3-61893bce933e', 'A', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('04edb627-02b5-f155-7f3b-fd6176ea284d', '75bf37e4-0b56-6814-50a3-61893bce933e', 'C', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8e679159-8bbd-0c6f-0bee-20c6162d4f79', '75bf37e4-0b56-6814-50a3-61893bce933e', '3ae7f3ff-a2d2-4e66-c7ec-b24548afaf59', 'La primera condición que se cumple se ejecuta: nota >= 7 da B.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('729da75e-4332-c654-e13f-96ec8ffb08cf', '30000000-0000-0000-0000-000000000016', '¿Cuál rama se ejecuta si n = -3?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('6d3d81ee-89d5-b453-d961-639a9980385a', '729da75e-4332-c654-e13f-96ec8ffb08cf', 'else if (n < 0)', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e318c09c-645e-71b2-1a2d-4c98a10e525e', '729da75e-4332-c654-e13f-96ec8ffb08cf', 'if (n > 0)', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('727f7250-a8ac-cada-3111-e608c75e585b', '729da75e-4332-c654-e13f-96ec8ffb08cf', 'else', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4fca61d6-dfff-26b2-7349-4c99588abb16', '729da75e-4332-c654-e13f-96ec8ffb08cf', '6d3d81ee-89d5-b453-d961-639a9980385a', '-3 no es mayor que 0, pero sí menor que 0.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('1c644fce-b57d-0e98-fd33-237a1dff8500', '30000000-0000-0000-0000-000000000016', 'else if se evalúa en orden.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('75a4a773-dda9-1df2-f7d4-afc9f53b4359', '1c644fce-b57d-0e98-fd33-237a1dff8500', 'De arriba hacia abajo hasta que alguna se cumpla.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('42fc2946-e3be-a564-90ad-c06152cd59d3', '1c644fce-b57d-0e98-fd33-237a1dff8500', 'En cualquier orden.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('2fb5f0ad-48aa-f9b4-d7e4-357f1287ff99', '1c644fce-b57d-0e98-fd33-237a1dff8500', '75a4a773-dda9-1df2-f7d4-afc9f53b4359', 'Siempre se evalúan de arriba hacia abajo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('916e8bba-4436-1fdc-16a0-04553115924e', '30000000-0000-0000-0000-000000000016', '¿Qué imprime este código? const x = 10; if (x > 5) { if (x > 8) { console.log("alto") } else { console.log("medio") } }', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('41dc7ff1-fd76-0aff-7b89-ee51bc7f4a54', '916e8bba-4436-1fdc-16a0-04553115924e', 'alto', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('9bbe3cc0-1449-523f-7b74-b7ba7b281774', '916e8bba-4436-1fdc-16a0-04553115924e', 'medio', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b6292e02-2859-2572-6715-97dbd358ff12', '916e8bba-4436-1fdc-16a0-04553115924e', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('ff2bc678-2eb9-8d24-4f32-f930b6209d5a', '916e8bba-4436-1fdc-16a0-04553115924e', '41dc7ff1-fd76-0aff-7b89-ee51bc7f4a54', '10 > 5 y 10 > 8: imprime alto.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('fba4a8c6-1680-631a-c78c-4d3d951f9b95', '30000000-0000-0000-0000-000000000016', '¿Qué ejecutaría si x = 4?', 'seleccion', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('8611871c-a75d-b99a-1160-b8a5d744c0ae', 'fba4a8c6-1680-631a-c78c-4d3d951f9b95', 'else if (x <= 5)', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('abc71fc0-1d32-40db-b22f-7f9be91afbe7', 'fba4a8c6-1680-631a-c78c-4d3d951f9b95', 'if (x > 5)', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1aad56a2-549e-cc63-69b5-9b2a607657c1', 'fba4a8c6-1680-631a-c78c-4d3d951f9b95', 'else { }', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('a65b4fb0-f0a2-45da-c7b1-33a014363c73', 'fba4a8c6-1680-631a-c78c-4d3d951f9b95', '8611871c-a75d-b99a-1160-b8a5d744c0ae', '4 no es mayor que 5, pero sí menor o igual.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('53834f00-8b28-d49a-d44c-3b57e5b2f93a', '30000000-0000-0000-0000-000000000017', '¿Cuándo se ejecuta else?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('01e79261-2bad-7c0e-5804-553e03dbf442', '53834f00-8b28-d49a-d44c-3b57e5b2f93a', 'Cuando todas las condiciones previas fueron falsas.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('34b83d5f-e6c7-0389-a224-8f7131cbcbb1', '53834f00-8b28-d49a-d44c-3b57e5b2f93a', 'Siempre.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5334445a-2d2b-4da3-1ab0-9ec22a982a17', '53834f00-8b28-d49a-d44c-3b57e5b2f93a', 'Nunca.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6c9711ba-911a-867e-a47d-6143041422db', '53834f00-8b28-d49a-d44c-3b57e5b2f93a', '01e79261-2bad-7c0e-5804-553e03dbf442', 'else es el "si no se cumplió ninguna de las anteriores".') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('b8bdb541-bc12-6b5c-a72e-59bdad22eb84', '30000000-0000-0000-0000-000000000017', '¿Qué imprime este código? const valor = 30; if (valor > 50) console.log("alto"); else if (valor > 10) console.log("medio"); else console.log("bajo");', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('da0ba0af-0312-07f4-7027-d551212ee8f3', 'b8bdb541-bc12-6b5c-a72e-59bdad22eb84', 'medio', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c9db07f8-81cb-0e07-0657-e2083649f559', 'b8bdb541-bc12-6b5c-a72e-59bdad22eb84', 'alto', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f567d40b-90ec-5633-c0c6-b7d4e320cc5b', 'b8bdb541-bc12-6b5c-a72e-59bdad22eb84', 'bajo', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('3b0d6958-e614-8ab7-19d1-14da07a2cdf4', 'b8bdb541-bc12-6b5c-a72e-59bdad22eb84', 'da0ba0af-0312-07f4-7027-d551212ee8f3', '30 > 10 y no > 50: medio.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('52ff5506-a26c-2f17-821f-d519bf0ce552', '30000000-0000-0000-0000-000000000017', 'Una condición falsa termina el while.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('f8e8d63d-e8c7-4ddc-32cc-4875c6aae3cd', '52ff5506-a26c-2f17-821f-d519bf0ce552', 'Mientras haya verdad hay repetición; cuando es falsa, termina.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('566cfdd4-5b8a-12c0-a8f2-db5bca4dd21c', '52ff5506-a26c-2f17-821f-d519bf0ce552', 'while siempre ejecuta una vez.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e360f0f6-5eb9-73b3-60cb-dc728fd83cf6', '52ff5506-a26c-2f17-821f-d519bf0ce552', 'f8e8d63d-e8c7-4ddc-32cc-4875c6aae3cd', 'while evalúa antes de cada iteración.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('28b17ec3-931e-a388-0892-4f5217ad4b82', '30000000-0000-0000-0000-000000000017', '¿Qué imprime este código? const x = 0; if (x) console.log("si"); else console.log("no");', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('fb3a066d-538d-73aa-d5a9-bf4718997688', '28b17ec3-931e-a388-0892-4f5217ad4b82', 'no', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b3500b89-d97a-3b97-bd15-557369411d7f', '28b17ec3-931e-a388-0892-4f5217ad4b82', 'si', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1c913d14-5488-9d32-972e-51115ddbb12b', '28b17ec3-931e-a388-0892-4f5217ad4b82', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0a84371d-681f-80cc-37c3-4e4fe0b8850b', '28b17ec3-931e-a388-0892-4f5217ad4b82', 'fb3a066d-538d-73aa-d5a9-bf4718997688', '0 es falsy en JavaScript.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('6e16cc1c-64d8-359c-0fe6-e412ef17f2b3', '30000000-0000-0000-0000-000000000017', 'En else if, el orden importa.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('55aaff7e-3172-629f-32b1-cfd02bf3f65a', '6e16cc1c-64d8-359c-0fe6-e412ef17f2b3', 'Las primeras condiciones se evalúan primero.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('0f6b586a-e274-5f79-ebf8-0457532615eb', '6e16cc1c-64d8-359c-0fe6-e412ef17f2b3', 'No importa el orden.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('a6da0768-0c24-95d7-49b7-103b2fdfb8e2', '6e16cc1c-64d8-359c-0fe6-e412ef17f2b3', '55aaff7e-3172-629f-32b1-cfd02bf3f65a', 'Siempre se evalúan de arriba hacia abajo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('7a2305ab-438f-22ab-afe6-0131ec198bba', '30000000-0000-0000-0000-000000000018', '¿Qué imprime este código? let suma = 0; for (let i = 1; i <= 4; i++) suma = suma + i; console.log(suma);', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('37000ae0-e5b6-414b-2669-6a7f3c9f832b', '7a2305ab-438f-22ab-afe6-0131ec198bba', '10', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5022e5da-7aa8-bd6d-645b-76c881f09516', '7a2305ab-438f-22ab-afe6-0131ec198bba', '4', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5acc88ec-c96e-20be-1ac5-124fcac9617a', '7a2305ab-438f-22ab-afe6-0131ec198bba', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8f366bda-c3bd-3ffc-f00d-c922e9e0ea84', '7a2305ab-438f-22ab-afe6-0131ec198bba', '37000ae0-e5b6-414b-2669-6a7f3c9f832b', '1+2+3+4 = 10.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('b4ee3795-7399-3a82-da4c-8530f98dd97d', '30000000-0000-0000-0000-000000000018', 'Un acumulador guarda:', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('ef90c674-e6ce-65cc-dcb1-36038a6d2f0f', 'b4ee3795-7399-3a82-da4c-8530f98dd97d', 'Un total que crece en cada iteración.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('91b951fd-fdcd-2fa1-1f8c-fdea11118dd6', 'b4ee3795-7399-3a82-da4c-8530f98dd97d', 'Un contador 0/1.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d70628ff-90a6-9b84-5f83-0f7861f75bb1', 'b4ee3795-7399-3a82-da4c-8530f98dd97d', 'El índice actual.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6efa9d8b-377d-2ad8-26f6-c69e6c78111b', 'b4ee3795-7399-3a82-da4c-8530f98dd97d', 'ef90c674-e6ce-65cc-dcb1-36038a6d2f0f', 'Un acumulador suma sobre sí mismo en cada paso.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('b22c9729-8bf8-1d87-29ec-a9b803d686eb', '30000000-0000-0000-0000-000000000018', '¿Qué imprime este código? let c = 0; for (let i = 0; i < 7; i++) { if (i % 2 === 0) c = c + 1; } console.log(c);', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('2108e428-101a-f9b6-392c-da1ec58196cd', 'b22c9729-8bf8-1d87-29ec-a9b803d686eb', '4', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('be31c7e2-b32d-2801-a785-f9e739cd0615', 'b22c9729-8bf8-1d87-29ec-a9b803d686eb', '3', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1b5140ba-b963-b99e-cdf8-2bc0c833cfb1', 'b22c9729-8bf8-1d87-29ec-a9b803d686eb', '7', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6f6d811b-182f-4ad6-b1cf-7f33cc87db8c', 'b22c9729-8bf8-1d87-29ec-a9b803d686eb', '2108e428-101a-f9b6-392c-da1ec58196cd', 'i en 0, 2, 4, 6: 4 valores pares.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('31635dcf-b19a-2018-bbee-174dd69563b5', '30000000-0000-0000-0000-000000000018', '¿Qué rol tiene i en for?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('b70663dc-2669-eb9f-a269-1ec8ce6da5bb', '31635dcf-b19a-2018-bbee-174dd69563b5', 'Contador que aumenta en cada iteración.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('0dd66f34-0795-3031-11f9-36f4a36ea937', '31635dcf-b19a-2018-bbee-174dd69563b5', 'No cambia.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('92ceaa05-efdd-d98d-1d34-e965893e516b', '31635dcf-b19a-2018-bbee-174dd69563b5', 'Es un acumulador.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('bf0b65ba-692c-d53f-c617-a11230e74ddd', '31635dcf-b19a-2018-bbee-174dd69563b5', 'b70663dc-2669-eb9f-a269-1ec8ce6da5bb', 'i es el contador clásico del for.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('4c3da434-ecad-423a-39f2-4319af0a798a', '30000000-0000-0000-0000-000000000019', 'Un bucle infinito produce:', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('c01a387c-9521-5e3f-d4c4-54cad7d47474', '4c3da434-ecad-423a-39f2-4319af0a798a', 'Un bloqueo temporal típico.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('57ee03a4-f87d-6c2f-9157-7d7f63d14392', '4c3da434-ecad-423a-39f2-4319af0a798a', 'Una excepción inmediata.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4a8f2e3a-8e34-b0fa-cd6b-136a5ee63120', '4c3da434-ecad-423a-39f2-4319af0a798a', 'Un error de sintaxis.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('29e527d7-b07d-d5c5-bf02-b36ddb131fd1', '4c3da434-ecad-423a-39f2-4319af0a798a', 'c01a387c-9521-5e3f-d4c4-54cad7d47474', 'while(true) nunca termina por sí solo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('1433f6d9-c713-4653-04a2-8ea3e0240cc2', '30000000-0000-0000-0000-000000000019', '¿Qué termina primero? while (n < 100) n = n + 10; donde n empieza en 0.', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('b21d9f7f-9e97-235b-5f0e-d8eb47327186', '1433f6d9-c713-4653-04a2-8ea3e0240cc2', 'Cuando n llega a 100.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('cc00465e-2626-19f8-68ce-805cbe75fd82', '1433f6d9-c713-4653-04a2-8ea3e0240cc2', 'Nunca.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8459abde-7b68-ba7e-ea51-b46d7ce7f361', '1433f6d9-c713-4653-04a2-8ea3e0240cc2', 'Cuando n llega a 1000.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('c73f14d8-6e31-72a5-feac-2320afd16c90', '1433f6d9-c713-4653-04a2-8ea3e0240cc2', 'b21d9f7f-9e97-235b-5f0e-d8eb47327186', '0+10+10+…=100 ⇒ termina cuando n=100.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('56cbe712-3fa8-f9c5-0232-c518b94300f9', '30000000-0000-0000-0000-000000000019', '¿Qué pasa si la condición de while es falsa desde el inicio?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('25c3f817-6f60-22b5-9c50-0876a5235458', '56cbe712-3fa8-f9c5-0232-c518b94300f9', 'No se ejecuta; sigue con la siguiente instrucción.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('09525efa-405f-8cf4-2f29-9d44577ff329', '56cbe712-3fa8-f9c5-0232-c518b94300f9', 'Ejecuta una vez igual.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8f3e8baf-5a44-dc44-a1c4-091fceb3072e', '56cbe712-3fa8-f9c5-0232-c518b94300f9', 'Produce error.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6456d941-1c6a-c65b-9d3e-2423bde8c9fa', '56cbe712-3fa8-f9c5-0232-c518b94300f9', '25c3f817-6f60-22b5-9c50-0876a5235458', 'El cuerpo puede no ejecutarse nunca.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('d5f10910-19cc-04d3-ccbd-70756fddd6c4', '30000000-0000-0000-0000-000000000019', 'Un for necesita que la condición sea falsa para terminar.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('33b38b36-a2a1-819e-3c07-f1c6e268e646', 'd5f10910-19cc-04d3-ccbd-70756fddd6c4', 'i <= 5 detiene en 5; i >= 0 con i++ nunca se detiene.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4d4f3336-ec78-1759-2a49-b65ab5063b8b', 'd5f10910-19cc-04d3-ccbd-70756fddd6c4', 'Termina por tiempo por sí solo.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('fdb7542f-3285-c8bb-a475-077ca8385f33', 'd5f10910-19cc-04d3-ccbd-70756fddd6c4', '33b38b36-a2a1-819e-3c07-f1c6e268e646', 'Termina cuando la condición es falsa.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('efeaed73-b197-8c82-82fc-f81f32bcff3a', '30000000-0000-0000-0000-000000000020', '¿Qué imprime este código? let sum = 0; for (let i = 0; i < 3; i++) sum = sum + 10; console.log(sum);', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('2d7fd847-5a3a-f118-ebd2-d58c792a2245', 'efeaed73-b197-8c82-82fc-f81f32bcff3a', '30', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a1683686-a74c-018b-a520-91eb3f34ae75', 'efeaed73-b197-8c82-82fc-f81f32bcff3a', '10', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5171ec9b-a719-1d06-c553-21058a810a57', 'efeaed73-b197-8c82-82fc-f81f32bcff3a', '0', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4d037526-d19e-42fe-32cb-57d1fd0f959b', 'efeaed73-b197-8c82-82fc-f81f32bcff3a', '2d7fd847-5a3a-f118-ebd2-d58c792a2245', 'En cada vuelta sum = sum + 10: 10, 20, 30.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('6803105a-e65a-90f5-8dab-6866e8774a19', '30000000-0000-0000-0000-000000000020', '¿Qué imprime este código? let c = 0; for (let i = 0; i < 6; i++) c = c + (i % 2); console.log(c);', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('ce5fd629-02df-6bc0-1dca-9bec3da99152', '6803105a-e65a-90f5-8dab-6866e8774a19', '3', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('bee0d10e-e14f-b495-8bb1-35a215ad6db9', '6803105a-e65a-90f5-8dab-6866e8774a19', '6', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('fed11455-f008-c676-9278-b5fdcf2594d1', '6803105a-e65a-90f5-8dab-6866e8774a19', '9', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('af0ed198-0f9c-961c-41bb-8d158ceb9520', '6803105a-e65a-90f5-8dab-6866e8774a19', 'ce5fd629-02df-6bc0-1dca-9bec3da99152', 'i en 0,1,2,3,4,5: pares 0+0+0 (3), impares 1+1+1 (3) — total 3.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('492da31c-d3fa-6d29-48e4-08774cd17137', '30000000-0000-0000-0000-000000000020', '¿Cuántas veces se repite este bucle para que x llegue a 50? x = 2; while (x < 50) x = x * 2;', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('95b8e48d-4b53-b22f-aa96-49b18391d5ca', '492da31c-d3fa-6d29-48e4-08774cd17137', 'Cinco veces (2→4→8→16→32→64).', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('23f59bd9-daf7-6109-07d9-60954706c4a2', '492da31c-d3fa-6d29-48e4-08774cd17137', 'Diez veces.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('608003a3-8989-1fdd-b33d-5a29f7f6e948', '492da31c-d3fa-6d29-48e4-08774cd17137', 'Infinitamente.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('7300d2a0-288e-bf99-324b-b6cf6a685762', '492da31c-d3fa-6d29-48e4-08774cd17137', '95b8e48d-4b53-b22f-aa96-49b18391d5ca', '2,4,8,16,32,64: 5 pasos.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('774f56d0-f52c-54a8-8c75-5552af03e0b8', '30000000-0000-0000-0000-000000000020', 'Una condición falsa termina el while.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('37e0d29c-f7a7-3061-f756-10250145770a', '774f56d0-f52c-54a8-8c75-5552af03e0b8', 'Mientras la condición sea verdadera, repite.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4c83cfc2-5dd5-3c3a-a5b7-c26f232bced7', '774f56d0-f52c-54a8-8c75-5552af03e0b8', 'while siempre ejecuta una vez.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('496e16f6-83c5-54a6-f0c3-dab9aa079248', '774f56d0-f52c-54a8-8c75-5552af03e0b8', '37e0d29c-f7a7-3061-f756-10250145770a', 'while evalúa antes de cada iteración.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('595a6d91-e5ef-1087-233e-87e61cb93d09', '30000000-0000-0000-0000-000000000020', '¿Qué imprime este código? let sum = 0; for (let i = 0; i < 4; i++) sum = sum + 5; console.log(sum);', 'seleccion', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('85b9f00e-fded-840c-6e16-7e8225e624aa', '595a6d91-e5ef-1087-233e-87e61cb93d09', '20', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5282a759-87ee-0953-e24b-8103c32b69b4', '595a6d91-e5ef-1087-233e-87e61cb93d09', '15', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b0e5d38f-cc9c-b64d-15e4-a21b187a9619', '595a6d91-e5ef-1087-233e-87e61cb93d09', '25', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6ad4c14c-76e4-4805-2f65-4447cd4b737e', '595a6d91-e5ef-1087-233e-87e61cb93d09', '85b9f00e-fded-840c-6e16-7e8225e624aa', '0+5+5+5+5 = 20.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('abb4ff87-9278-5944-f0c2-906482ae8567', '30000000-0000-0000-0000-000000000021', '¿Cuál es la diferencia entre parámetro y argumento?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('79dacd0b-5198-4320-fa17-557b25bc1ac4', 'abb4ff87-9278-5944-f0c2-906482ae8567', 'Parámetro es el nombre en la declaración; argumento el valor enviado.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('779d816f-1b2e-feaa-d413-a27db3ccfa4a', 'abb4ff87-9278-5944-f0c2-906482ae8567', 'Son lo mismo.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8a1389e5-b775-6294-844b-2c46a4878cb3', 'abb4ff87-9278-5944-f0c2-906482ae8567', 'Argumento es el nombre; parámetro el valor.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('32c8e51f-28ba-8ffc-eb7c-e666092dccb8', 'abb4ff87-9278-5944-f0c2-906482ae8567', '79dacd0b-5198-4320-fa17-557b25bc1ac4', 'Parámetro = variable, argumento = valor enviado.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('de7306b2-7450-435d-f363-ded2e4c44a59', '30000000-0000-0000-0000-000000000021', '¿Qué imprime este código? function saludar(nombre) { console.log("Hola " + nombre); } saludar("Ana");', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('91f490d7-6fcd-9c90-6ba0-feb9479498f5', 'de7306b2-7450-435d-f363-ded2e4c44a59', 'Hola Ana', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('24c122a1-8a1f-3fef-5a57-e2360de56483', 'de7306b2-7450-435d-f363-ded2e4c44a59', 'Hola nombre', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b87db63c-1d3b-8602-488c-9751dc583605', 'de7306b2-7450-435d-f363-ded2e4c44a59', 'Hola', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('d4e5027d-cbdf-d929-6eca-7d3c28c5631b', 'de7306b2-7450-435d-f363-ded2e4c44a59', '91f490d7-6fcd-9c90-6ba0-feb9479498f5', 'El argumento "Ana" entra como parámetro nombre.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('d196b738-c90b-23ed-5950-16787e05324b', '30000000-0000-0000-0000-000000000021', '¿Qué imprime este código? function suma(a, b) { return a + b; } console.log(suma(2, 3));', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('24ec7f59-146c-14bd-518c-2ddd4b911590', 'd196b738-c90b-23ed-5950-16787e05324b', '5', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('dbc9322e-7eb9-3e64-f238-92640471ce0a', 'd196b738-c90b-23ed-5950-16787e05324b', '23', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('2cb0aa42-0b71-3fc7-b7b2-5128c3533011', 'd196b738-c90b-23ed-5950-16787e05324b', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('474c6978-29d8-43da-dedf-ead36ce1070e', 'd196b738-c90b-23ed-5950-16787e05324b', '24ec7f59-146c-14bd-518c-2ddd4b911590', 'a=2, b=3, devuelve 5.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('d4ac490b-6e4b-e3d0-af55-bad1fd1af424', '30000000-0000-0000-0000-000000000021', '¿Qué valen a y b en suma(2, 3)?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('21bb4f45-8696-7c2b-a9d9-174dc0cfcc5f', 'd4ac490b-6e4b-e3d0-af55-bad1fd1af424', 'a=2, b=3', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('0aab2df3-63c1-3f40-0a27-6271071cb59c', 'd4ac490b-6e4b-e3d0-af55-bad1fd1af424', 'a=3, b=2', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('85ec4536-6814-9668-276c-9fdea58ea96c', 'd4ac490b-6e4b-e3d0-af55-bad1fd1af424', 'a="2", b="3"', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('00a32fbb-e12c-a2cb-7c84-7657857f715e', 'd4ac490b-6e4b-e3d0-af55-bad1fd1af424', '21bb4f45-8696-7c2b-a9d9-174dc0cfcc5f', 'Los argumentos se asignan por orden.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('2ccec8e6-23d9-a850-0c07-b8325a8ace7e', '30000000-0000-0000-0000-000000000022', '¿Qué pasa si una función no tiene return?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('3dc433d9-0df6-a274-c93f-c785a3d1649f', '2ccec8e6-23d9-a850-0c07-b8325a8ace7e', 'Devuelve undefined.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('9dc95403-a273-eb32-3a7b-9d160b24e63a', '2ccec8e6-23d9-a850-0c07-b8325a8ace7e', 'Devuelve null.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d8c66050-8261-7640-36f3-ab63943b8465', '2ccec8e6-23d9-a850-0c07-b8325a8ace7e', 'Lanza una excepción.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('c71f4db8-8427-6f69-47aa-7d44dcbc1b6b', '2ccec8e6-23d9-a850-0c07-b8325a8ace7e', '3dc433d9-0df6-a274-c93f-c785a3d1649f', 'Toda función devuelve algo: undefined por defecto.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('bfbb161b-9032-2eb5-4858-9ec5f54d8900', '30000000-0000-0000-0000-000000000022', 'Escribí el valor que falta para que la función devuelva w * h: return ___;', 'completar_texto', '{"alternativas": [], "valor": "w * h"}'::jsonb, 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, datos = excluded.datos, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('4d03e902-cb6c-8c71-1f00-291d706f2e51', 'bfbb161b-9032-2eb5-4858-9ec5f54d8900', '{"valor": "w * h"}'::jsonb, 'return w * h; devuelve el área.') on conflict (pregunta_id) do update set solucion = excluded.solucion, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('e07a9195-8ac3-6107-081b-fe7d9e19d4ad', '30000000-0000-0000-0000-000000000022', '¿Qué imprime este código? function uno() { return 10; } console.log(uno() + uno());', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('2fbe99de-93de-a333-5b52-60f8a9ff6e37', 'e07a9195-8ac3-6107-081b-fe7d9e19d4ad', '20', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d70c6d53-6e2d-5054-5e87-54f9f35b8bc0', 'e07a9195-8ac3-6107-081b-fe7d9e19d4ad', '10', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('cc1dc15b-76cf-1046-7da5-051bfc4b417e', 'e07a9195-8ac3-6107-081b-fe7d9e19d4ad', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0d06680d-fe3c-eed9-60b2-5664b752ee9d', 'e07a9195-8ac3-6107-081b-fe7d9e19d4ad', '2fbe99de-93de-a333-5b52-60f8a9ff6e37', '10 + 10 = 20.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('14005ba3-0b6c-4e98-951b-15fa01b15e0b', '30000000-0000-0000-0000-000000000022', '¿Qué imprime? function doble(x) { return x * 2; } console.log(doble(8));', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('54726531-6a78-f746-a539-9547b894dfce', '14005ba3-0b6c-4e98-951b-15fa01b15e0b', '16', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e076a4ed-19fd-fbc3-aa69-ffb8d36612ce', '14005ba3-0b6c-4e98-951b-15fa01b15e0b', '8', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('01c51d7a-b64c-7892-4711-114bbb8f3f28', '14005ba3-0b6c-4e98-951b-15fa01b15e0b', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8dfd793c-6aac-01a7-5716-295aa5717f52', '14005ba3-0b6c-4e98-951b-15fa01b15e0b', '54726531-6a78-f746-a539-9547b894dfce', 'doble(8) devuelve 16.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('b657d222-fda9-e8a8-f7d1-1929be340e4a', '30000000-0000-0000-0000-000000000023', '¿Qué devuelve map en el código anterior?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('29a3ba8f-a9bd-2ccd-e767-15737c57ac10', 'b657d222-fda9-e8a8-f7d1-1929be340e4a', 'Un nuevo array con valores modificados.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b910a43f-f4b5-90a3-83aa-890819ee851c', 'b657d222-fda9-e8a8-f7d1-1929be340e4a', 'Un array vacío.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a88ee900-5b7d-a1ce-85c4-d808cec5f981', 'b657d222-fda9-e8a8-f7d1-1929be340e4a', 'El array original.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e26ed196-cbbf-8f41-193c-5724a2b51294', 'b657d222-fda9-e8a8-f7d1-1929be340e4a', '29a3ba8f-a9bd-2ccd-e767-15737c57ac10', 'map transforma y devuelve un nuevo array.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('a7e9e352-4bea-67ed-7741-9464b690984e', '30000000-0000-0000-0000-000000000023', '¿Qué imprime este código? const nums = [1, 2, 3]; console.log(nums.map(n => n + 1));', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('09fea342-4c12-c900-7e12-323dafdf3c41', 'a7e9e352-4bea-67ed-7741-9464b690984e', '[2, 3, 4]', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('53c9798e-1c9f-3ae3-2427-30511838f3d2', 'a7e9e352-4bea-67ed-7741-9464b690984e', '[1, 2, 3]', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('6288dd79-87bf-f37a-9601-e97e6b7e5f13', 'a7e9e352-4bea-67ed-7741-9464b690984e', '[2, 4, 6]', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('32e2a4d0-aac3-3e81-a232-866b910c17f3', 'a7e9e352-4bea-67ed-7741-9464b690984e', '09fea342-4c12-c900-7e12-323dafdf3c41', 'n + 1 sobre cada elemento.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('76788b92-5bb1-23d5-58e2-cd76cd617c70', '30000000-0000-0000-0000-000000000023', '¿Qué hace filter?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('02149db6-52ed-443f-8b98-5081fa9ad626', '76788b92-5bb1-23d5-58e2-cd76cd617c70', 'Devuelve los elementos que cumplen la condición.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1ef8d77a-3db1-943c-c317-6f137911b058', '76788b92-5bb1-23d5-58e2-cd76cd617c70', 'Devuelve el primero que coincide.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('139c6751-969d-6ae5-cdbb-0b16247d5477', '76788b92-5bb1-23d5-58e2-cd76cd617c70', 'Modifica el array original.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('be36cb58-d12a-cd24-74c8-fb065dad0ba3', '76788b92-5bb1-23d5-58e2-cd76cd617c70', '02149db6-52ed-443f-8b98-5081fa9ad626', 'filter es selectiva, no destructiva.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('f21207b2-30b2-5bf4-5b49-95d6a55711d1', '30000000-0000-0000-0000-000000000023', '¿Qué imprime? const nums = [1, 2, 3, 4]; console.log(nums.filter(n => n > 2));', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('5ba86dab-db8c-ba7b-f9e3-5684b8eb820c', 'f21207b2-30b2-5bf4-5b49-95d6a55711d1', '[3, 4]', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('db442d9e-c870-2d99-4c64-f27a422ba9aa', 'f21207b2-30b2-5bf4-5b49-95d6a55711d1', '[1, 2]', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d2f5538c-8589-24b5-8bf6-1be12bb5df9d', 'f21207b2-30b2-5bf4-5b49-95d6a55711d1', '[2, 3, 4]', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('a2617bba-915f-94f9-99b3-7fc86ba881e4', 'f21207b2-30b2-5bf4-5b49-95d6a55711d1', '5ba86dab-db8c-ba7b-f9e3-5684b8eb820c', 'n > 2: queda 3 y 4.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('61fe283f-0e33-fa97-4157-33b298786309', '30000000-0000-0000-0000-000000000023', 'map crea un nuevo array; filter selecciona.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('a4c354c7-483c-ce78-8e68-962d4a6f830b', '61fe283f-0e33-fa97-4157-33b298786309', 'Map transforma 1 a 1; filter reduce por condicion.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a5d0e43f-a30c-477f-487b-6381417f02fc', '61fe283f-0e33-fa97-4157-33b298786309', 'Concatenan.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0dde0272-f9e2-3eec-9e33-8d3c6252a663', '61fe283f-0e33-fa97-4157-33b298786309', 'a4c354c7-483c-ce78-8e68-962d4a6f830b', 'Map transforma 1:1; filter selecciona.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('bbf8e14b-836c-7911-24bc-7f0556de19e2', '30000000-0000-0000-0000-000000000024', '¿Qué diferencia a una propiedad de un método?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('76bd14d8-c223-f89f-6db4-77c67426ec54', 'bbf8e14b-836c-7911-24bc-7f0556de19e2', 'Propiedad guarda dato; método es función del objeto.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b578c6f9-2898-85aa-aeb4-a78a0251cb8d', 'bbf8e14b-836c-7911-24bc-7f0556de19e2', 'No hay diferencia.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('90d7fd62-17dd-e3ae-cef4-90381c385690', 'bbf8e14b-836c-7911-24bc-7f0556de19e2', 'Un método es propiedad de un array.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('7790cf76-ef20-58df-6a3a-e91904ea6ca4', 'bbf8e14b-836c-7911-24bc-7f0556de19e2', '76bd14d8-c223-f89f-6db4-77c67426ec54', 'propiedad = dato; método = función.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('0f83d7e0-2a6d-d2f3-17d2-5746fba8e027', '30000000-0000-0000-0000-000000000024', '¿Qué imprime este código? const o = { n: 5, d() { return this.n * 2; } }; console.log(o.d());', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('1cc126ac-70fb-f4f5-4475-0141a09089e4', '0f83d7e0-2a6d-d2f3-17d2-5746fba8e027', '10', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('85529119-afef-ef21-c214-92f8c6f8e6e0', '0f83d7e0-2a6d-d2f3-17d2-5746fba8e027', '25', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('69e9c52d-a5ed-a40d-cf3c-50c5a9a22453', '0f83d7e0-2a6d-d2f3-17d2-5746fba8e027', 'undefined', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('44ee06e0-5084-442d-d6d8-8c21bfac2ab1', '0f83d7e0-2a6d-d2f3-17d2-5746fba8e027', '1cc126ac-70fb-f4f5-4475-0141a09089e4', 'd() devuelve 5 * 2 = 10.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion) values ('5be59280-1c9b-c576-3115-c1cb77c11002', '30000000-0000-0000-0000-000000000024', 'Escribí qué falta para que o.mostrar() llame al método mostrar: const o = { ___: function mostrar() { console.log("hola"); } };', 'completar_texto', '{"alternativas": [], "valor": "mostrar"}'::jsonb, 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, datos = excluded.datos, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into soluciones (id, pregunta_id, solucion, explicacion) values ('43c412fc-701d-9a97-8973-75e539115fb7', '5be59280-1c9b-c576-3115-c1cb77c11002', '{"valor": "mostrar"}'::jsonb, 'El nombre de la propiedad es el nombre del método.') on conflict (pregunta_id) do update set solucion = excluded.solucion, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('319d2720-7d48-9686-5eca-438d3ee9f737', '30000000-0000-0000-0000-000000000024', '¿Qué imprime este código? const o = { x: 1 }; console.log(o.x);', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('f8cce7d0-12b8-a334-c152-2db8b062ce08', '319d2720-7d48-9686-5eca-438d3ee9f737', '1', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e9d6b155-c639-db90-3050-f00b3126651b', '319d2720-7d48-9686-5eca-438d3ee9f737', 'undefined', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('029a4e25-ef20-38bb-64e0-8e80a5f60367', '319d2720-7d48-9686-5eca-438d3ee9f737', 'o.x', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('bebedd84-6c1e-ab0b-b30b-f99ab9496ceb', '319d2720-7d48-9686-5eca-438d3ee9f737', 'f8cce7d0-12b8-a334-c152-2db8b062ce08', 'Se accede con el punto.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('50be3cc7-e27d-49a6-4ae2-c733b1b83a6c', '30000000-0000-0000-0000-000000000025', '¿Qué es el DOM?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('a0ccc719-2109-7f1e-faac-31557dc71ad5', '50be3cc7-e27d-49a6-4ae2-c733b1b83a6c', 'Document Object Model: la representación en árbol de la página.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('bdebf588-cef3-cfcb-ce3b-b0c99c4deda3', '50be3cc7-e27d-49a6-4ae2-c733b1b83a6c', 'Un lenguaje de programación.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('31b6df0b-a128-8633-a6c1-442868d67e4d', '50be3cc7-e27d-49a6-4ae2-c733b1b83a6c', 'Una base de datos.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('7f680b56-064d-fe24-27db-c9d55771bfa9', '50be3cc7-e27d-49a6-4ae2-c733b1b83a6c', 'a0ccc719-2109-7f1e-faac-31557dc71ad5', 'El DOM es el árbol de la página.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c54362bb-24db-b223-94a2-bd57b2904d7a', '30000000-0000-0000-0000-000000000025', '¿Qué hace document.querySelector?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('854fa90b-f277-e27b-3657-de947b11baae', 'c54362bb-24db-b223-94a2-bd57b2904d7a', 'Devuelve el primer elemento que coincide con el selector.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b9d48146-4356-de7a-5426-cffc71b6b792', 'c54362bb-24db-b223-94a2-bd57b2904d7a', 'Devuelve todos los elementos.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b2d7aeef-4af7-7f1e-9e55-c4edd00ff2ae', 'c54362bb-24db-b223-94a2-bd57b2904d7a', 'No hace nada.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('387810eb-31bb-bbc6-d7fe-808c56285886', 'c54362bb-24db-b223-94a2-bd57b2904d7a', '854fa90b-f277-e27b-3657-de947b11baae', 'Primer match según selector CSS.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ed3aae5f-eaa8-e68d-c608-e49d525922a1', '30000000-0000-0000-0000-000000000025', 'El DOM es una API.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('d24cfc26-9f45-c5ac-5ee3-b36060628b24', 'ed3aae5f-eaa8-e68d-c608-e49d525922a1', 'El navegador expone el DOM como API.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('147a46a2-b73e-f991-dfe8-a7f862e90670', 'ed3aae5f-eaa8-e68d-c608-e49d525922a1', 'No es una API.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('fdeb8327-16df-a8ca-4178-4a9a78f43d8b', 'ed3aae5f-eaa8-e68d-c608-e49d525922a1', 'd24cfc26-9f45-c5ac-5ee3-b36060628b24', 'document, window, console son partes del DOM.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('283aad86-f211-75c5-bdb6-13f65f9be689', '30000000-0000-0000-0000-000000000025', '¿Qué hace el código siguiente? document.querySelector("#btn").addEventListener("click", () => console.log("clic"));', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('dc49a180-ed60-11e8-7d9b-f79a9169ce66', '283aad86-f211-75c5-bdb6-13f65f9be689', 'Imprime "clic" cuando se presiona el botón con id btn.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('79b9d2a1-a28b-94c9-6209-d7dbf6517286', '283aad86-f211-75c5-bdb6-13f65f9be689', 'Imprime "clic" al cargar la página.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8a59c3ca-7c20-1282-178c-ed05d8d24f30', '283aad86-f211-75c5-bdb6-13f65f9be689', 'Cambia el texto del botón.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('37a8c3c6-f452-7c05-0a06-d9180ed52263', '283aad86-f211-75c5-bdb6-13f65f9be689', 'dc49a180-ed60-11e8-7d9b-f79a9169ce66', 'addEventListener suscribe a eventos del elemento.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('8c4939bb-4c8d-cff8-ab97-3cc289160ee3', '70000000-0000-0000-0000-000000000001', '¿Qué significa HTML?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('07e8d527-3323-7511-62e7-0b9d3a4654a4', '8c4939bb-4c8d-cff8-ab97-3cc289160ee3', 'HyperText Markup Language.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('58533f53-f74a-366b-01ed-c1094b804acb', '8c4939bb-4c8d-cff8-ab97-3cc289160ee3', 'High Text Manipulation Language.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c5e3a38d-df88-3aca-82b3-d9c7dcaf2c4d', '8c4939bb-4c8d-cff8-ab97-3cc289160ee3', 'Hyperlink and Text Markup Language.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('823d7af5-e96c-0d03-75db-6f75c50b1eb0', '8c4939bb-4c8d-cff8-ab97-3cc289160ee3', '07e8d527-3323-7511-62e7-0b9d3a4654a4', 'HTML es HyperText Markup Language.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('396b51ff-20c7-a099-5c35-29afb0197180', '70000000-0000-0000-0000-000000000001', 'HTML es un lenguaje de programación.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('68a8d057-df5f-9340-74ce-e0a0621db5ad', '396b51ff-20c7-a099-5c35-29afb0197180', 'No, es un lenguaje de marcado; no ejecuta instrucciones.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('06a6018b-abec-c9ff-c691-754e6ca5a6fb', '396b51ff-20c7-a099-5c35-29afb0197180', 'Ejecuta sentencias.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('abd9e77b-3532-08cd-d43c-e587a1a4a89d', '396b51ff-20c7-a099-5c35-29afb0197180', '68a8d057-df5f-9340-74ce-e0a0621db5ad', 'HTML describe estructura; no ejecuta sentencias (eso lo hace JavaScript).') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('fcf23c2e-df0b-3546-d446-8ff33688ab41', '70000000-0000-0000-0000-000000000001', '¿Cuál es el propósito principal de HTML?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('0ca34de7-7ae1-eb64-5323-e727eaa29745', 'fcf23c2e-df0b-3546-d446-8ff33688ab41', 'Estructurar el contenido de las páginas web.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('2ba038f2-c9f6-23f1-4c05-859e97a230f0', 'fcf23c2e-df0b-3546-d446-8ff33688ab41', 'Diseñar imágenes y logotipos.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1a078132-e101-a145-70e5-74f85e37c8fa', 'fcf23c2e-df0b-3546-d446-8ff33688ab41', 'Servir datos a aplicaciones móviles.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0cde20d1-7486-47a3-03ce-173c158401ae', 'fcf23c2e-df0b-3546-d446-8ff33688ab41', '0ca34de7-7ae1-eb64-5323-e727eaa29745', 'HTML define la estructura del documento.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c77e70c9-6f3a-bfa6-4c68-f6d9104ae5cd', '70000000-0000-0000-0000-000000000001', '¿Qué hace una declaración <!DOCTYPE html>?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('d46882a4-f19f-d051-ea14-8093f131a79b', 'c77e70c9-6f3a-bfa6-4c68-f6d9104ae5cd', 'Le dice al navegador que el documento es HTML5.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('13d25668-0efe-ce33-d421-2e7c973914e7', 'c77e70c9-6f3a-bfa6-4c68-f6d9104ae5cd', 'Crea el primer párrafo.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('967d32ed-f56d-67e7-8d16-09f3e8be8bbd', 'c77e70c9-6f3a-bfa6-4c68-f6d9104ae5cd', 'No hace nada.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e1b16044-68bd-6ba9-abc4-f9317da62d26', 'c77e70c9-6f3a-bfa6-4c68-f6d9104ae5cd', 'd46882a4-f19f-d051-ea14-8093f131a79b', 'DOCTYPE declara el tipo de documento al navegador.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('a0684e78-491c-2bba-39cc-7ede93b0404c', '70000000-0000-0000-0000-000000000002', '¿Cuál es un título de segundo nivel?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('890c736b-d9b9-eec4-31fb-2e588fd8e6a9', 'a0684e78-491c-2bba-39cc-7ede93b0404c', '<h2>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8238994c-239f-0678-f36f-68187b7732cb', 'a0684e78-491c-2bba-39cc-7ede93b0404c', '<h1>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('64b43a21-144e-de04-e044-13c69d9603d7', 'a0684e78-491c-2bba-39cc-7ede93b0404c', '<h3>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('43e95868-eb4e-54cb-429a-cf044e67f01e', 'a0684e78-491c-2bba-39cc-7ede93b0404c', '890c736b-d9b9-eec4-31fb-2e588fd8e6a9', 'h1-h6 jerarquía según importancia.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('5da0697c-6d26-401f-0b80-7eca81bddffa', '70000000-0000-0000-0000-000000000002', '¿Cuál es el orden correcto de anidamiento?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('6fbc74fd-b641-aa2e-9c48-d1f0aedaa1d0', '5da0697c-6d26-401f-0b80-7eca81bddffa', '<h1><h2>Texto</h2></h1>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d6b4fda1-f156-0ad0-1cfc-91b979f728e2', '5da0697c-6d26-401f-0b80-7eca81bddffa', '<h2><h1>Texto</h1></h2>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b87097e0-220b-00f9-a779-56fef32b7b42', '5da0697c-6d26-401f-0b80-7eca81bddffa', 'No importa.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('f66b42c3-6dab-f030-3b4a-81466bf2099b', '5da0697c-6d26-401f-0b80-7eca81bddffa', '6fbc74fd-b641-aa2e-9c48-d1f0aedaa1d0', 'Las etiquetas deben abrirse y cerrarse en orden inverso.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('e9810f06-558b-85fa-1d61-ac3446040738', '70000000-0000-0000-0000-000000000002', '¿Qué hace el comentario <!-- comentario -->?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('10110690-fe05-b4ad-23ce-2411de6337a2', 'e9810f06-558b-85fa-1d61-ac3446040738', 'Se ignora al renderizar; sirve para anotar.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('287814c5-6d6f-0505-bdb4-c0cd7c3fd14c', 'e9810f06-558b-85fa-1d61-ac3446040738', 'Muestra el comentario en la página.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('75100d18-bf15-b029-722c-c5a195418b13', 'e9810f06-558b-85fa-1d61-ac3446040738', 'Lanza un error.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('7fad360a-abe0-b7f7-076f-e45f8fa8a504', 'e9810f06-558b-85fa-1d61-ac3446040738', '10110690-fe05-b4ad-23ce-2411de6337a2', 'Los comentarios son para el autor.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ed5aedbf-2143-a116-4910-88e25092631e', '70000000-0000-0000-0000-000000000002', 'La etiqueta <br> necesita cierre.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('c2d60f26-995e-cd08-9587-51cfd2708c4f', 'ed5aedbf-2143-a116-4910-88e25092631e', 'br es un salto de línea sin contenido; no lleva cierre.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a945a59d-7650-ddca-c37d-7fb56992daf0', 'ed5aedbf-2143-a116-4910-88e25092631e', 'Va <br></br>.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('64aa9da0-0517-27d5-de1e-9c162940ed35', 'ed5aedbf-2143-a116-4910-88e25092631e', 'c2d60f26-995e-cd08-9587-51cfd2708c4f', 'br, hr, img, input son etiquetas vacías.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('93b230af-e4bc-191a-3778-ac03f8cde540', '70000000-0000-0000-0000-000000000003', '¿Qué etiqueta envuelve al cuerpo?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('b0e6ceea-0ad7-5688-8f4f-8a598fe0a0bc', '93b230af-e4bc-191a-3778-ac03f8cde540', '<body>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c3c71ada-4cb3-23f2-060a-f2b02c0929bf', '93b230af-e4bc-191a-3778-ac03f8cde540', '<html>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a51f4a71-e350-783b-3121-383e5bad96ab', '93b230af-e4bc-191a-3778-ac03f8cde540', '<head>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('75e0d3e3-7657-ac9c-abe8-1305e7aae5fa', '93b230af-e4bc-191a-3778-ac03f8cde540', 'b0e6ceea-0ad7-5688-8f4f-8a598fe0a0bc', 'body es el contenido visible.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('94a9d623-b15a-a72e-acb7-9cea1572ba0a', '70000000-0000-0000-0000-000000000003', 'El <title> de un documento HTML aparece en la pestaña del navegador.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('dfcdf2ac-ce8e-9276-b33b-714be1c0ff79', '94a9d623-b15a-a72e-acb7-9cea1572ba0a', 'El contenido de title se muestra en la pestaña.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('33593217-71b3-ce60-90b5-f8828d2f3cd0', '94a9d623-b15a-a72e-acb7-9cea1572ba0a', 'Los títulos no van en ningún lado.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('19a28a1c-b51e-7a61-9f23-36d3de96b5b5', '94a9d623-b15a-a72e-acb7-9cea1572ba0a', 'dfcdf2ac-ce8e-9276-b33b-714be1c0ff79', '<title> está dentro de <head> y define el título de la pestaña.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c628217a-7def-70c5-9c53-5db621bb8277', '70000000-0000-0000-0000-000000000003', '¿Qué etiqueta jerárquica es la más importante?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('9d2da07c-70aa-a67e-17bd-8ffdd240f4ff', 'c628217a-7def-70c5-9c53-5db621bb8277', '<h1>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('90ff58e2-0aff-36cf-b592-5b03fa679bb7', 'c628217a-7def-70c5-9c53-5db621bb8277', '<h2>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('6f89ae98-d441-b2f3-4b60-ba540da9b359', 'c628217a-7def-70c5-9c53-5db621bb8277', '<h6>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('36a9316c-a697-e543-ca34-5d5fc3fb7bcc', 'c628217a-7def-70c5-9c53-5db621bb8277', '9d2da07c-70aa-a67e-17bd-8ffdd240f4ff', 'h1 es el encabezado de mayor jerarquía.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('8c47a6a3-cdca-7d2b-c4fe-577a67c08ac3', '70000000-0000-0000-0000-000000000003', '¿Qué contiene <head>?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('31a238d2-14f7-2514-33fb-2c08bcf2e3e3', '8c47a6a3-cdca-7d2b-c4fe-577a67c08ac3', 'Metadatos como charset, title, enlaces CSS.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('91a8a257-327f-811a-6bb9-d4b2df44ac1a', '8c47a6a3-cdca-7d2b-c4fe-577a67c08ac3', 'El contenido visible.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('3f60ce90-9337-8db8-acd5-4482d7cb5971', '8c47a6a3-cdca-7d2b-c4fe-577a67c08ac3', 'Las imágenes.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8340754d-0274-56bf-a08f-032eb2b65e14', '8c47a6a3-cdca-7d2b-c4fe-577a67c08ac3', '31a238d2-14f7-2514-33fb-2c08bcf2e3e3', 'head NO se renderiza directamente.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('455eeb79-976d-e39b-9429-26f1ccf89ad3', '70000000-0000-0000-0000-000000000003', 'Los elementos void como <img> o <input> no tienen etiqueta de cierre.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('8d59ee58-f15a-8bfd-9464-0c894fc275a5', '455eeb79-976d-e39b-9429-26f1ccf89ad3', 'Son etiquetas vacías por definición.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f9d0ac3f-7647-8134-d16b-4cd8210e6d75', '455eeb79-976d-e39b-9429-26f1ccf89ad3', 'Siempre llevan cierre.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('85069bd4-7400-bdbc-3de8-688a72a499e3', '455eeb79-976d-e39b-9429-26f1ccf89ad3', '8d59ee58-f15a-8bfd-9464-0c894fc275a5', 'img, input, br, hr, meta son void elements.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('567bd843-2d72-4dab-e516-9e49d53654ff', '70000000-0000-0000-0000-000000000004', '¿Qué etiqueta se usa para rutas relativas?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('173a064e-a36b-b52d-4296-d310c27d9c7a', '567bd843-2d72-4dab-e516-9e49d53654ff', '<a href="contacto.html">', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d8f7dc9f-0db6-2487-4c75-7d7561d5e3b1', '567bd843-2d72-4dab-e516-9e49d53654ff', '<a src="contacto.html">', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('abb8cf18-2721-5117-40f3-eb6c0b51da64', '567bd843-2d72-4dab-e516-9e49d53654ff', '<href="contacto.html">', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('943648ae-82c0-32e4-fee9-23fa76370b68', '567bd843-2d72-4dab-e516-9e49d53654ff', '173a064e-a36b-b52d-4296-d310c27d9c7a', 'href es el destino de navegación.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('93fb68e9-1f16-8cf5-f681-6696c5ead294', '70000000-0000-0000-0000-000000000004', 'Una ruta absoluta comienza con:', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('eff0e35c-2ba6-e22e-d6db-4788c4895327', '93fb68e9-1f16-8cf5-f681-6696c5ead294', 'https://', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8b243f0b-6b50-2551-2c4d-08e7a1fff1df', '93fb68e9-1f16-8cf5-f681-6696c5ead294', '/', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8899a27c-c8c7-7e5e-a70d-c24ec01b89f0', '93fb68e9-1f16-8cf5-f681-6696c5ead294', './', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('158052e1-dc0c-78b6-dead-caaeb26bdae7', '93fb68e9-1f16-8cf5-f681-6696c5ead294', 'eff0e35c-2ba6-e22e-d6db-4788c4895327', 'Las rutas absolutas empiezan con protocolo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('f246d1ce-7ffc-ff60-2e8e-fbe6c30ac0f7', '70000000-0000-0000-0000-000000000004', 'Un enlace relativo desde index.html a carpeta/archivo.html es:', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('2ca1ea2e-a0bd-f529-d394-7829d8715f20', 'f246d1ce-7ffc-ff60-2e8e-fbe6c30ac0f7', '<a href="carpeta/archivo.html">', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('82dd24b1-b6fd-b50d-3164-1c6cc9c48cf8', 'f246d1ce-7ffc-ff60-2e8e-fbe6c30ac0f7', '<a href="archivo.html">', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('ce17862a-9b6c-0c1a-cf4e-ed7494efbd3e', 'f246d1ce-7ffc-ff60-2e8e-fbe6c30ac0f7', '<a href="../archivo.html">', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('b7e99d07-951d-eb9a-e7f7-ffb2d9376025', 'f246d1ce-7ffc-ff60-2e8e-fbe6c30ac0f7', '2ca1ea2e-a0bd-f529-d394-7829d8715f20', 'Las rutas relativas incluyen la carpeta desde el documento.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('9b0143a9-908b-bece-571a-468c17cc882f', '70000000-0000-0000-0000-000000000004', 'Un enlace puede abrirse en nueva pestaña con:', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7d0ef6ed-621e-0a9e-1255-7f0b4b4a291d', '9b0143a9-908b-bece-571a-468c17cc882f', 'target="_blank"', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a3adf4ee-bbc5-ae25-9e32-46810fa328c3', '9b0143a9-908b-bece-571a-468c17cc882f', 'newtab="true"', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('efd7fb77-0809-d77f-917a-0ce017851ca1', '9b0143a9-908b-bece-571a-468c17cc882f', 'target="new"', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('be9df656-64e6-1dcd-13a8-47d09c7fd5af', '9b0143a9-908b-bece-571a-468c17cc882f', '7d0ef6ed-621e-0a9e-1255-7f0b4b4a291d', 'target="_blank" abre en pestaña nueva.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('78e14e71-7d85-30c3-bed4-4eb2e901d69f', '70000000-0000-0000-0000-000000000005', '¿Qué etiqueta se usa para elementos de lista?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('84f81655-f923-fae2-d857-21edfd5d37cf', '78e14e71-7d85-30c3-bed4-4eb2e901d69f', '<li>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('82f0f74b-cbe7-0347-06ed-548c50b504b9', '78e14e71-7d85-30c3-bed4-4eb2e901d69f', '<ol>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('02f7802e-681d-ad79-c4a3-7079175db73d', '78e14e71-7d85-30c3-bed4-4eb2e901d69f', '<ul>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0d0922c9-7887-41b8-e0da-69ab3ae1825d', '78e14e71-7d85-30c3-bed4-4eb2e901d69f', '84f81655-f923-fae2-d857-21edfd5d37cf', 'li = list item.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('9c2cfe75-e844-3b4f-c864-1d5d33ecf34d', '70000000-0000-0000-0000-000000000005', '¿Cuál lista muestra números por defecto?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('f806070a-8a5d-527e-48d7-3725f9450074', '9c2cfe75-e844-3b4f-c864-1d5d33ecf34d', '<ol>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('b5212be3-7b73-c868-76e8-fdf26d06cbb9', '9c2cfe75-e844-3b4f-c864-1d5d33ecf34d', '<ul>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('2f4c6750-a4b5-288a-4342-511bd07832fa', '9c2cfe75-e844-3b4f-c864-1d5d33ecf34d', '<li>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('9e40b387-4041-5f3f-c287-73de56e90e29', '9c2cfe75-e844-3b4f-c864-1d5d33ecf34d', 'f806070a-8a5d-527e-48d7-3725f9450074', 'ol = números; ul = viñetas.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('a5e0e406-b506-1125-c5a7-6f2885d8d9ac', '70000000-0000-0000-0000-000000000005', '¿Qué crea anidadas?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('6a1acbd1-468a-fc0b-c11f-73ee2d3497cb', 'a5e0e406-b506-1125-c5a7-6f2885d8d9ac', 'Poner un <ul>/<ol> dentro de un <li>.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4367313a-dae5-8a68-1993-05088edc267a', 'a5e0e406-b506-1125-c5a7-6f2885d8d9ac', 'Anidar etiquetas libremente.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('2c7bca06-9a90-4f8f-9aa3-15213b5efc3b', 'a5e0e406-b506-1125-c5a7-6f2885d8d9ac', 'Usar <dir>.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4ff11270-88d1-8a0c-bab2-3e847dd582db', 'a5e0e406-b506-1125-c5a7-6f2885d8d9ac', '6a1acbd1-468a-fc0b-c11f-73ee2d3497cb', 'Anidá listas dentro de li.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c4a1a726-699c-b4e1-4239-831949ab66ac', '70000000-0000-0000-0000-000000000005', 'La etiqueta <li> requiere cierre.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('6a38800d-4bf4-3da3-a84b-57663b2f2155', 'c4a1a726-699c-b4e1-4239-831949ab66ac', '<li>…</li> siempre lleva cierre.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('fc4c236c-2542-6a62-1285-ed90f0ad4c8d', 'c4a1a726-699c-b4e1-4239-831949ab66ac', 'Es auto-cerrada.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4a09df24-bf46-20ef-0bbf-8fd3320aa421', 'c4a1a726-699c-b4e1-4239-831949ab66ac', '6a38800d-4bf4-3da3-a84b-57663b2f2155', 'li requiere cierre.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c926c3de-0cfd-e1ff-fe28-700bfa75143c', '70000000-0000-0000-0000-000000000006', 'Un documento válido tiene DOCTYPE como primer elemento.', 'verdadero_falso', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('2055d2ab-ff64-5ee1-0210-2934baf9af45', 'c926c3de-0cfd-e1ff-fe28-700bfa75143c', 'DOCTYPE es el primer tag del archivo.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('ff6b0c64-52e8-64c3-b421-5f48afc84568', 'c926c3de-0cfd-e1ff-fe28-700bfa75143c', 'Es el <title>.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8b96ebca-cdc7-c9b9-6f7e-b9aeebbedcbe', 'c926c3de-0cfd-e1ff-fe28-700bfa75143c', '2055d2ab-ff64-5ee1-0210-2934baf9af45', '<!DOCTYPE html> debe ser el primer nodo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('62b98dca-c8e2-6b05-65db-f61dd8c9603d', '70000000-0000-0000-0000-000000000006', 'Una imagen sin alt pierde accesibilidad.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('c26bfbd2-e5dc-81ec-6e71-75934f31ebda', '62b98dca-c8e2-6b05-65db-f61dd8c9603d', 'src + alt cubrirían el caso completo.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('26f54548-eae1-5efb-1759-19447fb83646', '62b98dca-c8e2-6b05-65db-f61dd8c9603d', 'alt siempre soporta.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('75e3b898-df0e-74fb-99f1-6e7ac5e48398', '62b98dca-c8e2-6b05-65db-f61dd8c9603d', 'c26bfbd2-e5dc-81ec-6e71-75934f31ebda', 'alt obligatorio para accesibilidad.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('157f3aec-81d5-689e-1cb5-54e34154036f', '70000000-0000-0000-0000-000000000006', 'Ordenar un artículo simple: el orden correcto es:', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('ff7ec7cf-fdda-d94a-5a44-147185ff1795', '157f3aec-81d5-689e-1cb5-54e34154036f', '<p>Primero</p><p>Segundo</p>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('11566024-51bf-d48d-7732-63d8fe279f29', '157f3aec-81d5-689e-1cb5-54e34154036f', '</p><p>Texto</p>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('fa680a95-826b-0116-04b5-643772aa3f6c', '157f3aec-81d5-689e-1cb5-54e34154036f', '<p>Texto</p></p>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('57cb2ff0-69ff-c5d2-f36d-3e72932c3142', '157f3aec-81d5-689e-1cb5-54e34154036f', 'ff7ec7cf-fdda-d94a-5a44-147185ff1795', 'Abrir, contenido, cerrar correctamente.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ad0be3a2-5e45-3f45-a83c-31aeed686d53', '70000000-0000-0000-0000-000000000006', '¿Qué etiqueta envuelve al cuerpo?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('8e45f0cb-ee0e-1ef3-50c1-e6e92d9888ae', 'ad0be3a2-5e45-3f45-a83c-31aeed686d53', '<body>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('0f87eb86-b5ba-b739-0f1e-9488ce36fc20', 'ad0be3a2-5e45-3f45-a83c-31aeed686d53', '<html>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c1b625cf-8ee7-6c5f-8eec-50e301a8046c', 'ad0be3a2-5e45-3f45-a83c-31aeed686d53', '<head>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4dedb879-8415-d4c6-ccd3-7e726613603c', 'ad0be3a2-5e45-3f45-a83c-31aeed686d53', '8e45f0cb-ee0e-1ef3-50c1-e6e92d9888ae', 'body envuelve todo lo visible.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('6ff424bd-b33f-108b-3dad-135aedb4d3fb', '70000000-0000-0000-0000-000000000006', 'Las listas HTML usan <ul>/<ol> + <li>.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('f9b0eb2b-685c-6a9c-7b4e-fa309b2a867f', '6ff424bd-b33f-108b-3dad-135aedb4d3fb', '<ul> y <ol> son contenedores; <li> los ítems.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('abd449f2-0af3-96ca-d90b-49e06461d642', '6ff424bd-b33f-108b-3dad-135aedb4d3fb', 'Li es contenedor.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('1dea0c33-1a0e-64d2-e1d0-a868d4f91b28', '6ff424bd-b33f-108b-3dad-135aedb4d3fb', 'f9b0eb2b-685c-6a9c-7b4e-fa309b2a867f', 'ul/ol vs li.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('da90f039-d557-5db3-1093-503374906a1e', '70000000-0000-0000-0000-000000000007', '¿Qué es una etiqueta block?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('bbbf46f0-8b64-a9a1-9d68-6e710a864666', 'da90f039-d557-5db3-1093-503374906a1e', 'Una etiqueta que ocupa todo el ancho disponible.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('337f38e6-130b-7f93-1048-3535aba06830', 'da90f039-d557-5db3-1093-503374906a1e', 'Una etiqueta inline.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('9ee9f06c-8b4e-dd28-4a2c-2d5c0c8b88c0', 'da90f039-d557-5db3-1093-503374906a1e', 'Un input.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('3ad2cce3-87d1-fb3c-48a8-cf3e28c42990', 'da90f039-d557-5db3-1093-503374906a1e', 'bbbf46f0-8b64-a9a1-9d68-6e710a864666', 'Los block elements rompen la línea y ocupan todo el ancho.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('af8afd2d-a35a-427f-6035-70ce3d868f6a', '70000000-0000-0000-0000-000000000007', '<div> es un contenedor genérico.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('c6181a03-a116-f898-c599-40b6a97bdbc8', 'af8afd2d-a35a-427f-6035-70ce3d868f6a', 'div = division, contenedor sin significado.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('40769112-eb4c-04a1-3083-293ef688fd66', 'af8afd2d-a35a-427f-6035-70ce3d868f6a', 'div es semántico.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e38a06a0-77be-e82e-41d2-d94144cf5e14', 'af8afd2d-a35a-427f-6035-70ce3d868f6a', 'c6181a03-a116-f898-c599-40b6a97bdbc8', 'div es no-semántico; preferí section/article cuando aplique.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('627b6d21-2234-c851-bdf0-35df19e56bb5', '70000000-0000-0000-0000-000000000007', '¿Qué contiene semánticamente un artículo?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('100e863e-b256-ab54-d7eb-a6f073abd32a', '627b6d21-2234-c851-bdf0-35df19e56bb5', 'Contenido independiente que puede extraerse.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('95cc41b6-9d8b-b214-07be-b1d6e2cdce73', '627b6d21-2234-c851-bdf0-35df19e56bb5', 'El pie de página.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('aa96c093-6753-a884-60b3-a67bda9dc636', '627b6d21-2234-c851-bdf0-35df19e56bb5', 'La navegación.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('05896cea-54ef-fe58-22fa-2296cee90968', '627b6d21-2234-c851-bdf0-35df19e56bb5', '100e863e-b256-ab54-d7eb-a6f073abd32a', 'article es contenido autónomo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('7dec3778-5f80-35de-4178-a15217bf0eed', '70000000-0000-0000-0000-000000000007', '¿Qué etiqueta contiene una cabecera principal?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('82a1c5d5-b878-7101-69f6-69c4bf8145eb', '7dec3778-5f80-35de-4178-a15217bf0eed', '<header>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4e2c98b1-7c61-8b4d-5afd-bd60df5dd847', '7dec3778-5f80-35de-4178-a15217bf0eed', '<footer>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('91cbf9cf-10b2-ba14-ff69-8891d69deab2', '7dec3778-5f80-35de-4178-a15217bf0eed', '<main>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('9c7f988b-92a1-514c-f2d2-4c04faba93fa', '7dec3778-5f80-35de-4178-a15217bf0eed', '82a1c5d5-b878-7101-69f6-69c4bf8145eb', 'header = encabezado de página o de sección.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('3de7158d-47ff-db69-be35-e8ee9b937fef', '70000000-0000-0000-0000-000000000007', 'Una etiqueta <section> distingue por tema, no por contenido.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('78bc0779-63f9-e94d-34a5-f1c75d2a9d3c', '3de7158d-47ff-db69-be35-e8ee9b937fef', 'section agrupa contenidos temáticos.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c716c330-e968-68b5-a803-8efb5f0e2f8a', '3de7158d-47ff-db69-be35-e8ee9b937fef', 'Es similar a div.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('32df7ff2-004e-7882-9dc6-2667451f5096', '3de7158d-47ff-db69-be35-e8ee9b937fef', '78bc0779-63f9-e94d-34a5-f1c75d2a9d3c', 'section es una agrupación temática.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('bf0c76d2-b16a-02cd-3f1b-df14de28a536', '70000000-0000-0000-0000-000000000008', '¿Qué etiqueta envuelve el contenido principal?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('3146e06f-7681-8770-850e-c9f55b8c27b6', 'bf0c76d2-b16a-02cd-3f1b-df14de28a536', '<main>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('7d7a57af-e0a1-718f-f85d-ec2a5b3845ca', 'bf0c76d2-b16a-02cd-3f1b-df14de28a536', '<body>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('08db9c6c-df2f-3d72-e80b-563149451a39', 'bf0c76d2-b16a-02cd-3f1b-df14de28a536', '<content>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('7d8444be-991c-92b2-8371-2bda0adaf789', 'bf0c76d2-b16a-02cd-3f1b-df14de28a536', '3146e06f-7681-8770-850e-c9f55b8c27b6', 'main es único por página.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('a998a860-587e-5c24-b06e-d85a6cfdfdfa', '70000000-0000-0000-0000-000000000008', '¿Qué va en <footer>?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('9091fcbc-675b-c65f-8e03-201daf916479', 'a998a860-587e-5c24-b06e-d85a6cfdfdfa', 'Fin de página: autor, copyright, enlaces legales.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e933f29c-b580-fbc1-6cf2-e841d707b06a', 'a998a860-587e-5c24-b06e-d85a6cfdfdfa', 'La barra de navegación.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('10f3f78b-af91-c5be-5316-1e4d51a84275', 'a998a860-587e-5c24-b06e-d85a6cfdfdfa', 'El título principal.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('bae7cd47-c850-e9d6-7cc3-7c12e6666b36', 'a998a860-587e-5c24-b06e-d85a6cfdfdfa', '9091fcbc-675b-c65f-8e03-201daf916479', 'footer es el cierre del documento o de una sección.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('250e960c-482c-ac63-e5e9-4ecc0ef4de3f', '70000000-0000-0000-0000-000000000008', '¿Qué etiqueta envuelve la navegación principal?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('02ac9903-6152-68cb-6e9c-0b6e0519e558', '250e960c-482c-ac63-e5e9-4ecc0ef4de3f', '<nav>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('65a1876d-13bc-2bc0-d3ae-f278b3e9c417', '250e960c-482c-ac63-e5e9-4ecc0ef4de3f', '<menu>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a1c1e4d1-c0c8-f705-2992-99e32b917ab5', '250e960c-482c-ac63-e5e9-4ecc0ef4de3f', '<links>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('b19984f1-b0c3-55ec-5f75-4d330d9a4b2e', '250e960c-482c-ac63-e5e9-4ecc0ef4de3f', '02ac9903-6152-68cb-6e9c-0b6e0519e558', 'nav = navigator.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('89cc6fe6-7c8e-bdad-98e1-6ff02ad935e5', '70000000-0000-0000-0000-000000000008', '¿Qué debería contener <header>?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('96a8f8ac-b71a-541e-57e4-2b5460194709', '89cc6fe6-7c8e-bdad-98e1-6ff02ad935e5', 'Logo, título y navegación del sitio.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('0be85486-b46e-7802-3e52-5b7c5b9a9216', '89cc6fe6-7c8e-bdad-98e1-6ff02ad935e5', 'El contenido más largo.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('45a29f78-21cc-b2cf-5599-54b85524a1b1', '89cc6fe6-7c8e-bdad-98e1-6ff02ad935e5', 'Sólo imágenes.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('f596ca74-39ac-4b16-755c-e03fd5d058c9', '89cc6fe6-7c8e-bdad-98e1-6ff02ad935e5', '96a8f8ac-b71a-541e-57e4-2b5460194709', 'header = encabezado del sitio o sección.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('2a522e64-3a50-e1b7-9dc4-38348bcaaae7', '70000000-0000-0000-0000-000000000009', '¿Qué hace <article>?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('21ff429b-be3b-5695-208d-be1e0a1e2a6b', '2a522e64-3a50-e1b7-9dc4-38348bcaaae7', 'Contenido independiente y auto-contenido.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('599e69c9-7261-5ed5-9b92-c073f254da7e', '2a522e64-3a50-e1b7-9dc4-38348bcaaae7', 'Agrupa párrafos juntos.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c75fe5f4-8753-b84e-90ff-28cb1d63c0f3', '2a522e64-3a50-e1b7-9dc4-38348bcaaae7', 'Es un contenedor genérico.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('e6aa6abc-a60f-d77e-2337-506002b1c73d', '2a522e64-3a50-e1b7-9dc4-38348bcaaae7', '21ff429b-be3b-5695-208d-be1e0a1e2a6b', 'article = contenido que se puede extraer y entender solo.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('db79a69c-7999-8233-e0bd-cff88e37fc50', '70000000-0000-0000-0000-000000000009', '¿Qué hace <section>?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('b5d95c0a-c27c-8466-a2b6-4eb101b4648d', 'db79a69c-7999-8233-e0bd-cff88e37fc50', 'Agrupa contenido relacionado temáticamente.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('962eff7a-a806-90a5-ec94-348255ea7dea', 'db79a69c-7999-8233-e0bd-cff88e37fc50', 'Es el container principal.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('33d2ae4f-c601-7b8f-bbbb-9e9ca50661dc', 'db79a69c-7999-8233-e0bd-cff88e37fc50', 'Es una etiqueta vacía.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('26b6cc73-9ebb-b6c3-0eb2-a49f9e71ceea', 'db79a69c-7999-8233-e0bd-cff88e37fc50', 'b5d95c0a-c27c-8466-a2b6-4eb101b4648d', 'section agrupa información relacionada.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('1ac005b1-a1bd-ee2c-54fb-28d96a313d3b', '70000000-0000-0000-0000-000000000009', 'article necesita siempre encabezado h2/h3.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('67647b46-148f-540b-307b-856025ac7db0', '1ac005b1-a1bd-ee2c-54fb-28d96a313d3b', 'Buenas prácticas: article comienza con encabezado.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c3c27613-1157-3394-55a1-cab82f51b432', '1ac005b1-a1bd-ee2c-54fb-28d96a313d3b', 'No.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0eb261c4-bddd-382e-a593-acc51887310e', '1ac005b1-a1bd-ee2c-54fb-28d96a313d3b', '67647b46-148f-540b-307b-856025ac7db0', 'article con encabezado es un patrón accesible.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('75470228-dc93-0807-3d25-ecfdaf2e74e7', '70000000-0000-0000-0000-000000000009', '¿Qué etiqueta tiene significado semántico?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('dee167cb-be78-a1a3-a744-99b816c70cf4', '75470228-dc93-0807-3d25-ecfdaf2e74e7', '<aside>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('542b721f-fe85-f7ed-df48-bca43b357ce2', '75470228-dc93-0807-3d25-ecfdaf2e74e7', '<div>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('300bff8c-75cd-a311-3b9c-31f83bd48d6c', '75470228-dc93-0807-3d25-ecfdaf2e74e7', '<span>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('77177e84-f63d-e931-1d46-f08d9b545190', '75470228-dc93-0807-3d25-ecfdaf2e74e7', 'dee167cb-be78-a1a3-a744-99b816c70cf4', 'aside = contenido complementario.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('576c452c-98e9-cc5e-2c0c-e85b2a64aff0', '70000000-0000-0000-0000-00000000000a', 'El elemento <br> crea:', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('ecae6198-ba90-5a8e-e5be-4dd8996ff5c6', '576c452c-98e9-cc5e-2c0c-e85b2a64aff0', 'Un salto de línea.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('44d8de80-ecb0-0a7a-9b7f-a8ce0ce70fad', '576c452c-98e9-cc5e-2c0c-e85b2a64aff0', 'Una línea horizontal.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('97e3d4c9-49c5-196b-c45d-265115fb8dd7', '576c452c-98e9-cc5e-2c0c-e85b2a64aff0', 'Un párrafo.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('b6c8d2cb-63c1-7c10-df35-2c88577d7f6f', '576c452c-98e9-cc5e-2c0c-e85b2a64aff0', 'ecae6198-ba90-5a8e-e5be-4dd8996ff5c6', 'br = line break.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('8200190d-1dc5-c85a-1d17-3379695087b5', '70000000-0000-0000-0000-00000000000a', 'El elemento <hr> crea:', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('65ee07de-f01c-3f7d-6349-046069db2681', '8200190d-1dc5-c85a-1d17-3379695087b5', 'Una línea horizontal.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d0a9288a-b275-2d94-60bc-aff0a640c1a1', '8200190d-1dc5-c85a-1d17-3379695087b5', 'Un salto de línea.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8edacce2-5594-df05-8743-a056254b3870', '8200190d-1dc5-c85a-1d17-3379695087b5', 'Un separador visual sin significado.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('26ee7164-f030-520f-269a-b01a7d6e74dc', '8200190d-1dc5-c85a-1d17-3379695087b5', '65ee07de-f01c-3f7d-6349-046069db2681', 'hr = horizontal rule.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ac21d93e-261a-cca0-563c-a1af1481579d', '70000000-0000-0000-0000-00000000000a', 'Un bloque con <hr> indica separación temática.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('75fb751b-c0ad-8cc1-1061-c759ea5ebf02', 'ac21d93e-261a-cca0-563c-a1af1481579d', 'hr marca cambio de tema o escena.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('de9296b2-23e4-6824-4fb6-d08b52f0a763', 'ac21d93e-261a-cca0-563c-a1af1481579d', 'Es sólo estético.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('d78a9bb2-1529-8814-90f4-7f84303d867d', 'ac21d93e-261a-cca0-563c-a1af1481579d', '75fb751b-c0ad-8cc1-1061-c759ea5ebf02', 'hr es semántica: cambio de sección temática.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('9cac7bda-4f63-f0c5-2c05-a044b16e35ca', '70000000-0000-0000-0000-00000000000a', '¿Qué debería contener una página bien estructurada?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('49f33a16-0e05-d923-a716-15ea1817198e', '9cac7bda-4f63-f0c5-2c05-a044b16e35ca', 'header, main y footer con contenido relacionado.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('dda2f963-9788-0f49-6a0e-1515d143e884', '9cac7bda-4f63-f0c5-2c05-a044b16e35ca', 'Sólo body.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('c42001d1-a053-2dac-fdea-b8809907d3c9', '9cac7bda-4f63-f0c5-2c05-a044b16e35ca', 'Sólo divs.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('8508e18d-549f-b469-e935-96b04347c4b0', '9cac7bda-4f63-f0c5-2c05-a044b16e35ca', '49f33a16-0e05-d923-a716-15ea1817198e', 'Estructura típica y semántica: header+main+footer.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('cff552af-6066-80d5-dc6d-dafc7867fdbf', '70000000-0000-0000-0000-00000000000a', 'HTML semántico mejora la accesibilidad y el SEO.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('33fa3685-c82f-6778-b1bc-3de27fc79724', 'cff552af-6066-80d5-dc6d-dafc7867fdbf', 'nav, header, main, footer, article mejoran lectura.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e64c6c45-4391-f1b7-bdcb-8ace176e6bed', 'cff552af-6066-80d5-dc6d-dafc7867fdbf', 'Es indiferente.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('eeaf208d-8c03-35f7-1c01-74e0a20c60bd', 'cff552af-6066-80d5-dc6d-dafc7867fdbf', '33fa3685-c82f-6778-b1bc-3de27fc79724', 'Semántica beneficia a lectores y buscadores.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ed112d67-3e7c-2ec6-ecee-76dd29d1d0a1', '70000000-0000-0000-0000-00000000000b', '¿Por qué usar <label>?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('8c79b076-0424-3109-cc5c-3a446db27823', 'ed112d67-3e7c-2ec6-ecee-76dd29d1d0a1', 'El clic en el label enfoca el campo; mejora accesibilidad.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a907ffcb-8cac-1182-97aa-ec9e1b604aac', 'ed112d67-3e7c-2ec6-ecee-76dd29d1d0a1', 'Es sólo estético.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('d72d8ed1-4bf4-9f94-4b73-e0971e526578', 'ed112d67-3e7c-2ec6-ecee-76dd29d1d0a1', 'No tiene ventajas.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6e048d7c-cb7c-32f4-a583-d946b6629257', 'ed112d67-3e7c-2ec6-ecee-76dd29d1d0a1', '8c79b076-0424-3109-cc5c-3a446db27823', 'label mejora la usabilidad y la accesibilidad.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('ffebffda-12ee-2d43-0e75-7d16a42efb55', '70000000-0000-0000-0000-00000000000b', '¿Qué atributo vincula label con input?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('0444b101-5a9f-550d-8dda-8ca7bd9dc1db', 'ffebffda-12ee-2d43-0e75-7d16a42efb55', 'for', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a684b175-1684-8251-fbe5-b0777b23f7b9', 'ffebffda-12ee-2d43-0e75-7d16a42efb55', 'id', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('4a785687-9ccd-cf60-c1ff-6a2ee878ae68', 'ffebffda-12ee-2d43-0e75-7d16a42efb55', 'to', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('35580d08-d99c-ae06-1381-e95f711feee2', 'ffebffda-12ee-2d43-0e75-7d16a42efb55', '0444b101-5a9f-550d-8dda-8ca7bd9dc1db', 'for + id: label for → input id.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('3cc730b1-0105-1daa-08da-987cb04753f9', '70000000-0000-0000-0000-00000000000b', 'El texto del label debe explicar el campo.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('9ccf61bb-6291-5830-15c0-ff1add2ba680', '3cc730b1-0105-1daa-08da-987cb04753f9', '"Nombre" para el campo nombre completo.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('a4f901fe-f0e4-fb1d-b68d-5e2b5f79404c', '3cc730b1-0105-1daa-08da-987cb04753f9', 'No importa el texto.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('99249eea-bb7f-9ff8-16f8-6256987074fc', '3cc730b1-0105-1daa-08da-987cb04753f9', '9ccf61bb-6291-5830-15c0-ff1add2ba680', 'Los labels deben ser claros y descriptivos.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('f22c5a46-cfdd-e86a-a1cf-f8b15db623a4', '70000000-0000-0000-0000-00000000000b', 'Un sitio accesible usa <label> en sus formularios.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('707509ad-7c6d-a93d-dc80-41590ecafaf3', 'f22c5a46-cfdd-e86a-a1cf-f8b15db623a4', 'Screen readers dependen de label.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f5aa7f33-893d-a7ee-efab-29325396ce55', 'f22c5a46-cfdd-e86a-a1cf-f8b15db623a4', 'No importa.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('b8191be6-1617-f422-ae46-675082faf8e6', 'f22c5a46-cfdd-e86a-a1cf-f8b15db623a4', '707509ad-7c6d-a93d-dc80-41590ecafaf3', 'Los lectores de pantalla anuncian label al enfocar.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('24b0f7dc-873c-a24a-aa3a-8cc6522ecc90', '70000000-0000-0000-0000-00000000000c', '¿Qué tipo de input crea un botón de envío?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7a325f88-ddff-ad92-ce14-e521d3dd90a1', '24b0f7dc-873c-a24a-aa3a-8cc6522ecc90', 'submit', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f1d112b8-b67a-77d5-1601-79b74602087c', '24b0f7dc-873c-a24a-aa3a-8cc6522ecc90', 'button', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('30260c12-7aed-cd14-5638-ad5e0da0412d', '24b0f7dc-873c-a24a-aa3a-8cc6522ecc90', 'send', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('432f4b36-9aa2-a63a-ed06-f0aa084a8346', '24b0f7dc-873c-a24a-aa3a-8cc6522ecc90', '7a325f88-ddff-ad92-ce14-e521d3dd90a1', '<input type="submit"> envía el formulario.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('f1280402-099e-2f86-3207-39c5a705c0f3', '70000000-0000-0000-0000-00000000000c', '¿Qué tipo de input crea un campo numérico?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('570a8def-6e51-0efd-cfe2-c7c62df573bd', 'f1280402-099e-2f86-3207-39c5a705c0f3', 'number', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('21ee3b60-2e1c-b7c6-3266-cc8b99800ee7', 'f1280402-099e-2f86-3207-39c5a705c0f3', 'text', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('8c28cd07-49bf-d2f1-683f-ea659c19d6ce', 'f1280402-099e-2f86-3207-39c5a705c0f3', 'int', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4c982dcd-5ee2-665f-54b3-f7ae3df81496', 'f1280402-099e-2f86-3207-39c5a705c0f3', '570a8def-6e51-0efd-cfe2-c7c62df573bd', '<input type="number">.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('17e7e78d-54c6-f2f8-db6a-79e2ad23ea0a', '70000000-0000-0000-0000-00000000000c', '¿Qué tipo de input crea un checkbox?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('71c06a8a-2db2-3815-daaf-09c34061ec26', '17e7e78d-54c6-f2f8-db6a-79e2ad23ea0a', 'checkbox', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1bec2c3e-f669-651e-bfd3-cb8365af1700', '17e7e78d-54c6-f2f8-db6a-79e2ad23ea0a', 'check', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('9e380b5e-5964-89f0-dbff-24cc5452383e', '17e7e78d-54c6-f2f8-db6a-79e2ad23ea0a', 'bool', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('6feec9a9-a480-8414-8812-50bc514b30f9', '17e7e78d-54c6-f2f8-db6a-79e2ad23ea0a', '71c06a8a-2db2-3815-daaf-09c34061ec26', '<input type="checkbox">.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('7ac02cf3-bcfb-bd43-e732-545b7a148c82', '70000000-0000-0000-0000-00000000000c', 'Los radio buttons se agrupan con el mismo atributo name.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('36a30783-7cce-4a96-afc1-26db4cf902b8', '7ac02cf3-bcfb-bd43-e732-545b7a148c82', 'Mismo name → selección única.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e22b30f3-c493-bbf0-5677-b81d91e4938d', '7ac02cf3-bcfb-bd43-e732-545b7a148c82', 'Necesitan id distinto.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4c6c128b-055f-af06-2034-f2abdc0294df', '7ac02cf3-bcfb-bd43-e732-545b7a148c82', '36a30783-7cce-4a96-afc1-26db4cf902b8', 'Agrupá radio buttons con name compartido.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('01e6b56d-280e-1519-fe21-e459626e68c6', '70000000-0000-0000-0000-00000000000d', 'Un formulario puede tener varios tipos de input.', 'verdadero_falso', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('9bb0e2f3-3585-ab98-6954-955193402edb', '01e6b56d-280e-1519-fe21-e459626e68c6', 'Text, email, number, checkbox, radio…', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('10306211-7856-f59d-2fb7-d03a7a539d77', '01e6b56d-280e-1519-fe21-e459626e68c6', 'Sólo uno por formulario.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('4ddfde25-b7b6-7b32-ca2b-fff9a2e349c4', '01e6b56d-280e-1519-fe21-e459626e68c6', '9bb0e2f3-3585-ab98-6954-955193402edb', 'Los formularios combinan campos de tipos diferentes.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('e32954cc-55cf-7ee6-141d-9adfe2b9476e', '70000000-0000-0000-0000-00000000000d', 'El atributo name es el identificador del campo.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('64ad9e2b-42c6-3b27-541a-961a3bba9f08', 'e32954cc-55cf-7ee6-141d-9adfe2b9476e', 'name es la clave que recibe el servidor.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f46d0c3a-e918-2248-032d-b25f8741bf91', 'e32954cc-55cf-7ee6-141d-9adfe2b9476e', 'id es lo mismo.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('83f39e45-623f-1a8a-da39-e56b4a9e4c24', 'e32954cc-55cf-7ee6-141d-9adfe2b9476e', '64ad9e2b-42c6-3b27-541a-961a3bba9f08', 'name es lo que viaja al servidor.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('b6a13e4d-af28-a5d1-67c5-94903959ae4b', '70000000-0000-0000-0000-00000000000d', 'Ordenar un formulario válido: el orden correcto es:', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7d2e765c-8ba4-2d56-a5f0-c5814d351804', 'b6a13e4d-af28-a5d1-67c5-94903959ae4b', '<form><label>…</label><input></form>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('e801150b-26fa-24fe-e250-3383396d6cb2', 'b6a13e4d-af28-a5d1-67c5-94903959ae4b', '</form><form><input>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('5908c372-9df2-54ee-f4df-6430bd252047', 'b6a13e4d-af28-a5d1-67c5-94903959ae4b', '<input></input>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('d3c4f777-659f-5d71-0ead-41909190af18', 'b6a13e4d-af28-a5d1-67c5-94903959ae4b', '7d2e765c-8ba4-2d56-a5f0-c5814d351804', 'Form, label, input, cierre.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('5a069a36-0d3f-2d18-031e-a73732b24930', '70000000-0000-0000-0000-00000000000d', 'Los formularios son la puerta de entrada de datos.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('41c5093d-3ead-6768-22ba-911aebfe76d1', '5a069a36-0d3f-2d18-031e-a73732b24930', 'Cada dato viaja con su name asociado.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('9659bec9-5587-7b8a-bfb6-ef316a67dd19', '5a069a36-0d3f-2d18-031e-a73732b24930', 'Los formularios no recopilan datos.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('65a2ba73-4889-e315-9b24-d936c77b50c3', '5a069a36-0d3f-2d18-031e-a73732b24930', '41c5093d-3ead-6768-22ba-911aebfe76d1', 'name es esencial para recibir datos.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('e4e88af1-182d-7eca-5780-69b92bcd5b6d', '70000000-0000-0000-0000-00000000000d', 'El type del input determina el control visual.', 'verdadero_falso', 5, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('572129d8-76c9-6f34-0d07-ee2801848b2b', 'e4e88af1-182d-7eca-5780-69b92bcd5b6d', 'Text, email, number, checkbox, radio…', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('ee491543-cb28-3d45-a7cb-62b3854dd5b1', 'e4e88af1-182d-7eca-5780-69b92bcd5b6d', 'Siempre luce igual.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('0c727786-a2d2-93c9-d0dd-61441274cb8c', 'e4e88af1-182d-7eca-5780-69b92bcd5b6d', '572129d8-76c9-6f34-0d07-ee2801848b2b', 'El type produce controles diferentes.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('cf9d89d7-6bda-26c3-cd7e-5da6174eecdd', '70000000-0000-0000-0000-00000000000e', '¿Qué etiqueta incrusta audio?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('ac1c3c32-6107-a7d6-7e14-8e4e759350af', 'cf9d89d7-6bda-26c3-cd7e-5da6174eecdd', '<audio>', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('1451bdde-4493-a87d-f935-357340b6f33c', 'cf9d89d7-6bda-26c3-cd7e-5da6174eecdd', '<sound>', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('bbeb4661-62c5-4c5a-cbab-c7cf6d6a2fce', 'cf9d89d7-6bda-26c3-cd7e-5da6174eecdd', '<music>', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('44113ea3-64eb-757c-e8f5-a95cdf742a86', 'cf9d89d7-6bda-26c3-cd7e-5da6174eecdd', 'ac1c3c32-6107-a7d6-7e14-8e4e759350af', 'audio = sonido.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('c2fc8473-b826-659b-273b-5d9c67491b12', '70000000-0000-0000-0000-00000000000e', '¿Qué atributo muestra los controles?', 'seleccion', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7d1f87bf-dfe1-bab8-af06-ba39580e677f', 'c2fc8473-b826-659b-273b-5d9c67491b12', 'controls', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f224230b-fef4-9e28-abeb-a754aa9ca927', 'c2fc8473-b826-659b-273b-5d9c67491b12', 'panel', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('68dbba3b-129a-2161-9b27-f32f20bdaf75', 'c2fc8473-b826-659b-273b-5d9c67491b12', 'buttons', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('290f420d-a04c-4c8a-7c5e-3f1ccc02c945', 'c2fc8473-b826-659b-273b-5d9c67491b12', '7d1f87bf-dfe1-bab8-af06-ba39580e677f', 'controls activa UI de play/pausa y volumen.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('d6c0dbad-a1ef-43c9-44df-eec89707e696', '70000000-0000-0000-0000-00000000000e', '¿Qué atributo indica el archivo?', 'seleccion', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('fb4d808e-3bb5-bde4-5ee8-0225a14ab27f', 'd6c0dbad-a1ef-43c9-44df-eec89707e696', 'src', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('fb168729-072e-1ad9-d489-0ec69c732ea2', 'd6c0dbad-a1ef-43c9-44df-eec89707e696', 'href', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('fd363dc9-aff3-9ec0-a1c6-ce1dc3cf7903', 'd6c0dbad-a1ef-43c9-44df-eec89707e696', 'file', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('1597d9f7-67bf-3187-0eb3-65dfcd0f1188', 'd6c0dbad-a1ef-43c9-44df-eec89707e696', 'fb4d808e-3bb5-bde4-5ee8-0225a14ab27f', 'src = origen.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('b071be2a-2258-d577-3231-b3c462caad8b', '70000000-0000-0000-0000-00000000000e', 'Declarar <audio> sin controls lo hace invisible.', 'verdadero_falso', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('7146cbdb-3a19-ddd7-b6a3-4269e546e356', 'b071be2a-2258-d577-3231-b3c462caad8b', 'Sin controls no hay UI reproducible.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('f7a23d89-6e35-ad1c-2b27-0aa24e27153d', 'b071be2a-2258-d577-3231-b3c462caad8b', 'Siempre se ven controles.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('197e7048-da91-3691-7b82-b115dbc38039', 'b071be2a-2258-d577-3231-b3c462caad8b', '7146cbdb-3a19-ddd7-b6a3-4269e546e356', 'controls muestra la interfaz de reproducción.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('95468557-eedc-67e6-a6f9-73c5cbe52c50', '70000000-0000-0000-0000-00000000000f', '¿Qué es aria-label?', 'seleccion', 1, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('40dbadd3-3bad-e316-3a29-c93955e02e78', '95468557-eedc-67e6-a6f9-73c5cbe52c50', 'Atributo ARIA que describe el propósito a lectores de pantalla.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('50ea4c33-2847-272b-8894-6aa1c07ea125', '95468557-eedc-67e6-a6f9-73c5cbe52c50', 'Una etiqueta visual oculta.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('47decc21-5bf8-ca6e-0043-b5457c866f61', '95468557-eedc-67e6-a6f9-73c5cbe52c50', 'Nada.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('fc65a44a-c385-4d6e-ed8e-8d98689b110f', '95468557-eedc-67e6-a6f9-73c5cbe52c50', '40dbadd3-3bad-e316-3a29-c93955e02e78', 'ARIA = Accessible Rich Internet Applications.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('154965c4-8d8d-f21a-4237-c7b0bf55e24c', '70000000-0000-0000-0000-00000000000f', 'El alt de una imagen informativa debe describirla.', 'verdadero_falso', 2, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('6369010a-083a-d806-fd93-945c824d1d5e', '154965c4-8d8d-f21a-4237-c7b0bf55e24c', '"Foto del campus" es correcto; "" para imágenes decorativas.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('88d7e03e-1388-49c9-f84b-ace885bd010d', '154965c4-8d8d-f21a-4237-c7b0bf55e24c', 'alt = texto alternativo obligatorio en todas.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('cb8beb52-f6e8-0b50-a1aa-0e663ae864c5', '154965c4-8d8d-f21a-4237-c7b0bf55e24c', '6369010a-083a-d806-fd93-945c824d1d5e', 'Decorativa: alt=""; informativa: alt="descripción".') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('4d1bdfa2-603d-8650-ae53-c5eebfad3f6a', '70000000-0000-0000-0000-00000000000f', 'Un HTML accesible usa h1-h6 en orden de jerarquía.', 'verdadero_falso', 3, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('db501a69-ad5b-887c-3eef-b4a29e27545c', '4d1bdfa2-603d-8650-ae53-c5eebfad3f6a', 'h1 > h2 > h3 …', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('44c49503-c395-1fbc-25e4-43017bf58663', '4d1bdfa2-603d-8650-ae53-c5eebfad3f6a', 'Se elige aleatorio.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('7aef709f-177e-da42-c804-7aca5edfe363', '4d1bdfa2-603d-8650-ae53-c5eebfad3f6a', 'db501a69-ad5b-887c-3eef-b4a29e27545c', 'La jerarquía facilita navegación asistida.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion) values ('56265271-0d56-add3-cf96-ace373a9b077', '70000000-0000-0000-0000-00000000000f', '¿Qué hace prefers-reduced-motion?', 'seleccion', 4, 'publicado') on conflict (id) do update set leccion_id = excluded.leccion_id, enunciado = excluded.enunciado, tipo = excluded.tipo, orden = excluded.orden, estado_publicacion = excluded.estado_publicacion;
insert into opciones (id, pregunta_id, texto, orden) values ('df2af16f-8368-9da9-5b6f-1d860cb2c4c9', '56265271-0d56-add3-cf96-ace373a9b077', 'Respetar que el usuario prefiere menos animación.', 1) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('28b33765-cb57-6970-ec66-a0d92e4baaff', '56265271-0d56-add3-cf96-ace373a9b077', 'Activar contraste alto.', 2) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into opciones (id, pregunta_id, texto, orden) values ('32dd39da-4953-2494-8760-572329ace96a', '56265271-0d56-add3-cf96-ace373a9b077', 'Nada.', 3) on conflict (id) do update set pregunta_id = excluded.pregunta_id, texto = excluded.texto, orden = excluded.orden;
insert into soluciones (id, pregunta_id, opcion_correcta_id, explicacion) values ('98dbf949-a367-0590-f65f-a0c02e02f19e', '56265271-0d56-add3-cf96-ace373a9b077', 'df2af16f-8368-9da9-5b6f-1d860cb2c4c9', 'Los usuarios con sensibilidad vestibular prefieren menos movimiento.') on conflict (pregunta_id) do update set opcion_correcta_id = excluded.opcion_correcta_id, explicacion = excluded.explicacion;
