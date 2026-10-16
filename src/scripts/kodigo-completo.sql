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
    tipo varchar(30) not null default 'multiple_choice',
    orden integer not null default 0,
    estado_publicacion varchar(20) not null default 'borrador',
    created_at timestamptz not null default now(),
    constraint preguntas_tipo_check check (tipo = 'multiple_choice'),
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
    opcion_correcta_id uuid not null references opciones(id) on delete restrict,
    explicacion text not null,
    created_at timestamptz not null default now()
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
    opcion_id uuid not null references opciones(id) on delete restrict,
    correcta boolean not null,
    created_at timestamptz not null default now(),
    constraint respuestas_intento_pregunta_unique unique (intento_id, pregunta_id)
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

drop policy if exists "perfiles para ranking" on perfiles;
create policy "perfiles para ranking"
on perfiles
for select
to authenticated
using (true);

drop policy if exists "usuario modifica su perfil" on perfiles;
create policy "usuario modifica su perfil"
on perfiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

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

create function cantidad_preguntas_publicadas(p_leccion_id uuid)
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

create function es_leccion_publicada(p_leccion_id uuid)
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
          and estado_publicacion in ('publicado', 'bloqueada')
    );
$$;

create function recalcular_intento(p_intento_id uuid)
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
    aprobado := completado and v_correctas >= 2;

    return next;
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
declare
    v_usuario uuid := auth.uid();
    v_leccion uuid;
    v_estado varchar;
    v_correccion record;
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

    if not exists (
        select 1 from preguntas
        where id = p_pregunta_id
          and leccion_id = v_leccion
          and estado_publicacion = 'publicado'
    ) then
        raise exception 'La pregunta no pertenece a la leccion o no esta publicada';
    end if;

    if not exists (
        select 1 from respuestas_intento where intento_id = p_intento_id and pregunta_id = p_pregunta_id
    ) then
        select c.correcta, c.explicacion into v_correccion
        from comprobar_respuesta(p_pregunta_id, p_opcion_id) c;

        insert into respuestas_intento (intento_id, pregunta_id, opcion_id, correcta)
        values (p_intento_id, p_pregunta_id, p_opcion_id, v_correccion.correcta)
        on conflict (intento_id, pregunta_id) do nothing;
    else
        v_ya_registrada := true;
        select c.correcta, c.explicacion into v_correccion
        from respuestas_intento r
        join comprobar_respuesta(r.pregunta_id, r.opcion_id) c on true
        where r.intento_id = p_intento_id and r.pregunta_id = p_pregunta_id;
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
        update perfiles set experiencia = experiencia + v_xp, updated_at = now()
        where id = v_usuario;
        update intentos set xp_ganado = v_xp where id = p_intento_id;
    else
        select i.xp_ganado into v_xp from intentos i where i.id = p_intento_id;
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

insert into preguntas (id, leccion_id, enunciado, tipo, orden, estado_publicacion)
values
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '¿Cuál de estas líneas declara correctamente una variable llamada edad con el valor 18?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '¿Qué valor completa la sentencia para guardar el nombre de una persona?\nlet nombre = ___;',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    '¿Qué opción representa una asignación válida de una constante?',
    'multiple_choice',
    3,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000002',
    '¿Qué resultado devuelve 12 + 5?',
    'multiple_choice',
    1,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000002',
    '¿Qué operador completa la sentencia para calcular el resto de la división?\nlet resto = 10 ___ 3;',
    'multiple_choice',
    2,
    'publicado'
),
(
    '40000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000002',
    '¿Cuál de estas expresiones calcula correctamente el total de 4 × 3?',
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
    'const apellido = "Pérez";',
    1
),
(
    '50000000-0000-0000-0000-000000000010',
    '40000000-0000-0000-0000-000000000003',
    'const = "Pérez";',
    2
),
(
    '50000000-0000-0000-0000-000000000011',
    '40000000-0000-0000-0000-000000000003',
    'let const = "Pérez";',
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
    'La suma combina ambos valores numéricos y da 17.'
),
(
    '40000000-0000-0000-0000-000000000005',
    '50000000-0000-0000-0000-000000000017',
    'El operador % devuelve el resto de la división: 10 % 3 da 1.'
),
(
    '40000000-0000-0000-0000-000000000006',
    '50000000-0000-0000-0000-000000000021',
    'La multiplicación usa el operador *. 4 * 3 equivale a 12.'
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
