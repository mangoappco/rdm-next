# SKILL - RDM Next (rebuild M3 desde cero)

## 1. Objetivo

Construir la libreria de componentes para **mango-next**, sobre Material
Design 3, componente por componente, desde los mas basicos.

**Exito** = que cualquier pantalla de mango-next pueda construirse usando
solo esta libreria, sin CSS propio ni estilos inline.

**Principio rector:** cada componente se apoya en los que ya existen.
Button necesita typography, shape y color; por eso la capa de tokens va
primero y cada componente se construye cuando sus bases existen.

Carpeta hermana de `rdm/` (la libreria anterior), que se conserva intacta
como **referencia** y no se toca.

## 2. Principios (invariables)

| # | Regla | Detalle |
|---|---|---|
| 1 | **Cero CSS inline** | Un componente = un archivo `css/comp/<nombre>.css`. Sin excepciones |
| 2 | **HTML comentado** | Cada componente y cada pieza con `<!-- INICIO: x -->` / `<!-- FIN: x -->`. Grepeable: `grep "INICIO:"` lista el showroom entero |
| 3 | **Clase base obligatoria** | Todo componente tiene clase base (`.rdm-button`) + modificadores (`.rdm-button--filled`). Nunca modificadores sueltos ni selectores de etiqueta (`button { }`) |
| 4 | **Showroom por componente** | Una pagina `<nombre>.html` por componente, un ejemplo por variante y estado |
| 5 | **Indice vivo** | `index.html` enlaza a todos; se actualiza al agregar cada componente |
| 6 | **Un token, una fuente** | Todo valor visual viene de `--md-sys-*` o `--md-comp-*`; excepciones del proyecto en `--rdm-*` |

## 3. Metodologia (loop por componente)

1. Verificar que las bases existen (tokens + componentes previos)
2. Leer el comp token de Material Web para ese componente
3. Crear `css/comp/<nombre>.css`
4. Crear `<nombre>.html` con el showroom comentado
5. Enlazar desde `index.html`
6. Correr `tools/verify-tokens.ps1`
7. Documentar en este SKILL (seccion 9)

## 4. Convenciones

**Archivos:** paginas en raiz (`button.html`, `card.html`), CSS en
`css/comp/<nombre>.css`. Nombres en **ingles** en el codigo
(`button.html`, `.rdm-button--filled`); **espanol** en la documentacion.

**Estilos de showroom:** van en `css/demo/<pagina>.css`, nunca en `css/comp/`.
`css/demo/` no forma parte de la libreria: son clases con prefijo `demo-`
que solo existen para mostrar tokens. Cada pagina enlaza su demo CSS
directo en el `<head>`, no via `rdm-next.css`.

**Primitivas:** viven en `css/primitives/` (typography, icon, ...). Son
clases base que leen tokens sys y que los componentes consumen. Se importan
en `rdm-next.css` entre tokens y componentes. Excepcion deliberada:
`base.css` lee los tokens de body-medium directo en vez de exigir la clase
`.rdm-typography--body-medium` en cada `<body>` — si una pagina olvidara la
clase, el texto caeria al default del navegador.

**Convencion tipografica del showroom:** ningun `<p>` ni `<h1-h6>` pelado.
Cada elemento de texto declara su rol explicito. El default del `body` es
body-medium (estilo base de UI en M3); el copy de lectura opta por
body-large con su clase. Reparto: nav `label-large`, copy `body-large`,
nombre de swatch `title-medium`, spec tecnica `body-small`. El check 8 del
script lo vigila.

**Plantilla minima del showroom:**

```html
<!-- ================= BUTTON: variante filled ================= -->

<!-- INICIO: button filled -->
<button class="rdm-button rdm-button--filled">Guardar</button>
<!-- FIN: button filled -->

<!-- INICIO: button destructive (modificador de rol, no variante) -->
<button class="rdm-button rdm-button--filled rdm-button--destructive">Eliminar</button>
<!-- FIN: button destructive -->
```

Base + modificadores acumulados. Destructive no tiene pagina propia: es un
modificador de `rdm-button` y se demuestra dentro de `button.html`. Igual
que `--icon-only`.

## 5. Decisiones

