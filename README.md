# Kodigo

## Estructura del proyecto

```text
Kodigo/
├── src/
│   ├── components/     # Componentes reutilizables de Vue
│   ├── views/          # Pantallas principales de la aplicación
│   ├── data/           # Datos de cursos, unidades, lecciones y actividades
│   ├── services/       # Acceso y gestión de datos, preparado para una futura API
│   ├── router/         # Configuración de las rutas
│   └── assets/         # Estilos e imágenes
├── public/             # Recursos públicos
├── dist/               # Resultado de la compilación (build)
└── node_modules/       # Dependencias instaladas
```

## Descripción de carpetas

- `src/`: código principal de la aplicación.
- `src/components/`: componentes reutilizables de Vue (tarjetas, navegación, código, actividades, etc.).
- `src/views/`: pantallas principales (inicio, cursos, unidades, lecciones y actividades).
- `src/data/`: datos de cursos, unidades, lecciones y actividades.
- `src/services/`: acceso y gestión de datos, preparado para una futura API.
- `src/router/`: configuración de las rutas de la aplicación.
- `src/assets/`: estilos e imágenes (incluye las imágenes del fantasma de Kodigo).
- `public/`: recursos públicos servidos directamente.

## Archivos importantes fuera de las carpetas

- `index.html`: página de entrada de la aplicación.
- `vite.config.js`: configuración del proyecto.
- `package.json`: define el nombre del proyecto (`Kodigo`).