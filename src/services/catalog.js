import { courses } from '@/data/courses'
import { units } from '@/data/units'
import { lessons } from '@/data/lessons'
import { activities } from '@/data/activities'

export function getCourses() {
  return courses
}

export function getAvailableCourses() {
  return courses.filter((course) => course.status === 'available')
}

export function getCourse(courseId) {
  return courses.find((course) => course.id === courseId)
}

export function getUnitsForCourse(courseId) {
  return units.filter((unit) => unit.courseId === courseId).sort((a, b) => a.id - b.id)
}

export function getUnit(courseId, unitId) {
  return units.find((unit) => unit.courseId === courseId && unit.id === Number(unitId))
}

export function getUnitById(unitId) {
  return units.find((unit) => unit.id === Number(unitId))
}

export function getUnits() {
  return units
}

export function getLesson(lessonId) {
  return lessons.find((lesson) => lesson.id === lessonId)
}

export function getLessonsForUnit(unitId) {
  return lessons.filter((lesson) => lesson.unitId === Number(unitId))
}

export function getLessons() {
  return lessons
}

export function getActivities() {
  return activities
}

export function getActivity(activityId) {
  return activities.find((activity) => activity.id === activityId)
}

export function getActivityIdsForLesson(lessonId) {
  const lesson = getLesson(lessonId)
  return lesson ? lesson.activityIds : []
}

export function getActivitiesForLesson(lessonId) {
  return getActivityIdsForLesson(lessonId)
    .map((id) => getActivity(id))
    .filter(Boolean)
}

export function getActivityPosition(activityId) {
  const activity = getActivity(activityId)
  if (!activity) return -1
  return getActivityIdsForLesson(activity.lessonId).indexOf(activityId)
}

export function getNextActivity(activityId) {
  const activity = getActivity(activityId)
  if (!activity) return null
  const ids = getActivityIdsForLesson(activity.lessonId)
  const index = ids.indexOf(activityId)
  const nextId = ids[index + 1]
  return nextId ? getActivity(nextId) : null
}

export function getFirstAvailableLesson(courseId) {
  const courseUnits = getUnitsForCourse(courseId)
  for (const unit of courseUnits) {
    if (unit.status === 'locked') continue
    const unitLessons = getLessonsForUnit(unit.id)
    const availableLesson = unitLessons.find((lesson) => lesson.status === 'available')
    if (availableLesson) return availableLesson
  }
  return null
}

export function getUnitCourse(unitId) {
  const unit = getUnitById(unitId)
  return unit ? getCourse(unit.courseId) : null
}

export function unitRoute(unitId) {
  const unit = getUnitById(unitId)
  if (!unit) return { name: 'courses' }
  return { name: 'unit', params: { courseId: unit.courseId, unitId: String(unit.id) } }
}

export function lessonRoute(lessonId) {
  const lesson = getLesson(lessonId)
  if (!lesson) return { name: 'courses' }
  const unit = getUnitById(lesson.unitId)
  if (!unit) return { name: 'courses' }
  return {
    name: 'lesson',
    params: { courseId: unit.courseId, unitId: String(unit.id), lessonId: lesson.id },
  }
}