| # | Decision | Valor | Por que |
|---|---|---|---|
| 1 | Tipografia | **Google Sans** variable 400..700 via Google Fonts | Se evaluaron Roboto (spec M3, estaba en v0.1-v0.7), Product Sans (licencia restringida, no esta en el Theme Builder) y Google Sans (la usa material.io). Override de 2 tokens en `additions.css`, no 15: `--md-ref-typeface-plain` y `-brand`. Pesos 400/500 segun M3 (475 es lo que shippea Google, se descarta). Sin `opsz` (rango 17..18 sin efecto visible) ni `GRAD` (default neutro) ni cursivas (la escala no las usa) |
| 2 | Tema | **Solo `prefers-color-scheme`**, sin JS ni `data-theme` | El toggle JS de la libreria anterior tenia `VAR_KEYS` hardcodeado y dejaba 6 tokens (`surface-container-*`) sin re-tematizar. Sin JS ese bug no puede existir. Costo: se pierde el toggle manual |
| 3 | Capas | **ref -> sys -> comp**, las tres | `ref` paletas crudas, `sys` roles con tema, `comp` tokens por componente. Un componente nunca lee `ref` |
| 4 | Vendor separado | `vendor/material-tokens/` intacto en `css/` | Cada token propio es demostrablemente de Google. Lo nuestro vive en `additions.css` y `project.css`, aislado |
| 5 | `colors.css` excluido | No se importa | Son clases demo (`.primary`, `.surface`...), 0 custom properties, colisionarian con el showroom |
| 6 | `comp` por componente | Se jala de Material Web al construir cada uno | El repo oficial frena en ref+sys; no hay `comp.css` gigante adelantado |
| 7 | Unidades | `em` en componentes, como la libreria anterior | Consistencia con el proyecto; los tokens usan px (spec) |
| 8 | Clase base | `.rdm-button` + `.rdm-button--filled`, siempre las dos | La libreria anterior usaba modificadores sin base y selectores `button { }` globales: M3 nunca aplica estilos a etiquetas nativas y sin base habia que duplicar geometria por variante (bug de sincronizacion card/form). La base lleva geometria, tipografia, shape y state layer; la variante solo color y elevacion |

## 6. Capa de tokens

```
css/md/tokens.css    entry: vendor (sin colors.css) + additions.css
css/md/additions.css los 7 roles que el vendor no trae (post-2023)
css/primitives/      clases base que leen tokens (typography, icon, ...)
css/rdm/project.css  --rdm-* (z-index; M3 no define apilamiento)
css/rdm-next.css     entry del proyecto
css/comp/            vacio; se llena por componente
```

### Fuente de verdad

Repo oficial `material-foundation/material-tokens` (Apache 2.0, LICENSE
conservada en vendor/). Podado a `css/` + docs: se elimino `dsp/` (230 KB
para Android/iOS/Flutter/JS/SCSS, 0 referencias) y artefactos de GitHub.
Los 10 archivos de `css/` estan sin tocar.

| Archivo vendor | Tokens | Capa |
|---|---|---|
| `palette.css` | 80 | ref |
| `typography.css` | 230 | sys |
| `shape.css` | 48 | sys |
| `motion.css` | 45 | sys |
| `state.css` | 4 | sys |
| `elevation.css` | 19 | sys |
| `theme/light.css` + `theme/dark.css` | 29+29 | sys |

### Los 9 roles de superficie (`additions.css`)

El vendor es baseline anterior a marzo 2023 (opacidades sobre surface) y
no trae la familia por tono. M3 actual: **9 roles**, 5 contenedores + 4
que no lo son (`surface`, `surface-dim`, `surface-bright`,
`surface-variant` en depreciacion hacia `highest`).

| Token | Light | Dark | Origen |
|---|---|---|---|
| `surface-dim` | `#DED8E1` | `#141218` | neutral87 / neutral6 (dim dark verificado en libreria anterior) |
| `surface-bright` | `#FFFFFF` | `#3B383E` | neutral100 / estandar M3 (no estaba en libreria anterior) |
| `surface-container-lowest` | `#FFFFFF` | `#0F0D13` | verificado 5/5 |
| `surface-container-low` | `#F7F2FA` | `#1D1B20` | verificado 5/5 |
| `surface-container` | `#F3EDF7` | `#211F26` | verificado 5/5 |
| `surface-container-high` | `#ECE6F0` | `#2B2930` | verificado 5/5 |
| `surface-container-highest` | `#E6E0E9` | `#36343B` | verificado 5/5 |

