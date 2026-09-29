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

**Elementos vs modificadores:** `familia-elemento` con guion simple
(`.rdm-card-content`) es parte del componente y vive en `css/comp/`;
`familia--modificador` con doble guion es variante de estado o rol. El
check 26 acepta ambas formas como familia. Regla de codificacion: todo
`·` se escribe limpio en UTF-8; si el pipeline lo moja como `Â·`
(bytes C3 82 C2 B7), se repara a nivel byte preservando el BOM.

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
| 4 | Vendor separado | `vendor/material-tokens/` intacto en `css/` | Cada token propio es demostrablemente de Google. Lo nuestro vive en `additions.css` y `project.css`, aislado. Dos vendors, no uno: `material-tokens/` (export CSS de Adobe/DSP: ref+sys, se importa) y `material-web-tokens/` (SCSS de labs/card v0_192: comp, solo referencia, nunca se importa). No se unifican: la separacion registra las dos generaciones (el bug 0.12 era M2 arrastrado). Todo archivo bajo `vendor/` cubierto por Apache 2.0 (check 42) |
| 5 | `colors.css` excluido | No se importa | Son clases demo (`.primary`, `.surface`...), 0 custom properties, colisionarian con el showroom |
| 6 | `comp` por componente | Se jala de Material Web al construir cada uno | El repo oficial frena en ref+sys; no hay `comp.css` gigante adelantado |
| 7 | Unidades | `rem` en geometria de componentes | La libreria anterior usaba `em`, pero `<button>` no hereda el font-size del body (13.33px del UA): sus botones median 33px, no 40px. `rem` es raiz-fija e inmune a la etiqueta (14px) y al UA. `em` solo donde lo relativo al texto es lo querido |
| 8 | Clase base | `.rdm-button` + `.rdm-button--filled`, siempre las dos | La libreria anterior usaba modificadores sin base y selectores `button { }` globales: M3 nunca aplica estilos a etiquetas nativas y sin base habia que duplicar geometria por variante (bug de sincronizacion card/form). La base lleva geometria, shape y state layer; la variante solo color y elevacion. Tipografia por composicion con `rdm-typography--*` en el HTML (v0.22), no redeclarada |
| 9 | M3 core, no Expressive | **Target M3 core** (vendor pre-2023 + material-web v0.192) | M3 Expressive (May 2025: 5 tamanos, square, shape morph, toggle, springs, padding 16dp) no esta disponible para Web en botones. No somos ancient, somos baseline-matched: 24dp padding, round, small, duration+easing |
| 10 | Spacing | `--rdm-measurement-*` (oficial `md.sys.measurement.space100`) | El sistema es spec pero los tokens son Compose-only (Web Unavailable); misma nomenclatura para migracion 1:1 si llegan |
| 11 | Medidas de card | **Solo el container tiene medidas**: 12dp shape, 16dp left/right padding, 8dp max entre cards, start-aligned. **La media no tiene medida y es libre por diseno** | La tabla de `cards/specs` publica exactamente esas 4 filas y ninguna mas. La spec dice "Card size is determined by the elements it contains": M3 no prescribe aspect ratio ni thumbnail fijo, el componente es slot-based. No se inventan 16:9 ni 80x80 (auditados: sin fuente). `mango-next` elige la proporcion de sus imagenes sin violar M3 |
| 12 | Inset divider | **16dp**, igual al padding del container | La spec define full-width e inset pero no da el numero del inset. Se infiere del padding (16dp), que si esta publicado, para que la linea alinee con el texto. Decision de proyecto, no dato de tabla |
| 13 | Elevacion del container | **Solo el container expresa elevacion**; ningun slot interno lleva sombra | Texto oficial: "Card elevation is expressed by the container". Dos elementos con sombra dentro se leerian como dos superficies |
| 14 | Bloques de contenido | **Los slots se agrupan en bloques** con enfasis variable; **el padding es del contenido, no del container** | 3 fuentes: imagen edge-to-edge (flush al borde), content blocks ("grouped into blocks"), media contenida entre texto y actions. Prepara el refactor opcion A del paso 4 |
| 15 | Action area | **Botones a la derecha (`flex-end`) con gap 8dp** (`measurement-100`) | Sin fuente: la tabla publica 8dp max *entre cards*, no entre botones; stories.ts usa 16 entre bloques. Se toma el 8dp por ser la unica medida publicada de separacion. Si aparece el valor real, cambia en una linea |
| 16 | Ritmo de typography | **Plano: 8 dentro del par, 16 entre specimens** (decision de proyecto, no dato M3) | Verificado en el vendor: cada rol publica font, size, weight, line-height y tracking; cero margin/padding. El half-leading de M3 es absoluto-plano (2-4px en los 15 roles) con ratio decreciente (1.5 en body-large a 1.123 en display-large). Un margen proporcional al tamano iria contra M3. Seccion Teoria en typography.html con la tabla de ratios |
| 17 | Reset propio, no normalize | **Sin dependencias externas**: el reset vive en `base.css` con cada regla justificada | M3 no publica reset; normalize es opinion de terceros sin trazabilidad contra nuestra fuente y mete la primera dependencia externa en un proyecto sin dependencias. La sonda encontro ~20 elementos con defaults vivos (button Arial 13.33px, th centrado, h1 28px/700); se resetean con motivo documentado y check 50 que lo verifica |
| 18 | Ritmo en cero | **Todo `margin` de `css/demo/` a 0**; el aire se define despues con reglas de spacing explicitas | Los 5 niveles de pagina se acumulaban sin querer (section 32 + hr 8 = 41px medidos entre secciones). El `hr` conserva sus 8/8 porque son del componente divider. Check 52 (ritmo en cero) y 53 (el divider es el unico que separa) |
| 19 | Contrato de spacing | **Componentes = padding + gap del padre; layouts = margin + spacer. Hijos sin margin jamas** | Spec Do/Don't textual: el padre organiza, los hijos no llevan margin porque no son uniformes y piden mas tokens. El margin no aparece en la lista de conceptos de componentes. divider.css exento: separar es su funcion |
| 20 | Layout contra la spec actual | **Breakpoints (no window size classes), grid de 8, max-width dentro de expanded** | La spec renombro en mayo 2026 y nuestro layout.html publicaba el vocabulario viejo (3 clases, 12 columnas) con fecha para saber que es spec actual. El 1200 caia en Large; el 1024 vive en expanded. Tokens de breakpoint como limites inferiores (var() no vale en @media) |
| 21 | Showroom = ejemplos + medidas | **Cada showroom muestra ejemplos de SU componente y sus medidas publicadas. La guia del sistema vive en SKILL.md** | Las secciones de documentacion se cuelan version tras version (Emphasis y Placement tenian 0 specimens). La tabla de medidas se queda porque hace falta para consumir el componente; Audit, Tokens narrados, Rules y notas de derivacion salen al apendice (seccion 11). Check 59 lo custodia |
| 22 | Anatomy visual | **La anatomia es una referencia compuesta con el componente real, no un parrafo** | Card la tenia visual (35 specimens) y button/fab/extended-fab/icon-button en texto con el mismo nombre. El texto nombraba partes sin mostrarlas (y fab citaba rdm-fab--extended, que no existe como clase). Check 60 lo custodia |
| 23 | Menu baseline por pasos | **Baseline (core) por decision 9; menu-item dentro de menu; showroom estatico sin JS** | El vertical es Expressive y no se construye. Lists viene despues: el item del menu no es el item de lista. Apertura y reposicion son comportamiento del producto; el showroom muestra el surface abierto con roles ARIA |
| 24 | Scaffold temporal del showroom | **Barra minima (marca + index) porque no hay nav rail; el ritmo se define en `showroom.css` con token y bordes opuestos en 0** | Sin rail ni navigation bar no hay navegacion M3 que poner; 16 links en horizontal no son M3. El rail entra cuando exista el componente y la barra se ajusta. El ritmo vuelve con criterio unico y explicito (leccion v0.56: 41px por acumulacion) |
| 25 | El padre declara el ritmo | **`section` e `intro` con flex + gap con token; ningun hijo declara `margin`** | Do/Don't textual de M3 + precedente del vendor (gap 16 uniforme en stories.ts). Los wrappers no se crean: section, intro, .demo-type y .demo-card-spacing ya existian, solo les faltaba layout. Con gap en el padre, un margin en el hijo sumaria (16+16=32): por eso salen, no por limpieza |
| 26 | Divider con medidas de spec | **Vendor (color + thickness) + tabla de medidas; top-8 simetrico y vertical inline-8 como decisiones; 4dp y right-8 pendientes de Lists** | El vendor no trae geometria: todo margen sale de la tabla. La spec publica bottom 8; el top iguala por lectura simetrica. El 4dp a supporting-text y el right 8dp son del diagrama en contexto de lista, no de la base: forzarlos romperia inset (right 0) y full-width |
| 27 | Aire de layout vs respiracion del componente | **`main > hr` con margin de layout; el 8/8 del componente intacto** | El hr entre secciones juega dos roles: linea (componente) y separacion (layout). Envolverlo en divs es churn en 18 archivos; una regla de contexto hace lo mismo. `main > hr` alcanza solo separadores (specimens y nav fuera). Total 33 sin superar los 32 de barra a main |
| 28 | Indice por dependencia (dogfooding) | **Divider tras foundations; inputs por dependencia; menu antes que Lists** | Divider es componente M3 (no primitiva ni foundation): sube solo en el indice, `css/comp/divider.css` no se mueve. Checkbox/radio/switch no piden nada; select pide text field + menu. Menu define su propio MenuItem (vendor: paquetes separados). Limpia contaminacion externa: Paper es MUI, Badge fuera de scope, ciclo Select/Menu |
| 29 | Menu item standalone | **`.rdm-menu-item` sin componente Lists; procedencia compartida registrada** | El wrapper de Google lo dice textual: toma los valores de md-comp-list-item y renombra el prefijo. Los 30 tokens son autosuficientes; la dependencia con list/ es de comportamiento (controllers), no visual (D23). Correccion propia: el alto es 56/72, no 48. Vendor de 3 archivos (el styles scss vive en menu/internal/menuitem/) |
| 30 | Medidas sin auditoria | **Tablas Medida/Valor sin columna Estado; notas de derivacion al apendice** | La columna Estado con 12 coincide es ruido: el valor ya esta en el CSS. Solo card la conserva (permitido/prohibido por fila es dato de consumo) y state-layer (ahi Estado es el nombre del estado). Lo pendiente (divider 4dp/right-8 en Lists, menu sin radio, Grouped Expressive) se preserva en §11 |
| 31 | Divider sin ancho fijo | **La base no declara inline-size; el bloque llena entre margenes** | 100% + margin = overflow (el 100% va contra el content-box y el margen se suma; el middle-inset sobresalia 16 a la derecha). Reportado en el showroom: el specimen llegaba al borde del padre. Check 65 invertido: la presencia de inline-size en la base es la falla |

