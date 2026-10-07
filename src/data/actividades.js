export const activities = [
  {
    id: 'activity-variables-1',
    lessonId: 'lesson-variables-basicas',
    type: 'choice',
    statement:
      '¿Cuál de estas líneas declara correctamente una variable llamada edad con el valor 18?',
    options: ['let edad = 18;', 'let 18 = edad;', 'const edad;', 'edad = 18;'],
    answer: 0,
    explanation:
      'La sintaxis correcta es declarar la variable con let, poner el nombre y luego asignarle el valor con =.',
  },
  {
    id: 'activity-variables-2',
    lessonId: 'lesson-variables-basicas',
    type: 'fill',
    statement: 'Completa la sentencia para guardar el nombre de una persona:',
    code: 'let nombre = ___;',
    expected: ['"Ana"', "'Ana'"],
    explanation:
      'Los textos en JavaScript deben ir entre comillas. Por eso el valor correcto es "Ana" o \'Ana\'.',
  },
  {
    id: 'activity-variables-3',
    lessonId: 'lesson-variables-basicas',
    type: 'choice',
    statement: '¿Qué opción representa una asignación válida de una constante?',
    options: [
      'const apellido = "Pérez";',
      'const = "Pérez";',
      'let const = "Pérez";',
      'apellido = const;',
    ],
    answer: 0,
    explanation:
      'const se usa para declarar una constante, seguida del nombre y el valor. La sintaxis es const nombre = valor;',
  },
  {
    id: 'activity-operadores-1',
    lessonId: 'lesson-operadores-basicos',
    type: 'choice',
    statement: '¿Qué resultado devuelve 12 + 5?',
    options: ['17', '7', '60', '125'],
    answer: 0,
    explanation: 'La suma combina ambos valores numéricos y da 17.',
  },
  {
    id: 'activity-operadores-2',
    lessonId: 'lesson-operadores-basicos',
    type: 'fill',
    statement: 'Completa el operador que calcula el resto de la división:',
    code: 'let resto = 10 ___ 3;',
    expected: ['%'],
    explanation: 'El operador % devuelve el resto: 10 % 3 da 1.',
  },
  {
    id: 'activity-operadores-3',
    lessonId: 'lesson-operadores-basicos',
    type: 'choice',
    statement: '¿Cuál de estas expresiones calcula correctamente el total de 4 × 3?',
    options: ['4 * 3', '4 + 3', '4 / 3', '4 % 3'],
    answer: 0,
    explanation: 'La multiplicación usa el operador *. 4 * 3 equivale a 12.',
  },
]
