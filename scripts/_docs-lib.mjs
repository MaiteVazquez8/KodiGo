// Utilidades compartidas para generar los documentos Word de Kodigo con la
// paleta oficial (#000000, #3E065F, #700B97, #8E05C0).
import {
  Document, Paragraph, TextRun, HeadingLevel, AlignmentType, BorderStyle,
  Table, TableRow, TableCell, WidthType, convertInchesToTwip, ImageRun,
  Header, Footer, PageNumber, NumberFormat, SectionType, TableLayoutType,
} from 'docx'
import { readFileSync, existsSync } from 'node:fs'
import { extname, join, dirname } from 'node:path'

export const COLOR = {
  negro: '000000',
  violetaOscuro: '3E065F',
  violeta: '700B97',
  violetaIntenso: '8E05C2',
  texto: '1C1C1C',
  gris: '5A5A5A',
  grisClaro: '8C8C8C',
  superficie: 'FBF9FD',
  linea: 'E6DFF0',
  acentoSuave: 'F3EAFB',
  exito: '1E7A34',
  exitoSuave: 'E5F6EA',
  error: 'B3261E',
  errorSuave: 'FBE9E7',
  warning: '8A5A00',
  warningSuave: 'FFF4D6',
}

export const FONT = {
  body: 'Calibri',
  code: 'Consolas',
}

export const IMG_DIR = 'docs/imagenes-usuario'

const pxToTwip = (px) => Math.round(px * 15)

export const readImageSize = (path) => {
  const buf = readFileSync(path)
  // PNG: los anchos y altos viven en el IHDR (offset 16 y 20).
  if (buf.readUInt32BE(0) === 0x89504e47) {
    return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) }
  }
  // JPEG: escanear los segmentos SOF.
  let o = 2
  while (o < buf.length) {
    if (buf[o] !== 0xff) { o += 1; continue }
    const marker = buf[o + 1]
    const len = buf.readUInt16BE(o + 2)
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      return { width: buf.readUInt16BE(o + 7), height: buf.readUInt16BE(o + 5) }
    }
    o += 2 + len
  }
  return { width: 1000, height: 1000 }
}

export const image = (path, widthMm, caption = null) => {
  if (!existsSync(path)) {
    return [new Paragraph({ children: [new TextRun({ text: `[imagen no disponible: ${path}]`, color: COLOR.gris, italics: true })], spacing: { before: 120, after: 120 } })]
  }
  const dim = readImageSize(path)
  const ratio = dim.height / dim.width
  const wpx = Math.round((widthMm / 25.4) * 96)
  const hpx = Math.round(wpx * ratio)
  const out = [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 240, after: 60 },
      children: [
        new ImageRun({
          type: extname(path).slice(1).toLowerCase() === 'jpg' ? 'jpeg' : 'png',
          data: readFileSync(path),
          transformation: { width: wpx, height: hpx },
        }),
      ],
    }),
  ]
  if (caption) out.push(captionPara(caption))
  return out
}

export const captionPara = (texto) => new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { after: 220 },
  children: [new TextRun({ text: texto, italics: true, size: 17, color: COLOR.gris, font: FONT.body })],
})

export const h1 = (texto) => new Paragraph({
  heading: HeadingLevel.HEADING_1,
  spacing: { before: 360, after: 180 },
  border: { bottom: { color: COLOR.violetaIntenso, space: 4, style: BorderStyle.SINGLE, size: 18 } },
  children: [new TextRun({ text: texto, bold: true, size: 40, color: COLOR.violetaOscuro, font: FONT.body })],
})

export const h2 = (texto) => new Paragraph({
  heading: HeadingLevel.HEADING_2,
  spacing: { before: 280, after: 140 },
  children: [new TextRun({ text: texto, bold: true, size: 28, color: COLOR.violeta, font: FONT.body })],
})

export const h3 = (texto) => new Paragraph({
  heading: HeadingLevel.HEADING_3,
  spacing: { before: 200, after: 100 },
  children: [new TextRun({ text: texto, bold: true, size: 22, color: COLOR.negro, font: FONT.body })],
})