## 6. Capa de tokens

```
css/md/tokens.css    entry: vendor (sin colors.css) + additions.css
css/md/additions.css los 8 roles que el vendor no trae (post-2023)
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
la copian text field, FAB y los actions de card. Divider sube tras
foundations: cero dependencias y lo consumen card, menu y lists.

```
Base components: divider (sin dependencias; antes de sus consumidores)
Actions: button (+ icon-only, FAB, destructive)
Inputs: checkbox, radio, switch (cero deps) -> text field -> select (pide text field + menu) -> file input
Containment: card, menu (menu-item propio, no list-item: decision 23), list, dialog, snackbar
Navigation: top bar, nav bar, drawer, rail, tabs
```

Notas: `Destructive` enlaza a `button.html` a proposito (modificador sin
pagina propia, plantilla de §4), no es duplicado. Menu va antes que List:
en el vendor `menu/` y `list/` son paquetes separados y menu define su
propio `MenuItem` (solo comparte el tipo `ListItem`). Correcciones a un
analisis externo: `Paper` no existe en M3 (es vocabulario de MUI), Badge
esta fuera de scope, y su esquema se contradice solo (Select en capa 3
pidiendo Menu de capa 4).

## 8. Verificacion

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify-tokens.ps1
```

| Check | Detecta |
|---|---|
| Referencias rotas | `var()` sin definir ni en `css/` ni en vendor/ |
| Duplicados | Mismo token namespaced (`--md-*`, `--rdm-*`) en 2+ archivos propios; el API sin prefijo (`--layer`) vive en cada componente |
| sys incompleto | Un rol de superficie sin light o sin dark |
| Fugas de capa | `comp/`, `rdm/`, `primitives/` o `demo/` leyendo `--md-ref-*` (prohibido) |
| DSP consumido | `var()` a `-value`, `-unit` o `axis-value` (ruido de Figma) |
| Imports | Todos los `@import` relativos resuelven a archivo existente; se saltan los `https://` |
| Texto pelado | Ningun `<p>` ni `<h1-h6>` sin clase en los `.html` |
| Fuente conectada | `--md-ref-typeface-plain/-brand` (valor efectivo) cargada via `<link>` en los HTML |
| Shape sin ruido | Ningun `-family` consumido en `var()` (todos valen 1px o 3px, basura DSP) |
| Niveles sys intactos | Ningun `--md-sys-elevation-levelN:` declarado en CSS propio (son dp del vendor; sombras en `--rdm-shadow-*`) |
| Swatches identicos | Ningun run de 3+ `<div>` hermanos con misma clase Y mismo contenido (wrappers con distinto texto no forman racha) |
| Container en paginas | Todo `.html` de raiz usa `.rdm-container` (ningun showroom de lado a lado) |
| State sin ruido | Toda opacidad `--md-sys-state-*-state-layer-opacity` propia vale 0.08, 0.10 o 0.16 exactos (sin ruido Figma ni 0.12 de M2) |
| Motion con tokens | Ningun `transition`/`animation-duration` con duracion literal en CSS propio (todo pasa por token; el bloque reduced-motion se excluye) |
| Iconos con primitiva | Ningun HTML usa la clase generica de Google (`.material-symbols-*`); todo icono pasa por `.rdm-icon` |
| Spacing con tokens | Ningun `padding`/`margin`/`gap` con valor literal en `css/comp/` (todo pasa por `--rdm-measurement-*`; cero y auto permitidos) |
| Roles con tema | Todo `--md-sys-color-*` propio declarado 2+ veces (light y dark) |
| Chrome fuera de demo | Ningun `css/demo/` pinta `header`/`section`/`main` (la estructura la daran los componentes) |
| Showroom por componente | Cada `css/comp/*.css` tiene su `<nombre>.html` en la raiz |
| Grupo invisible | `button-group.css` sin `background-color`, `color`, `border` ni `box-shadow` (container sin visuales) |
| Chrome compartido | Todo `.html` de raiz linkea `css/demo/showroom.css` y tiene ≥1 `<section>` |
| Divisores ad-hoc | Ningun `css/demo/` declara `border-top` (viven en `css/comp/divider.css`) |
| Toggle con contrato | Todo `.rdm-icon-button--toggle` lleva `aria-pressed` (sin atributo no hay selected) |
| Divisores por seccion | En toda pagina, `<hr class="rdm-divider">` ≥ secciones − 1 |
| Un componente por archivo | La primera clase `.rdm-*` de cada regla pertenece a la familia del archivo |
| Destructive con error | Toda regla `.rdm-button--destructive` solo consume familia `error` (`error*`, `on-error*`) |
| Sin acciones anidadas | Ninguna seccion con `.rdm-card--interactive` contiene `<button>` ni `<a href>` |
| Card en bloque | `.rdm-card` declara `display: block` (un `<a>` inline se fragmenta por line box) |
| Contraste contenido en card | Todo boton con fondo propio dentro de `.rdm-card--*` da 3:1 (fondo vs fondo) en light y dark, con tokens leidos del arbol real |
| Inline con caja | Toda regla `inline-*` de `css/comp/` declara `vertical-align: middle`, nunca `baseline` |
| Disabled interactivo con contrato | Todo `.rdm-card--interactive` con `.rdm-card--disabled` lleva `aria-disabled="true"` |
| Base sin estados | Ninguna `.rdm-card` no-interactive lleva `.rdm-state-layer`; `cursor: pointer` solo en `--interactive` |
| Un solo tab stop | Ninguna card no-interactive lleva `tabindex` ni `role` |
| Anillo de foco | La primitiva declara el focus indicator (`secondary` 3px, offset 2px) en `:focus-visible` |
| Shape post-2023 | Los 3 niveles ausentes en el vendor existen en `css/` propio con valor exacto (20/32/48) |
| Medidas de card | La tabla Specs de `card.html` lista los 4 valores que publica `cards/specs` (12dp, 16dp, 8dp max, start-aligned) |
| Inset alineado | El inset del divider usa el mismo token que el padding del contenido de card (decision 12) |
| Container sin padding | La base `.rdm-card` no declara padding (vive en `.rdm-card-content`, opcion A) |
| Container que recorta | La base `.rdm-card` declara `overflow: hidden` (el radio solo recorta con overflow) |
| Elevacion de card | La tabla Elevation de `card.html` coincide con los niveles de material-web (reposo/hover/focus/pressed/dragged por variante) |
| Vendor con licencia | Todo archivo bajo `vendor/` cubierto por Apache 2.0 (cabecera propia o LICENSE en su carpeta o superiores) |
| Fila de acciones | `.demo-card-actions` alinea a la derecha con gap de token (decision 15, no literal) |
| Sin margenes UA | `p`, `h1-h6`, `ul` y `ol` llevan `margin: 0` en `base.css` (ritmo 100% de tokens) |
| Ritmo con token en demo | Ningun `css/demo/` usa `em` en `margin*` ni `padding*` (heredado de v0.51; desde v0.56 todo `margin` de demo vale 0) |
| Specimens tipograficos | `typography.html` enlaza su demo CSS y cada rol vive en `.demo-type` (flex + gap 8 del padre, sin reglas en hijos) |
| Demo CSS por foundation | Las 10 paginas de foundations linkean su `css/demo/<pagina>.css` (`layout.html` era la segunda sin demo CSS) |
| Escala aritmetica | Todo `--rdm-measurement-NNN` cumple `8 x NNN/100` exacto y estan los 17 (rango 0x-9x + 4 nested + 150/250 propios) |
| Origen distinguido | La tabla de `spacing.html` marca `measurement-150` y `measurement-250` como extension del proyecto (la spec solo define los nested que usa) |
| Reset propio | `base.css` resetea los ~20 elementos con defaults del UA vivos (decision 17, sin normalize) |
| Tablas con patron | Toda `<table>` del showroom lleva `demo-table` (18 en 11 paginas, ninguna depende del UA) |
| Ritmo en cero | Ningun `css/demo/` salvo `showroom.css` declara un `margin` distinto de 0 (18 reglas, decision 18; el ritmo de pagina lo custodia el check 62) |
| Divider unico | Ninguna `section` lleva margen; el gap entre secciones lo da el `hr` con sus 8/8 del componente |
| Contrato de spacing | Ninguna regla de `css/comp/` declara `margin` (divider exento: separar es su funcion) |
| Spacer de layout | `.rdm-spacer` existe en `css/rdm/` con token e import, base 400 + modificadores 600/900 |
| Breakpoints | `layout.html` publica los 5 con sus anchos exactos, sin el nombre viejo |
| Grid de 8 | `layout.html` publica 8 columnas; el 12 no aparece |
| Max-width en expanded | `--rdm-layout-max-width` entre 840 y 1199px |
| Tablas con ejemplo | Toda seccion de showroom de componente con `<table>` tiene >=1 specimen del propio componente (las medidas se muestran, no solo se listan) |
| Anatomy con specimen | Toda seccion Anatomy tiene >=1 specimen del componente (referencia visual, no parrafo) |
| Container del menu | `.rdm-menu` con min 112, max 280, radio extra-small, surface-container, level2 y padding-block con token |
| Ritmo con token | Toda declaracion `margin`/`padding` en `showroom.css` usa `var(--rdm-measurement-*)`, sin literales |
| Estructura | 1 barra y 1 intro por pagina, `h1` dentro de `main` y fuera de la barra |
| El padre declara | `section` e `intro` con flex + gap con token; ningun hijo declara `margin` en `showroom.css` ni en `demo/` |
| Medidas del divider | Inset 16/0, middle 16/16, thickness 1px, outline-variant, block 8 (4dp y right-8 pendientes de Lists) |
| Aire entre secciones | `main > hr` con margin de layout (separadores); specimens y nav fuera |
| Menu item | 56/72, padding 12/16, gap 16, transparent, selected (12 en measurement-150, extension) |
| Medidas sin auditoria | Ninguna tabla Medida/Valor declara Estado (card conserva el suyo: permitido/prohibido por fila) |