Donde el tono existe en el vendor se referencia con `var(--md-ref-palette-*)`;
donde no (la paleta solo tiene 13 tonos neutral) va el hexadecimal del
baseline con el tono anotado.

**Nota de baseline: `surface` es `#FFFBFE`, no `#FEF7FF`.** El vendor define
`surface` como `neutral99` y `neutral99` es `#FFFBFE`. `#FEF7FF` es de un
baseline mas nuevo con otro seed. La paleta anterior coincide 5/5 tonos
clave con el vendor (`primary40`, `neutral99`, `neutral-variant90`,
`error40`, `neutral10`), asi que el baseline es el mismo.

Esto cierra ademas la desviacion irresoluble de Card en la libreria
anterior: `filled` usa `surface-container-highest` (surface-variant se
fusiono ahi) y `elevated` usa `surface-container-low`.

## 7. Orden de construccion de componentes

Por dependencia y apalancamiento, uno por vez. Button primero: su anatomia
la copian text field, FAB y los actions de card.

```
Actions: button (+ icon-only, FAB, destructive)
Inputs: text field, select, checkbox, radio, switch, file input
Containment: list, card, dialog, snackbar
Navigation: top bar, nav bar, drawer, rail, tabs
```

## 8. Verificacion

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify-tokens.ps1
```

| Check | Detecta |
|---|---|
| Referencias rotas | `var()` sin definir ni en `css/` ni en vendor/ |
| Duplicados | Mismo token en 2+ archivos propios |
| sys incompleto | Un rol de superficie sin light o sin dark |
| Fugas de capa | `comp/`, `rdm/`, `primitives/` o `demo/` leyendo `--md-ref-*` (prohibido) |
| DSP consumido | `var()` a `-value`, `-unit` o `axis-value` (ruido de Figma) |
| Imports | Todos los `@import` relativos resuelven a archivo existente; se saltan los `https://` |
| Texto pelado | Ningun `<p>` ni `<h1-h6>` sin clase en los `.html` |
| Fuente conectada | `--md-ref-typeface-plain/-brand` (valor efectivo) cargada via `<link>` en los HTML |
| Shape sin ruido | Ningun `-family` consumido en `var()` (todos valen 1px o 3px, basura DSP) |
| Niveles sys intactos | Ningun `--md-sys-elevation-levelN:` declarado en CSS propio (son dp del vendor; sombras en `--rdm-shadow-*`) |
| Swatches identicos | Ningun run de 3+ `<div>` consecutivos con la misma clase (si no varia, es tabla) |
| Container en paginas | Todo `.html` de raiz usa `.rdm-container` (ningun showroom de lado a lado) |
| State sin ruido | Toda opacidad `--md-sys-state-*-state-layer-opacity` propia vale 0.08, 0.12 o 0.16 exactos (sin ruido Figma) |
| Motion con tokens | Ningun `transition`/`animation-duration` con duracion literal en CSS propio (todo pasa por token; el bloque reduced-motion se excluye) |

Corre en cada commit de la capa de tokens. Estado actual: 15/15 en verde.

**Leccion v0.5:** el import de `primitives/typography.css` se escribio como
`../primitives/` (sube un nivel de mas) y la hoja nunca llego al navegador:
todo el showroom se veia igual. El chequeo de imports existia en esta tabla
pero no estaba implementado en el script. Ahora si: el check 7 falla ante
cualquier `@import` relativo roto, probado con archivo temporal.

## 9. Historial de versiones

- **v0.1** - Capa base M3: estructura + `git init`, `tokens.css` importando
  el vendor (sin `colors.css`), `additions.css` con los 9 roles de
  superficie, `project.css` con `--rdm-z-*`, index limpio con roadmap por
  dependencia, script de verificacion de 5 checks. Vendor podado a `css/`
  + LICENSE + docs.
