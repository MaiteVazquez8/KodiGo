const files = import.meta.glob(
  ['./*.png', './*.jpg', './*.jpeg', './*.svg', './*.webp', './*.gif'],
  { eager: true, import: 'default' },
)

const courseImages = {}

for (const path of Object.keys(files)) {
  const name = path
    .split('/')
    .pop()
    .replace(/\.(png|jpe?g|svg|webp|gif)$/i, '')
  if (name.startsWith('fantasma')) continue
  courseImages[name] = files[path]
}

export function getCourseImage(key) {
  return courseImages[key] || null
}
