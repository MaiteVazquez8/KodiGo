export const lessons = [
  {
    id: 'lesson-variables-basicas',
    unitId: 1,
    title: 'Variables y asignación',
    kind: 'lesson',
    status: 'published',
    explanation:
      'Una variable guarda un valor para reutilizarlo después. En JavaScript usamos let para declarar una variable y luego le asignamos un valor.',
    exampleCode: `let nombre = "Ana";\nlet edad = 18;\nconsole.log(nombre);\nconsole.log(edad);`,
    activityIds: ['activity-variables-1', 'activity-variables-2', 'activity-variables-3'],
  },
  {
    id: 'lesson-operadores-basicos',
    unitId: 1,
    title: 'Operadores y cálculo',
    kind: 'lesson',
    status: 'published',
    explanation:
      'Los operadores permiten combinar valores y hacer cálculos. La suma, resta, multiplicación y división son las operaciones más comunes.',
    exampleCode: `let precio = 10;\nlet cantidad = 3;\nlet total = precio * cantidad;\nconsole.log(total);`,
    activityIds: ['activity-operadores-1', 'activity-operadores-2', 'activity-operadores-3'],
  },
]