- **v0.2** - SKILL reestructurado a 10 secciones: objetivo mango-next con
  criterio de exito, 6 principios invariables, metodologia de 7 pasos,
  convenciones (ingles en codigo, espanol en docs, paginas en raiz,
  plantilla del showroom), y decision 8 (clase base obligatoria).
- **v0.3** - Fase 1a: `css/rdm/base.css` (body con surface/on-surface y
  fuente desde el token, rompe el ciclo superficie/typography) +
  `surface.html` con los 9 roles tonales y `css/demo/surface.css`
  (convencion `css/demo/` documentada). Radio de swatches desde
  `--md-sys-shape-corner-medium-default-size`. Indice enlaza a Surface.
- **v0.4** - Primitiva Typography: `css/primitives/typography.css` con los
  15 roles (5 props cada uno, 75 lineas de tokens reales) + `typography.html`
  con valores visibles por rol. Se descartan `-value`/`-unit` (ruido DSP),
  `axis-value` y los 4 `unset`, mas el enum crudo `label-medium-text-transform: 1`
  de Figma. Check 6 en el script: ningun token DSP se consume.
- **v0.5** - Fix: el import de primitives apuntaba a `../primitives/`
  (un nivel de mas) y typography.css nunca llegaba al navegador. Check 7
  de imports implementado (la tabla lo prometia, el script no lo tenia),
  probado contra archivo temporal con import roto.
- **v0.6** - Showroom usa su propia primitiva: los 3 `h1` a
  `display-small` y los 13 `h2` a `title-large` en las 3 paginas. 0
  headings pelados en el proyecto (verificado por conteo).
- **v0.7** - Default del `body` a body-medium (estilo base de UI en M3) y  28 parrafos con clase explicita por categoria (nav `label-large` x2,
  copy `body-large` x3, swatch `title-medium` x8, spec `body-small` x15).
  Check 8: ningun `<p>` ni `<h1-h6>` pelado en los HTML, probado contra
  archivo temporal. Convencion tipografica documentada.
- **v0.8** - Tipografia a Google Sans (variable 400..700 via `<link>`).  Override de 2 tokens en `additions.css` (`--md-ref-typeface-plain` y
  `-brand`); los 15 roles siguen la cadena solos. Sin `opsz`/`GRAD`/
  cursivas (no aportan). Pesos 400/500 segun M3, no 475. Check 9: la
  familia del token debe estar cargada en los HTML, probado en ambos
  sentidos (stash del override -> ROTA Roboto x2).
- **v0.9** - Shape: `shape.html` con 7 simetricos + 4 direccionales y
  `css/demo/shape.css` (11 clases 1:1). Token `full` ausente en el vendor
  (solo `-family: 3px`): agregado a `additions.css` en 9999px segun spec.
  Shape no lleva primitiva (es atomico, se consume directo). Nota: el
  vendor trae 10 clases sin prefijo (`.shape-medium`, `.large-top`...)
  que entran con el import; no usarlas, son demo de Google. Check 10:
  ningun `-family` consumido, probado contra archivo temporal.
- **v0.10** - Elevation: `elevation.html` con 3 secciones (Levels con los 6
  dp del vendor, Tonal como tabla de referencia, Shadow con las 6 recetas
  `--rdm-shadow-*` de `project.css`) y `css/demo/elevation.css`. Hallazgo:
  el vendor esta bien, M3 define elevacion como distancia dp y en web
  `box-shadow: 1px` dibuja un borde duro; la libreria anterior tokenizo
  recetas MD2 bajo nombres M3. Check 11: ningun nivel sys redeclarado,
  probado contra archivo temporal (el primer regex exigia inicio de linea
  y no detectaba mid-line; se endurecio con lookbehind).
- **v0.11** - Levels de swatches a tabla: los 6 swatches usaban la misma
  clase sin modificador (cero sombra, 6 cajas iguales). Criterio: si un
  valor no se dibuja, es tabla, no swatch. Check 12: ningun run de 3+
  `<div>` consecutivos con la misma clase, probado en ambos sentidos
  (umbral 3: 2 identicos pueden ser estados legitimos).
