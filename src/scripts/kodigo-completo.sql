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
    updated_at timestamptz not null default now(),
    constraint progreso_usuario_leccion_unique unique (usuario_id, leccion_id),
    constraint progreso_intentos_check check (intentos >= 0),
    constraint progreso_porcentaje_check check (mejor_porcentaje >= 0 and mejor_porcentaje <= 100)
);

create table if not exists intentos (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references perfiles(id) on delete cascade,
    leccion_id uuid not null references lecciones(id) on delete cascade,
    cantidad_preguntas integer not null default 0,
    respuestas_correctas integer not null default 0,
    respuestas_incorrectas integer not null default 0,
    porcentaje numeric(5,2) not null default 0,
    completado boolean not null default false,
    aprobado boolean not null default false,
    created_at timestamptz not null default now(),
    constraint intentos_cantidad_check check (cantidad_preguntas >= 0),
    constraint intentos_correctas_check check (respuestas_correctas >= 0),
    constraint intentos_incorrectas_check check (respuestas_incorrectas >= 0),
    constraint intentos_porcentaje_check check (porcentaje >= 0 and porcentaje <= 100)
);

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

drop policy if exists "progreso propio inserta" on progreso_lecciones;
create policy "progreso propio inserta"
on progreso_lecciones
for insert
to authenticated
with check (usuario_id = auth.uid());

drop policy if exists "progreso propio modifica" on progreso_lecciones;
create policy "progreso propio modifica"
on progreso_lecciones
for update
to authenticated
using (usuario_id = auth.uid())
with check (usuario_id = auth.uid());

drop policy if exists "intentos propios visibles" on intentos;
create policy "intentos propios visibles"
on intentos
for select
to authenticated
using (usuario_id = auth.uid());

drop policy if exists "intentos propios inserta" on intentos;
create policy "intentos propios inserta"
on intentos
for insert
to authenticated
with check (usuario_id = auth.uid());

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

drop policy if exists "respuestas propias inserta" on respuestas_intento;
create policy "respuestas propias inserta"
on respuestas_intento
for insert
to authenticated
with check (
    exists (
        select 1
        from intentos
        where intentos.id = respuestas_intento.intento_id
        and intentos.usuario_id = auth.uid()
    )
);

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

revoke all on function comprobar_respuesta(uuid, uuid) from public;
grant execute on function comprobar_respuesta(uuid, uuid) to anon, authenticated;

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