Corre en cada commit de la capa de tokens. Estado actual: 68/68 en verde.

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
  de Tab. Check 14: opacidades propias exactas (0.08/0.10/0.16),
  probado contra valor con ruido (corregido en v0.37: el 0.12 era M2).
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
- **v0.17** - Icons: primitiva `.rdm-icon` en `css/primitives/` (Rounded,
  `font-optical-sizing: auto`, tamano desde `--rdm-icon-size: 24px` en
  `project.css`, GRAD 0 en light y -25 en dark por spec). Hallazgos contra
  la pagina oficial (leida con browser): escala 20/24/40/48 (el 18px es
  escala de componente, bajo el minimo optico), baseline 11.5%, target
  48px para glifo 24px, grade como estado activo, y Rounded validado
  ("rounded buttons and round icons"). Correciones a la propuesta externa:
  `body-large-size` vale 16px (no 24px), outlined/sharp son familias no
  ejes, ejes completos solo en `icons.html` (el resto recortado), y reglas
  ARIA documentadas. Check 16: ninguna clase generica de Google en HTML,
  probado contra span con clase generica.
- **v0.18** - Solo documentacion (sin codigo): decision #9 "M3 core, no
  Expressive" en §5 con su tabla, correccion de la nota de springs en
  `additions.css` (existen para Web por conversion, ninguna exportacion
  CSS los emite, son device-relativos) y pendientes de springs + Button.
  Origen: lectura con browser de la spec de Buttons (icono 20dp, no 18dp;
  padding 24dp confirmado para core; mapeo de color de la spec con 2
  diferencias vs Material Web; radios Full; elevated 1/0 disabled) y de
  Motion physics (los springs reemplazan duration+easing; Web convierte
  desde Compose). Retractacion: el padding 24dp NO estaba deprecado,
  16dp es solo Expressive.