export const p = (texto, opts = {}) => new Paragraph({
  spacing: { before: 40, after: 100 },
  children: [new TextRun({ text: texto, size: 19, color: COLOR.texto, font: FONT.body, ...opts })],
})

export const bullet = (texto) => new Paragraph({
  bullet: { level: 0 },
  spacing: { before: 20, after: 20 },
  children: [new TextRun({ text: texto, size: 19, color: COLOR.texto, font: FONT.body })],
})

export const callout = (texto, color = COLOR.acentoSuave, borde = COLOR.violeta) => new Paragraph({
  spacing: { before: 120, after: 120 },
  shading: { fill: color },
  border: {
    left: { color: borde, space: 14, style: BorderStyle.SINGLE, size: 14 },
  },
  indent: { left: 120 },
  children: [new TextRun({ text: texto, size: 18, color: COLOR.texto, font: FONT.body })],
})

export const code = (texto) => new Paragraph({
  spacing: { before: 80, after: 80 },
  shading: { fill: 'F5F5F5' },
  children: texto.split('\n').flatMap((line, i, arr) => [
    new TextRun({ text: line, font: FONT.code, size: 16, color: '1B1B1B', break: i > 0 ? 1 : undefined }),
  ]),
})

const CELL_PAD = { margins: { top: 60, bottom: 60, left: 110, right: 110 } }

export const tabla = ({ headers, rows, widths, headerFill = COLOR.violetaIntenso, fontSize = 15 }) => {
  const total = widths.reduce((a, b) => a + b, 0)
  const columnWidths = widths.map((w) => Math.round((w / total) * 9900))
  const headerCells = headers.map((h, i) => new TableCell({
    width: { size: columnWidths[i], type: WidthType.DXA },
    shading: { fill: headerFill },
    margins: CELL_PAD.margins,
    verticalMerge: 'restart',
    children: [new Paragraph({
      spacing: { before: 0, after: 0 },
      children: [new TextRun({ text: String(h), bold: true, size: fontSize, color: 'FFFFFF', font: FONT.body })],
    })],
  }))
  const bodyRows = rows.map((row, ri) => new TableRow({
    children: row.map((cell, ci) => new TableCell({
      width: { size: columnWidths[ci], type: WidthType.DXA },
      shading: { fill: ri % 2 === 0 ? 'FFFFFF' : COLOR.superficie },
      margins: CELL_PAD.margins,
      children: [new Paragraph({
        spacing: { before: 0, after: 0 },
        children: [new TextRun({ text: String(cell ?? ''), size: fontSize, color: COLOR.texto, font: FONT.body })],
      })],
    })),
  }))
  return new Table({
    width: { size: 9900, type: WidthType.DXA },
    columnWidths,
    rows: [new TableRow({ children: headerCells, tableHeader: true }), ...bodyRows],
    margins: { top: 40, bottom: 40, left: 60, right: 60 },
    border: {
      top: { color: COLOR.linea, size: 8 },
      bottom: { color: COLOR.linea, size: 8 },
      insideHorizontal: { color: COLOR.linea, size: 4 },
      insideVertical: { color: COLOR.linea, size: 4 },
      left: { color: COLOR.linea, size: 8 },
      right: { color: COLOR.linea, size: 8 },
    },
  })
}

export const tablaNota = (texto) => new Paragraph({
  spacing: { before: 40, after: 140 },
  children: [new TextRun({ text: texto, italics: true, size: 15, color: COLOR.grisClaro, font: FONT.body })],
})

export const spacer = (h = 160) => new Paragraph({ spacing: { before: 0, after: h }, children: [] })