- **v0.12** - Tabla fusionada: la tabla de Levels y la seccion Shadow eran
  dos mitades de la misma cosa separadas. Ahora una sola tabla de 5
  columnas (Level | Token sys | dp | Render | Swatch) donde cada nivel viaja
  acompanado de lo que lo dibuja; seccion Shadow eliminada y swatches como
  parche visual dentro de la celda (`td > .demo-elevation` sin margen).
  `surface-tint-color` (token M3 real, sin consumir) queda en pendientes:
  tintar superficies no es elevacion y se vera cuando un componente lo pida.
- **v0.13** - Revert de la tabla fusionada: embeber los swatches en celdas
  los dejo vacios y diminutos, sin aire para que la sombra respire. Vuelta
  a dos secciones (Levels como tabla pura de datos, Shadow como galeria de
  6 swatches grandes). Leccion: arreglar la seccion con el bug, no
  redisenar la pagina alrededor de el; una galeria necesita swatches de
  bloque completo para que se lea la progresion sutil-prominente.
- **v0.14** - Layout: `layout.html` + `.rdm-container` en `project.css`
  (`--rdm-layout-max-width: 1200px`, `--rdm-layout-margin: 16px` que pasa
  a 24px en 600px) y reset `box-sizing` en `base.css`. Los 5 HTML envuelven
  header+main en el container. Hallazgo: M3 no exporta tokens de layout ni
  spacing (grep al vendor: cero matches); los `--md-sys-spacing-*` que
  circulan no existen y el check 2 los marcaria. Grid de 12 columnas y app
  frame difieren por YAGNI. Check 13: todo HTML de raiz con container,
  probado contra pagina temporal sin el.
- **v0.15** - State layer: 4 opacidades limpias en `additions.css`
  (el vendor trae ruido Figma: 0.07999999821186066...), primitiva
  `.rdm-state-layer` en `css/primitives/` con `::after`,
  `pointer-events: none` y los 4 estados via `color-mix` sobre `--layer`
  (opacidad del token con `calc * 100%`). Dragged es modificador porque
  no tiene pseudo-clase. `state-layer.html` con tabla, mecanismo en vivo,
  comparacion hover/pressed/dragged y focus con `:focus-visible` + nota
  de Tab. Check 14: opacidades propias exactas (0.08/0.12/0.16),
  probado contra valor con ruido.
- **v0.16** - Motion: 7 curvas compuestas y 16 alias semanticos de duracion
  en `additions.css`. Hallazgos: duraciones del vendor correctas pero sin
  nombre (verificadas contra material-web v0_192), sin token de easing
  compuesto (cada componente escribiria el wrapper a mano), ruido Figma
  en 16 puntos de control (no se limpian: dejan de consumirse),
  motion-path: 1 es basura (el generador dice 'not supported'), emphasized
  y standard comparten curva por spec, springs espaciales imposibles en CSS
  puro, y faltaba prefers-reduced-motion (agregado a `base.css`). Deuda
  de v0.15 saldada: state-layer usa duration-short3 + easing-standard.
  Short3 es decision de proyecto (M3 no da duracion para state layers),
  a confirmar al construir Button. `motion.html` con 7 easings animados
  en loop, tabla de 16 duraciones y patron de transicion real. Check 15:
  ninguna duracion literal en transition/animation (excluye el bloque
  reduced-motion: 0.01ms ahi es patron de accesibilidad), probado contra
  valor literal.

## 10. Decisiones pendientes

- [x] Peso mediano con Google Sans: **500** segun spec M3 (resuelto en v0.8; 475 es lo que shippea Google, descartado).
- [ ] `surface-variant` en depreciacion: mantener el token del vendor o alias a `highest`. No tocar hasta que un componente lo necesite.
- [ ] Easing y duraciones de motion por componente: los tokens existen (45 en `motion.css`), falta mapearlos al construir cada componente. `160ms` no es token M3.
- [ ] Zona header/avatar de card y taxonomia de actions: documentadas en la libreria anterior, aplicar al construir Card.
- [ ] `--md-sys-elevation-surface-tint-color`: token M3 real del vendor (tinta primaria sobre superficies elevadas), hoy sin consumir. No es sombra ni nivel; evaluar cuando un componente necesite tinte de elevacion.