- **v0.19** - Spacing: escala `--rdm-measurement-*` en `project.css` (0 a 400:
  recomendados 100-400 mas nested 2/4/6/10 y ejemplos measurement125/measurement225,
  resto por multiplicador). Correccion a v0.14: el sistema SI es spec,
  los tokens son Compose-only (Web Unavailable). `spacing.html` con tabla,
  9 barras visuales, modelo padding/gap/margin y consumo por mapeo.
  Decision #10 en §5 (misma nomenclatura para migracion 1:1). Check 17:
  ningun padding/margin/gap literal en `css/comp/`, probado contra
  componente temporal.
- **v0.20** - Color: `surface.html` reescrito como `color.html` (absorbe
  los 9 roles, suma pares de acento, outline, inverse y tabla fixed).
  Censo verificado contra la spec: 26/26 estandar completos; dim/bright
  ya estaban; inverse/shadow/background en vendor; fixed (12) sin tokens
  por seed-dependientes, solo tabla. Retractacion: el bug de surface-dim
  dark NO existia (neutral10 es #1c1b1f, dim #141218 es mas oscuro,
  verificado en la paleta). Check 18: todo color propio con light+dark,
  probado contra rol solo-light. Hallazgo del check 2 al correr:
  outline-variant NO existia (vendor solo trae outline); agregado a
  additions.css en ambos temas (neutral-variant80/30, verificado v1.18).
  Octavo rol post-2023.
- **v0.21** - Motion transitions: 3 secciones nuevas en `motion.html`
  (tabla de 6 patrones, modelo espacial, notas). Retractacion: no son
  4 patrones, son 6 (el 4 venia de M2). Sin recetas numericas porque la
  spec no las publica en web. Sin check nuevo: documentacion pura.
- **v0.22** - Button: `css/comp/button.css` (base + 5 variantes) y
  `button.html` (variantes, con icono, states, anatomia). Consume las 7
  fundaciones de una vez; primer `css/comp/` no vacio. Decisiones:
  mapeo de la spec (elevated surface-container-low + primary, outlined
  borde outline-variant + label primary por codigo de Material Web),
  disabled 12%/38% por spec via color-mix (no el 38% plano anterior),
  tipografia por composicion con la primitiva (refina decision 8),
  icono 20px, sin anillo de focus propio. Fuera de alcance: destructive,
  icon-only, trailing icon, FAB. Check 19: ningun demo pinta
  header/section/main, probado contra seccion con fondo (mas TrimStart
  del BOM: Set-Content escribe EF BB BF y en .NET no matchea \s). Hallazgo del
  check 3 al correr: --layer en button.css y demo/state-layer.css NO es
  duplicado (es API de componente, muchos hogares); check 3 refinado a
  solo namespaced. Guia de decision en button.html (enfasis 3 niveles,
  placement, semantica outlined/elevated) e indice con los 10 tipos.
- **v0.23** - FAB: `css/comp/fab.css` (medium 56 + large 96 + extended) y
  `fab.html`. Default primary-container por spec (surface es baseline no
  recomendado; correccion a la lectura de tokens v0_192). Elevacion 3 con
  hover en 4: unico componente que levanta. Extended con padding 16/20 y
  gap 12 de la implementacion (sin tokens comp). Small es baseline, no se
  construye. Focus/pressed 12% por sys (spec dice 10%, pendiente).
  measurement-150 y measurement-250 por regla del multiplicador. Check 20: showroom
  por componente, probado contra css sin html. Fix post-entrega: fab
  States tenia 1 solo disabled sin nada interactivo; ahora lleva enabled
  + dragged + texto de prueba en vivo. Regla: toda seccion States lleva
  al menos un enabled en vivo (live con pseudo-clase, modificador sin
  ella, tabla si es dato). Fix extended-fab Label: el caso sin icono se
  veia corrido por la asimetria 16/20 (espec: equilibra el icono); se
  muestra solo el caso principal y la asimetria queda documentada, sin
  inventar padding simetrico.