export const coverBlocks = ({ wordmark, title, subtitle, lineas }) => {
  return [
    new Paragraph({ spacing: { before: 720, after: 0 }, children: [] }),
    new Paragraph({
      spacing: { before: 0, after: 40 },
      children: [
        new TextRun({ text: 'KODI', bold: true, size: 76, color: COLOR.negro, font: FONT.body }),
        new TextRun({ text: 'GO', bold: true, size: 76, color: COLOR.violetaIntenso, font: FONT.body }),
      ],
    }),
    new Paragraph({ spacing: { before: 0, after: 720 }, children: [new TextRun({ text: 'Gamifica tu aprendizaje de código', size: 20, color: COLOR.gris, font: FONT.body })] }),
    new Paragraph({
      spacing: { before: 0, after: 200 },
      shading: { fill: COLOR.negro },
      children: [new TextRun({ text: title, bold: true, size: 58, color: 'FFFFFF', font: FONT.body })],
    }),
    new Paragraph({
      spacing: { before: 0, after: 760 },
      shading: { fill: COLOR.violetaOscuro },
      children: [new TextRun({ text: subtitle, size: 24, color: 'FFFFFF', font: FONT.body })],
    }),
    ...lineas.map(({ izq, der }) => new Paragraph({
      spacing: { before: 24, after: 24 },
      border: { bottom: { color: COLOR.linea, space: 4, style: BorderStyle.SINGLE, size: 6 } },
      children: [
        new TextRun({ text: izq.toUpperCase(), size: 14, bold: true, color: COLOR.violeta, font: FONT.body }),
        new TextRun({ text: '   ' + der, size: 18, color: COLOR.texto, font: FONT.body }),
      ],
    })),
    new Paragraph({ spacing: { before: 480, after: 40 }, border: { top: { color: COLOR.violetaIntenso, space: 6, style: BorderStyle.SINGLE, size: 16 } }, children: [] }),
    new Paragraph({ children: [new TextRun({ text: 'Aplicación educativa para aprender programación de forma progresiva y gamificada.', size: 17, italics: true, color: COLOR.gris, font: FONT.body })] }),
  ]
}

export const headerFooter = (docTitle) => {
  const header = new Header({
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        border: { bottom: { color: COLOR.violeta, space: 3, style: BorderStyle.SINGLE, size: 8 } },
        children: [
          new TextRun({ text: 'KODIGO', bold: true, size: 15, color: COLOR.violetaIntenso, font: FONT.body }),
          new TextRun({ text: '  ·  ' + docTitle, size: 15, color: COLOR.gris, font: FONT.body }),
        ],
      }),
    ],
  })
  const footer = new Footer({
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        border: { top: { color: COLOR.violeta, space: 3, style: BorderStyle.SINGLE, size: 8 } },
        children: [
          new TextRun({ text: 'Kodigo · 16 de noviembre de 2026 · Página ', size: 15, color: COLOR.gris, font: FONT.body }),
          new TextRun({ children: [PageNumber.CURRENT], size: 15, color: COLOR.violetaIntenso, font: FONT.body }),
          new TextRun({ text: ' de ', size: 15, color: COLOR.gris, font: FONT.body }),
          new TextRun({ children: [PageNumber.TOTAL_PAGES], size: 15, color: COLOR.violetaIntenso, font: FONT.body }),
        ],
      }),
    ],
  })
  return { header, footer }
}

export const buildDocument = ({ title, creator, children, header, footer }) => new Document({
  creator,
  title,
  description: title,
  styles: {
    default: {
      document: {
        run: { font: FONT.body, size: 19, color: COLOR.texto },
        paragraph: { spacing: { line: 276 } },
      },
    },
  },
  sections: [{
    properties: {
      page: {
        size: { width: convertInchesToTwip(8.27), height: convertInchesToTwip(11.69) }, // A4
        margin: { top: 900, bottom: 900, left: 1000, right: 1000, header: 420, footer: 420 },
      },
    },
    headers: { default: header },
    footers: { default: footer },
    children,
  }],
})

export const saveDocument = async (doc, path) => {
  const { Packer } = await import('docx')
  const buf = await Packer.toBuffer(doc)
  const fs = await import('node:fs')
  fs.writeFileSync(path, buf)
  return buf.length
}
