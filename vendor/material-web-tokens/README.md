# material-web-tokens

Referencia de tokens `comp` de Material Web (codigo SCSS, Apache 2.0).
Origen: https://github.com/material-components/material-web
(`labs/card` + `tokens` v0_192).

- Capa: `comp` (valores por componente y variante). No es `ref` ni `sys`.
- Formato: SCSS con funciones `map.get(...)`. El navegador no ejecuta
  Sass: estos archivos NUNCA se importan desde `css/`. Solo se leen en
  auditorias (check 41) y se documentan en los showrooms.
- Generacion: v0_192 (2023). Distinta del export DSP pre-2023 de
  `material-tokens/`: no se unifican porque la separacion registra las
  dos generaciones (ver SKILL decision 4).
- Contenido actual: `_md-comp-{elevated,filled,outlined}-card.scss`
  (wrappers con la lista de tokens soportados y los 2 TODOs de Google)
  + `versions/v0_192/` (sets de valores) + `labs/card/demo/stories.ts`
  (maquetacion de referencia: content con padding 16 y gap 16, img con
  height 128 sin aspect-ratio y border-radius inherit).
  Menu baseline (v0.61): `_md-comp-menu.scss` (wrapper: top-space y
  bottom-space 8px hardcoded, 4 list-item-* unsupported) +
  `versions/v0_192/_md-comp-menu.scss` (container surface-container,
  level2, corner-extra-small).
  Divider (v0.64): `_md-comp-divider.scss` (wrapper: supported color +
  thickness) + `versions/v0_192/_md-comp-divider.scss` (color
  outline-variant, thickness 1px). Sin geometria: los margenes vienen
  solo de la tabla de la spec.
  Menu item (v0.67): `_md-comp-menu-item.scss` (wrapper: 30 tokens,
  container propio a transparent, valores de list-item renombrados) +
  `_md-comp-list-item.scss` (wrapper: top/bottom-space 12px hardcoded,
  alturas en v0_192) + `_md-menu-item-styles.scss` (geometria de la
  implementacion: flex, gap 16px, min-height con token).
- Licencia: Apache 2.0 (`LICENSE` en esta carpeta; cada archivo trae su
  cabecera SPDX).
