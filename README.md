# Kodigo

**Aprendé a programar de forma fácil, progresiva e interactiva.**

Kodigo es una aplicación educativa orientada al aprendizaje de programación mediante cursos, unidades, lecciones y actividades prácticas.

## Diseño

Las vistas y la identidad visual de la aplicación se encuentran diseñadas en Figma:

[Ver diseño en Figma](https://www.figma.com/design/4WN9X3SuPGuFneQs3UVFlU/Kodigo?node-id=0-1&t=DlAmQeh7k5mMFHh7-1&utm_source=chatgpt.com)

---

## Estructura del proyecto

```text
Kodigo/
├── src/
│   ├── components/     # Componentes reutilizables de Vue
│   ├── views/          # Pantallas principales de la aplicación
│   ├── data/           # Datos de cursos, unidades, lecciones y actividades
│   ├── services/       # Acceso y gestión de datos
│   ├── router/         # Configuración de las rutas
│   └── assets/         # Estilos e imágenes
├── public/             # Recursos públicos de la aplicación
├── index.html          # Página de entrada de la aplicación
├── package.json        # Configuración y dependencias del proyecto
├── vite.config.js      # Configuración de Vite
└── ...
```

## Descripción de carpetas

### `src/`

Contiene el código principal de la aplicación.

### `src/components/`

Contiene los componentes reutilizables de Vue. Por ejemplo, tarjetas de cursos y unidades, navegación, actividades, bloques de código y elementos de la identidad visual de Kodigo.

### `src/views/`

Contiene las pantallas principales de la aplicación, como:

* Inicio
* Cursos
* Curso
* Unidad
* Lección
* Actividad

### `src/data/`

Contiene las estructuras de datos utilizadas actualmente para representar:

* Cursos
* Unidades
* Lecciones
* Actividades

Los datos están separados de las vistas para facilitar su reutilización y mantenimiento.

### `src/services/`

Contiene la capa encargada del acceso y gestión de los datos. Su estructura permite reemplazar posteriormente los datos locales por información obtenida desde una API.

### `src/router/`

Contiene la configuración de **Vue Router** y las rutas que conectan las diferentes vistas de la aplicación.

### `src/assets/`

Contiene los recursos utilizados por la interfaz, principalmente:

* Estilos globales.
* Imágenes.
* Recursos de la identidad visual de Kodigo.
* Imágenes del fantasma en sus diferentes expresiones.

### `public/`

Contiene recursos públicos que se sirven directamente desde la aplicación, como el favicon de Kodigo.

---

## Archivos principales

* **`index.html`**: página de entrada de la aplicación.
* **`package.json`**: contiene la configuración del proyecto, scripts y dependencias.
* **`vite.config.js`**: configuración de Vite.
* **`capacitor.config.ts`**: configuración de Capacitor para la aplicación móvil.