- **v0.27** - Icon button: `css/comp/icon-button.css` (40px round, 4 estilos + toggle) y `icon-button.html`. Mapeo de tokens v0_192: selected de outlined = inverse-surface (no adivinado). Toggle sin JS: estados CSS sobre aria-pressed, specimens fijos, sin checkbox-hack. Icono 24px, disabled 12%/38%. Check 24: todo toggle con aria-pressed, probado contra toggle sin atributo. Render en localhost: toggle filled #6750A4, outlined inverse #313033. Hallazgo del render: botones a 33px por em sobre font-size UA (bug latente tambien anterior); geometria a rem, decision 7 enmendada. Leccion: el navegador cachea los @import (ni ?v= en el entry los refresca); render con archivos frescos o fetch no-store. Fix post-entrega: icon-button.html salio sin divisores (v0.26 migro lo existente); check 25 exige hr >= secciones - 1, probado contra pagina sin divisores.
- **v0.28** - Extended FAB promovido a `css/comp/extended-fab.css` + `extended-fab.html` (baseline 56px, con/sin icono, states, rules). Los 3 tamanos son Expressive; type de label-large a title-medium solo ahi. Icono opcional, nunca sin label; 1 por pantalla; margenes 16dp; sin tooltip; aria-label con prefijo. Check 26: un componente por archivo (primera clase de cada regla), probado contra clase ajena. Fix post-entrega: caso sin icono se veia corrido (asimetria 16/20 por diseno); solo caso principal, sin padding inventado.
- **v0.29** - Destructive: `.rdm-button--destructive` en 4 variantes (text, outlined, tonal, filled) con roles error, demo en Semantics de button.html. No es tipo M3 (ausente en las 10 + guidelines + dialogs: 0 matches); es aplicacion del rol error (urgencia) con 3:1 y label que nombra la accion. Excluye FAB y elevated. Check 27: destructive solo con tokens error*, probado contra rol primario.
- **v0.30** - Card: `css/comp/card.css` (elevated/filled/outlined, shape 12dp, padding 16dp) y `card.html` (variantes con botones reales, interactive como link, specs, rules). Opcion A: no-actionable por defecto, interactive sin botones dentro (HTML invalido). Enfasis real outlined > elevated > filled. Elevacion estatica (sin valores dinamicos verificados). Reset de links con (0,1,1). Check 28: sin acciones anidadas, probado contra boton dentro de interactive.
- **v0.31** - Card fix display: `.rdm-card` con `display: block`. El `<a>` interactive era inline y se fragmentaba por line box (fondo y radio partidos, layer del hover cortado). En `div` es no-op. Check 29: card en bloque, probado quitando la linea. Leccion: medir propiedades no caza cajas rotas; verificar tambien `display`.
- **v0.32** - Card contrast: action area al modelo M3 (filled + icon standard, sin tonal). Tabla Contrast con ratios medidos del arbol real: tonal 1.00-1.84 y elevated 1.00-1.39 dentro de cards, prohibidos; filled/text/outlined/icon permitidos (borde outline-variant con clausula Caution). Check 30 card-scoped: resuelve palette+themes+additions y exige 3:1 fondo-vs-fondo en ambos temas; el tonal sobre surface pagina (1.26) es baseline M3, no bug. Regla en Rules.
- **v0.33** - Card actions: 2 botones de texto por card (filled + outlined; outlined en vez de text para no confundirse con linked text del supporting text) + subhead (title-small) en las 3 variants. Fila flex con gap de token 16 en demo (el whitespace de 3px no lo controla ninguna regla). `vertical-align: middle` en los 4 inline (button, icon-button, fab, button-group): el glifo deriva la baseline 8px, middle alinea por caja. Anatomy con las 6 partes; overflow menu pendiente de Menus. Check 31: inline con caja, probado contra regla sin vertical-align.
- **v0.34** - Card tokens y disabled: seccion Tokens con valores reales de la spec (enabled + states) marcando filas abiertas y huecos de extraccion. `.rdm-card--disabled` (container 0.38, outlined borde outline 12%, sin layer) + demo filled con botones disabled e interactive disabled con aria-disabled. Icono primary 24dp ilustrado en Anatomy con probe demo-card-icon (.rdm-icon ya mide 24px). Comentario de state corregido en additions.css y delta #FEF7FF anotado. Abiertas: focus indicator reservado v0.38 (pasada transversal button/icon/fab/card). Check 32: disabled interactivo con contrato, probado sin aria-disabled.
- **v0.35** - Card paso 1 (anatomia): showroom reordenado por anatomia. Variants con 3 containers vacios (aria-label) y Disabled sin botones; demo de icono retirada (vuelve en su paso, el probe demo-card-icon queda). Regla de actions movida al paso 6. Sin refactor de padding: espera medidas de media (paso 4). Check 30 pasa en vacio hasta el paso 6. Sin cambios de script: 32/32. Nota: el check 12 cuenta divs identicos en orden de documento (no hermanos reales); el wrapper unico de Disabled se elimino por redundante y para no formar racha de 3. En v0.36 el check 12 excluye `demo-*` (wrappers de layout, no specimens).
- **v0.36** - Card paso 2 (texto) + a11y: seccion Text con caso completo (headline+subhead+supporting) y minimo (sin subhead). Fix spacing entre cards 16→8 (`measurement-100`); actions se queda en 16. Texto interactive corregido (rol link: Enter si, Space no). Check 33: base sin estados (sin layer, cursor pointer solo en interactive). Check 34: un solo tab stop (no tabindex/role en no-interactive). Focus indicator pasa a v0.38.
- **v0.37** - State 0.10: focus/pressed pasan de 0.12 a 0.10 (pagina de fundamentos state-layers + tabla de Card; el 0.12 era M2 arrastrado por el vendor). Toca los 4 componentes con layer via token, sin reglas por componente. Check 14 corregido a 0.08/0.10/0.16. Hallazgo para v0.38: layer 40dp vs target 48dp (el `inset: 0` de la primitiva no distingue).
- **v0.38** - Focus indicator transversal: anillo secondary 3px offset 2px en `:focus-visible` dentro de la primitiva (los 4 componentes lo heredan; el outline sigue el radio de cada uno). Sin hit-slop de 48dp (decision de proyecto: anillo al borde visible + 2px). Outlined interactive: borde a on-surface en focus (unico estado donde el outline se mueve) + demo outlined en Interactive para verificarlo. Check 35: anillo presente, probado quitando la regla.
- **v0.39** - Auditoria de baseline: vendor shape con 7 de 10 niveles (faltan large-increased 20, extra-large-increased 32, extra-extra-large 48; ningun valor mal, solo huecos). Agregados en additions.css con el patron del vendor; shape.html con los 10 + advertencia no-large/full-en-densas en Rules de card. Resultado: state contaminada (M2, corregida v0.37), shape incompleta (corregida), elevation/motion/color OK. Sombras M3 pendientes (distancias OK, recetas M2). Check 36: shape post-2023 con valor exacto, probado quitando un token.
- **v0.40** - Decisiones 11 y 12: medidas solo del container (12/16/8dp/start) y media libre por diseno; inset divider = padding 16dp por inferencia. La tabla de `cards/specs` renderiza con 4 filas; un analisis externo que afirmaba que M3 elimino las specs de card no se sostiene contra la fuente primaria, y sus numeros de media (16:9, 80x80, edge-to-edge) no tienen cita. Anatomy marca el paso 4 como libre por diseno en vez de bloqueado. Check 37: los 4 valores en la tabla Specs.
- **v0.41** - Card paso 3 (dividers): seccion Dividers con full-width (rompe el padding via clase demo, solo staging hasta el paso 4) e inset (divider base: el padding alinea solo). Decisiones 13 (elevacion solo del container) y 14 (bloques con enfasis; padding del contenido, 3 fuentes). Regla en Rules. Check 38: inset alineado al padding, probado cambiando el padding.
- **v0.42** - Card paso 4 (media) + refactor opcion A: padding movido de `.rdm-card` a `.rdm-card-content`; la media queda fuera del wrapper y sangra al borde. Specimens edge-to-edge y contenida (altura 10rem libre, sin sombra, radio heredado). Variants y Disabled migran a contenido minimo (el container vacio colapsa a 0: prueba empirica de la decision 11). Convencion elemento/modificador en SKILL + check 26 extendido. Check 39: container sin padding. Hallazgo: `·` mojibakeado como `Â·` en card.html (18 casos, reparado a byte con BOM intacto); `edit` escribe limpio.
- **v0.43** - Card recorta: `overflow: hidden` en `.rdm-card` (el radio solo recorta con overflow; el outline propio no se ve afectado). Media edge-to-edge sin radio (recorta el container) y divider full-bleed estructural entre bloques (eliminado el truco de margenes negativos). Regla: radio propio solo si la media no toca el borde. Check 40: container que recorta, probado quitando el overflow.
- **v0.44** - Auditoria contra material-web (labs/card + tokens v0_192 en vendor/material-web-tokens, 6 archivos byte-exactos, Apache 2.0): la elevacion NO es estatica, correccion a v0.30/v0.35. Dinamica por variante (elevated 1-2-1-1-4, filled/outlined 0-1-0-0-3) solo en interactive, con transicion short3+standard; orden hover, focus, active, dragged. Disabled con colores reales (elevated surface, filled surface-variant: resuelve el pendiente de surface-variant). Google no implementa hover/pressed/disabled en labs (2 TODOs): nuestro interactive/disabled son construccion propia. labs SCSS solo mapea tokens, sin geometria: la nuestra es propia. Check 41: tabla Elevation contra vendor, probado cambiando un nivel.
- **v0.45** - Dos vendors: LICENSE Apache 2.0 copiado byte-exacto + README en material-web-tokens; nota en tokens.css (los .scss nunca se importan); decision 4 extendida (dos procedencias, dos capas, dos generaciones: no se unifican). Check 42: todo archivo bajo vendor/ cubierto por licencia, probado con archivo huerfano.
- **v0.46** - stories.ts de labs en vendor (byte-exacto, 6278 bytes): confirma padding-16 y gap-16 en content, img height-128 sin aspect-ratio, border-radius inherit y un solo boton filled. Refuta el analisis externo de 3 zonas con flex-end y gap 8 (sin avatar, sin alineacion, sin par tonal+filled). Decisiones 11/14, opcion A y v0.43 suben de diagrama a codigo ejecutable de Google. Sin cambios de CSS ni checks: 42/42.
- **v0.47** - Referencia visual de anatomia: seccion Anatomy con card compuesta (media + headline + subhead + supporting con linked text + icon + outlined + filled, todo real). Fila a flex-end con gap 8 (decision 15: sin fuente, del 8dp max publicado). Check 43: fila con token, probado con gap literal.
- **v0.48** - Anatomia en las 3 variantes: misma composicion (media + texto + linked text + icon + outlined + filled), solo cambia el modificador. El action area es identico porque los 3 botones pasan 4.5:1 en las 3 superficies; tonal y elevated fuera por regla. Sin CSS ni checks nuevos: el check 30 ya valida los 9 botones. 43/43.
- **v0.49** - Rotulos de variante en Anatomy: cada referencia lleva su nombre fuera de la card (title-medium, por convencion de swatches); la composicion interna queda intacta. Sin cambios de CSS ni checks: 43/43.
- **v0.50** - Reset de margenes UA: p, h1-h6, ul y ol con margin 0 en base.css (el ritmo era mitad UA); content de card a flex column con gap 16 (stories.ts). Rotulos uniformes a 8. Check 44: sin margenes UA, probado quitando el reset. Render en typography, spacing y motion.
- **v0.51** - Ritmo de showroom con tokens: h2 separa 16, p apilados 8, header 8 en showroom.css; 13 margin-bottom y 5 padding de 1em a measurement-200 en demo/. El 1em escalaba con el font-size (57px de aire en display-large). Check 45: sin em en margin/padding de demo, probado con 1em trampa.
- **v0.52** - Specimens tipograficos: typography.html era la unica pagina sin demo CSS (16 p pelados en section). Nuevo demo/typography.css con .demo-type (8 dentro del par nombre+spec, 16 entre specimens) y los 15 roles envueltos. Check 46: link + ritmo de pares, probado sin wrapper.
- **v0.53** - Ritmo plano documentado (decision 16): M3 publica 5 propiedades por rol y cero spacing; half-leading absoluto-plano (2-4px) con ratio decreciente (1.5 a 1.123): un margen proporcional iria contra M3. Seccion Teoria en typography.html con tabla de ratios. layout.html tapado: nuevo demo/layout.css (tabla con ritmo, container real anidado como specimen). Check 47: las 10 foundations linkean su demo CSS, probado sin link.
- **v0.54a** - Escala de spacing completa: la spec publica el rango 0x a 9x (alt del diagrama de tokens) y nosotros parabamos en 400. Agregados measurement-500 a measurement-900 (40 a 72dp) en project.css, con sus 5 barras y 5 filas. Tabla de spacing.html con Origen distinguido: 10 del rango principal + 4 nested M3 + ejemplo oficial del multiplicador (225) + 2 extensiones del proyecto (150, 250). Check 48: escala aritmetica parseada (8 x N/100 + los 17 presentes), probado con token mal calculado. Check 49: 150 y 250 marcados como extension, probado sin marca.
- **v0.54b** - Rename a measurement: el token oficial es md.sys.measurement.space100, asi que el namespace anterior (space) pasa a --rdm-measurement-* (118 ocurrencias en 25 archivos), specimens a demo-measurement-bar--* y etiquetas a measurement-NNN. Las citas literales de la spec (space225 = 18dp, leading space) se conservan como las escribe M3. El historial anterior se lee con el nombre nuevo. Sin checks nuevos: el check 1 (referencias rotas) caza cualquier var() huerfano, probado con grep a 0.
- **v0.55** - Reset propio ampliado (decision 17, sin normalize): la sonda encontro ~20 elementos con defaults del UA vivos (button Arial 13.33px, th centrado con padding 1px, h1 28px/700, blockquote/figure 14px 40px). base.css pasa de 9 a 17 elementos reseteados, cada regla con motivo. Patron .demo-table en css/demo/table.css para las 18 tablas de 11 paginas (las 16 sin clase dependian del UA); layout y typography pierden su regla local; button.demo-state-layer pierde font/border redundantes. Check 50: reset por elemento, probado sin h1. Check 51: toda tabla con clase, probado desclasando una.
- **v0.56** - Reset total del ritmo a cero (decision 18): los 5 niveles de pagina (header 32/8, h2 16, p apilados 8, section 32) y las 18 reglas de specimens a margin 0 en 14 archivos demo. El caso que lo motivo: 41px medidos entre secciones (32 de section + 8 del hr, escritos en v0.25 y v0.26 sin cruzarse). El hr conserva sus 8/8 (son del componente). Check 52: ritmo en cero (23 reglas), probado con margin trampa. Check 53: section sin margen y hr con aire, probado con section con margen.
- **v0.57** - Contrato de spacing (decision 19): componentes = padding + gap del padre, layouts = margin + spacer, hijos sin margin jamas (Do/Don't textual de la spec). spacing.html con Model ampliado (listas componente vs layout), seccion Rules, extremos de escala verificados contra el alt (2/4/6/8 y 48/56/64/72 calzan), seccion Spacer con 3 specimens y Audit del boton en button.html (su showroom: cada showroom solo muestra su componente). Conclusion del audit: horizontal coincide, vertical derivado, small falta; se documenta, no se corrige. Nuevo .rdm-spacer en css/rdm/ (400 + 600/900). Check 54: comp sin margin (divider exento), probado con margin trampa. Check 55: spacer con token e import, probado sin import.
- **v0.58** - Layout contra la spec actual (decision 20): la spec renombro window size classes a breakpoints en mayo 2026. layout.html con 5 breakpoints (tabla oficial con panes), Scaffold (bar/rail/pane sin CSS), Grid de 8 (dato, sin CSS), Margin (definicion + mapeo) y Measure (regla 40-60 + tabla medida: 147 chars a 1200 en body-large). max-width 1200 a 1024 (dentro de expanded) + 4 tokens de breakpoint como limites inferiores. Check 56: 5 breakpoints con anchos, probado sin Large. Check 57: 8 columnas sin 12, probado con 12. Check 58: max-width en expanded, probado con 1300.
- **v0.59** - Showrooms sin documentacion (decision 21): salen 6 secciones de guia (button Emphasis/Placement/Audit con 0/0/1 specimens, card Rules, button-group Expressive, extended-fab Rules). El contenido se preserva en el apendice (seccion 11). Specimens agregados a las 4 secciones de medidas que no tenian (card Contrast/Tokens/Specs, button-group Measures). Check 59: tabla con ejemplo, probado con seccion sin specimen.
- **v0.60** - Anatomias visuales (decision 22): las 4 secciones Anatomy en texto pasan a referencia compuesta (button filled con icono, fab en 2 tamanos, extended-fab, icon-button standard + toggle selected). El texto original queda en el apendice. Check 60: Anatomy con specimen, probado sin specimen.
- **v0.61** - Menu paso 1, container (decision 23): vendor con los 2 archivos byte-exactos (wrapper + values v0_192). `.rdm-menu` con surface-container, level2, extra-small, min 7rem, max 17.5rem y padding-block con token. menu.html con seccion Container (vacio=min 112, texto largo=max 280) e index enlazado. Check 61: container con medidas, probado sin max-width.
- **v0.62** - Estructura de showroom (decision 24): barra minima (marca + link a index, sin nav rail) e intro de pagina en main en las 18 paginas. Ritmo con token en showroom.css (barra 32, intro 16, h2 16, p 8, bordes opuestos en 0). Check 52 exime a showroom; nuevos 62 (ritmo con token) y 63 (1 barra + 1 intro, h1 en main), probados sin token y sin intro.
- **v0.63** - El padre declara el ritmo (decision 25): section con flex + gap 16 e intro con flex + gap 8 en showroom.css; .demo-type y .demo-card-spacing con flex + gap 8. Se borran las 3 reglas de margin en hijos (con gap sumarian). p+p pasa de 8 a 16 (era nuestro, no spec); tablas a ancho completo por stretch. Check 46 al gap del padre; nuevo 64 (padres con gap, hijos sin reglas), probado en ambas direcciones.
- **v0.64** - Divider con medidas de spec (decision 26): vendor con wrapper (878b) + values (720b) byte-exactos; cero cambios de valores (ya coincidian). Comentario documentando top-8 simetrico y vertical inline-8 como decisiones. Tabla Measures con Estado (4 coinciden, 2 pendientes Lists). Check 65: 7 pares medida/flag, probado sin inset.
- **v0.65** - Aire entre secciones (decision 27): `main > hr.rdm-divider` con margin-block 200 en showroom.css (total 33). El 8/8 del componente intacto; specimens y nav fuera por selector. Check 66: aire de layout, probado sin regla.
- **v0.66** - Indice por dependencia (decision 28): Divider sale de Containment a seccion propia `Base components` tras foundations (solo indice, el CSS no se mueve). Inputs por dependencia (checkbox/radio/switch primero, select ultimo). Containment con menu antes que Lists. Sin check nuevo: reordenacion de indice y docs; 66/66.
- **v0.67** - Menu paso 2, item (decision 29): vendor de 3 archivos byte-exactos (3233/4595/4417b). `.rdm-menu-item` con 56/72, padding 12/16, gap 16, transparent, selected y disabled 0.3. Tabla Measures con Estado (12 coinciden, 1 fuera de scope). Correccion: el alto es 56, no 48. Check 67: 8 pares medida/flag. 67/67 en verde.
- **v0.68** - Medidas sin auditoria (decision 30): tablas de menu (13 a 7 filas) y divider (6 a 4) a Medida/Valor; notas de derivacion a §11. Card y state-layer conservan su Estado (ahi es dato). Check 68: sin patron Medida/Valor/Estado, probado re-agregando la columna. 68/68 en verde.
- **v0.69** - Fix divider sin ancho (decision 31): sale `inline-size: 100%` de la base (overflow con margin; el middle-inset llegaba al borde). Check 65 con guarda ANCHO-FIJO, probado re-agregando el 100%. Render: inset 16/0, middle 16/16. 68/68 en verde.
- **v0.57a** - Fix: el Audit del boton estaba en spacing.html y viola la regla de showroom (cada pagina solo muestra su componente). Movido a button.html como seccion Audit; spacing.html queda con 6 secciones de spacing puro.
- **v0.48** - Anatomia en las 3 variantes: misma composicion (media + texto + linked text + icon + outlined + filled), solo cambia el modificador. El action area es identico porque los 3 botones pasan 4.5:1 en las 3 superficies; tonal y elevated fuera por regla. Sin CSS ni checks nuevos: el check 30 ya valida los 9 botones. 43/43.
- **v0.26** - Divider: `css/comp/divider.css` (full/inset/middle-inset/vertical, 1px outline-variant) y `divider.html`. Inset 16 solo izquierda (la tabla dice 16/0, middle 16/16). Chrome migrado: 45 `<hr>` entre secciones (+1 escrito a mano), border-top fuera de showroom.css. Check 23: sin border-top en demo, probado contra borde agregado.
- **v0.25** - Chrome compartido: `css/demo/showroom.css` (ritmo vertical
  measurement-400 + divisores outline-variant 1px, sin background-color) linkeado
  en las 13 paginas. Card descartado como chrome (no es un subject).
  Check 19 relajado a lo que ya hacia (solo fondo); check 22 nuevo: toda
  pagina linkea showroom.css, probado contra pagina sin link.
  Fix post-v0.25: index tenia el link pero 0 secciones (el check solo
  miraba el link); selector a .rdm-container section, 5 grupos en
  section conservando nav, check 22 con ≥1 seccion.
- **v0.24** - Button group container: `css/comp/button-group.css` (solo
  `display: inline-flex` + gap 2dp) y `button-group.html` (demo Walk/Bike/
  Drive, tabla de medidas, aviso Expressive). Standard no existe en core;
  connected solo como segmented (no recomendado). Medidas guardadas.
  Check 21: grupo invisible (sin color/fondo/borde/sombra), probado
  contra fondo agregado.

## 10. Decisiones pendientes

- [x] Peso mediano con Google Sans: **500** segun spec M3 (resuelto en v0.8; 475 es lo que shippea Google, descartado).
- [x] `surface-variant` en depreciacion: se usa para filled disabled por material-web (v0.44). Era token real, no alias.
- [ ] Easing y duraciones de motion por componente: los tokens existen (45 en `motion.css`), falta mapearlos al construir cada componente. `160ms` no es token M3.
- [ ] Zona header/avatar de card y taxonomia de actions: documentadas en la libreria anterior, aplicar al construir Card.
- [ ] `--md-sys-elevation-surface-tint-color`: token M3 real del vendor (tinta primaria sobre superficies elevadas), hoy sin consumir. No es sombra ni nivel; evaluar cuando un componente necesite tinte de elevacion.
- [ ] Springs de M3 Expressive: 2 esquemas (expressive, standard) x 2 tipos (spatial con rebote: posicion, rotacion, tamano, radio; effects sin rebote: color, opacidad) x 3 velocidades (default, fast, slow). Criterio por tamano: componentes chicos (switches, buttons) = fast, bottom sheet = default, fullscreen = slow. Todo componente corre con fast spatial + fast effects. Sin tokens en ninguna exportacion CSS; la pagina Specs explica la conversion desde Compose.
- [x] Button (resuelto en v0.22 con mapeo de la spec; label outlined = primary por codigo de Material Web).
- [ ] Botones restantes (6 de 10 tipos): icon button, toggle icon button, split button, standard/connected groups, FAB menu. Toggle button es Expressive (fuera de scope). FAB hecho en v0.23.
- [x] Divider (resuelto en v0.26).
- [x] Anatomia inconsistente: resuelto en v0.60 (referencia visual compuesta en los 5; el texto original queda en el apendice).

## 11. Apendice: guia movida de showrooms (v0.59)

Contenido que vivia en showrooms de componentes y viola la decision 21. Se preserva aca con su motivo; los showrooms muestran ejemplos y medidas.

### Niveles de enfasis (ex `button.html`, seccion Emphasis)

M3 ordena los 10 tipos por enfasis. Filled, tonal y elevated comparten funcion (Save, Confirm, Done): se elige por cuanto deben atraer la atencion, no por que hacen.

| Enfasis | Componentes | Ejemplo |
|---|---|---|
| Alto | Extended FAB, FAB, FAB menu, filled, split button, standard button group | Create, Save, Confirm |
| Medio | tonal, elevated, outlined | Reply, View all, Add to cart |
| Bajo | text, connected button group, icon button | Learn more, Bookmark, Star |

### Placement (ex `button.html`, seccion Placement)

Una sola accion de alto enfasis por pantalla. En linea, de mayor a menor enfasis; nunca un boton debajo de otro si entran lado a lado. Pares correctos: filled + text, outlined + filled, text + outlined.

### Audit del boton (ex `button.html`, seccion Audit)

Contra el alt oficial de la spec (bottom padding space200/space400, leading space300/space600):

| Concepto | Spec | Nuestro | Estado |
|---|---|---|---|
| Leading padding (base) | space300 = 24px | measurement-300 = 24px | coincide |
| Leading padding (con icono) | space200 = 16px | measurement-200 = 16px | coincide |
| Trailing (con icono) | no dice | 24px | decision nuestra |
| Bottom padding | space200/space400 = 16/32px | 0 (height 2.5rem) | derivado, no spacing |
| Height | no dice | 40px | derivado del line-height |
| Small button | existe | no existe | falta |
| Gap icono-texto | no dice | measurement-100 = 8px | decision nuestra |

Se documenta, no se corrige: pasar a padding-block cambia la caja de 40px a 36px y eso es API visual. Ademas el target de 40px queda bajo el minimo de 48x48 de la pagina Density.

### Reglas de card (ex `card.html`, seccion Rules)

Un subject por card. El container es lo unico obligatorio, el resto opcional. El tamano lo da el contenido. No forzar contenido en cards (espaciado o divisores si es mas simple). Jamas accion sobre superficie accionable. Actions y media se construyen en sus pasos. Cuidado con large/full en cards densas (spec): medium 12 alcanza. Dividers full para expandir, inset 16 para separar. Media edge-to-edge o contenida, sin sombra, alto libre. Actions: botones a la derecha con gap 8 (decision 15). Mismo action area en las 3 (tonal y elevated fuera por contraste).

### Reglas de extended-fab (ex `extended-fab.html`, seccion Rules)

Uno por pantalla. No como opcion en un set (ahi van filled buttons). Margenes de 16dp. Mejor en pantallas grandes y vistas con scroll largo.

### Nota de Expressive (ex `button-group.html`, seccion Expressive)

Standard no existe en M3 core. Connected existe como segmented button, pero la spec lo marca no recomendado. Evitar icon buttons estandar y text buttons: no tienen container treatment.

### Anatomias en texto (originales, ex 4 showrooms)

Reemplazadas en v0.60 por referencia visual compuesta (decision 22). Se preservan porque nombran las partes:

- button: base con geometria (40px, pill, gap 8); variante con color y elevacion; state layer en hover/pressed/focus; etiqueta con label-large; con icono padding 16/24.
- fab: geometria 56, radio large, primary-container, sombra 3 (hover 4); large 96, radio extra-large, icono 36; extended ancho auto, padding 16/20, gap 12 (nota: rdm-fab--extended no existe como clase, el extendido es su componente); state layer; icono solo con aria-label en el boton.
- extended-fab: base 56 con sombra; ancho auto, padding 16/20, gap 12; state layer; etiqueta label-large.
- icon-button: 40px round sin container; variante con color y borde; state layer; aria-label siempre, aria-pressed en toggle; selected por atributo, JS lo alterna.

### Notas de auditoria de medidas (ex showrooms, v0.68)

Preservadas de las tablas Medida/Valor: el showroom publica medida y
valor; de donde sale cada numero vive aca.

- menu item: 56/72 de `v0_192/_md-comp-list.scss`; 12/16/16/24 del
  wrapper y de `_menu-item.scss`; label on-surface, resto
  on-surface-variant; fondo transparent (hereda el menu);
  seleccionado secondary-container + on-secondary-container;
  deshabilitado opacidad 0.3. `container-shape` unsupported: sin radio
  por item. Divider en menu = layout Grouped, `--` en M3 y disponible
  en Expressive: fuera por decision 9. El 12 va en
  `measurement-150` (extension del proyecto).
- divider: la spec publica margen inferior 8; el top iguala por
  decision simetrica (D26). Margen derecho 8 y 4dp a supporting-text
  son del diagrama en contexto de lista: pendientes de Lists, no de
  la base.
