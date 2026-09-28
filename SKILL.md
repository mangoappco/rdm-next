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
| 1 | Tipografia | **Roboto** 400+500 via Google Fonts | Es lo que M3 especifica. Se evaluaron Product Sans (licencia restringida, no esta en el Theme Builder) y Google Sans (la usa material.io, pero no es la spec). Cambiar despues son 15 lineas |
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
| Fugas de capa | `comp/` o `rdm/` leyendo `--md-ref-*` (prohibido) |
| Imports | Todos los `@import` resuelven a archivo existente |

Corre en cada commit de la capa de tokens. Estado actual: 5/5 en verde.

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

## 10. Decisiones pendientes

- [ ] Peso mediano con Google Sans si se cambia de fuente: 500 (spec M3) o 475 (lo que shippea Google). Solo aplica si se abandona Roboto.
- [ ] `surface-variant` en depreciacion: mantener el token del vendor o alias a `highest`. No tocar hasta que un componente lo necesite.
- [ ] Easing y duraciones de motion por componente: los tokens existen (45 en `motion.css`), falta mapearlos al construir cada componente. `160ms` no es token M3.
- [ ] Zona header/avatar de card y taxonomia de actions: documentadas en la libreria anterior, aplicar al construir Card.
