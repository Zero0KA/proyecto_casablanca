const drawings = {
  landmark: <><path d="m3 8 9-5 9 5H3zm1 13h16M5 11v7m5-7v7m4-7v7m5-7v7" /></>,
  book: <><path d="M12 5C8 2 3 4 3 4v15s5-2 9 1c4-3 9-1 9-1V4s-5-2-9 1zm0 0v15" /></>,
  tree: <><path d="m12 3-6 7h3l-5 7h16l-5-7h3L12 3zm0 14v4" /></>,
  church: <><path d="M12 2v5m-2-3h4M4 21V11l8-5 8 5v10H4zm5 0v-7h6v7" /></>,
  theater: <><path d="M3 4h18v16H3V4zm5 0c0 7-3 9-5 9m13-9c0 7 3 9 5 9M8 13l-5 7m13-7 5 7" /></>,
  camera: <><path d="M3 7h5l2-3h4l2 3h5v13H3V7z" /><circle cx="12" cy="13" r="4" /></>,
  map_pin: <><path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0z" /><circle cx="12" cy="10" r="2" /></>,
  utensils: <><path d="M4 3v5c0 4 6 4 6 0V3M7 3v18m13 0V3c-6 5-6 10 0 10" /></>,
  wine: <><path d="M7 3h10l1 7c1 7-13 7-12 0l1-7zm-1 6h12m-6 7v5m-4 0h8" /></>,
  building: <><path d="M4 21V3h16v18H4zm5 0v-5h6v5M8 7h1m6 0h1M8 11h1m6 0h1" /></>,
}
export default function CategoryIcon({ code }) {
  return <svg className="category-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{Object.hasOwn(drawings, code) ? drawings[code] : <rect x="5" y="5" width="14" height="14" rx="3" />}</svg>
}
