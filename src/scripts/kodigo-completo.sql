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
    -- Regla general de aprobacion: al menos 2/3 de las actividades correctas,
    -- con redondeo hacia arriba para no pedir nunca mas de lo justo:
    -- 3 -> 2, 4 -> 3, 5 -> 4, 6 -> 4, 7 -> 5.
    aprobado := completado and v_correctas >= ceiling(v_total::numeric * 2 / 3)::integer;

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
        'en_juego', 'finalizada', 'vencida', 'abandonada'
    )),
    constraint expotec_partidas_cerrada_check check (
        finalizado_at is null or estado in ('finalizada', 'vencida', 'abandonada')
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

    -- 8) Crea la partida con las reglas congeladas.
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
        estado, config_snapshot, iniciado_at, vencimiento_at
    )
    values (
        p_evento_id, v_desafio.id, v_participante, v_usuario,
        btrim(p_alias),
        'en_cuestionario',
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
        select *
        from expotec_resultados_publicos r
        where r.evento_id = p_evento_id
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
        p.id, p.alias, p.estado,
        p.respondidas, p.correctas, p.incorrectas,
        p.puntaje_cuestionario, p.puntaje_juego, p.puntaje_total,
        p.tiempo_cuestionario_seg, p.iniciado_at, p.finalizado_at
    from expotec_partidas p
    where p.evento_id = p_evento_id
      and (p_estado is null or p.estado = p_estado)
    order by p.iniciado_at desc
    limit least(coalesce(p_limite, 100), 500);
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
    'bloques'
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

-- ---------------------------------------------------------------------------
-- 6. Correccion de las once modalidades
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
