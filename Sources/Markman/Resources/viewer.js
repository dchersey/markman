// SPDX-License-Identifier: GPL-3.0-only
window.renderMarkdown = (markdown) => {
  const y = window.scrollY;
  document.getElementById('content').innerHTML = DOMPurify.sanitize(marked.parse(markdown, { gfm:true }), {
    FORBID_TAGS: ['style', 'form', 'iframe', 'object', 'embed', 'base'],
    FORBID_ATTR: ['style', 'srcset'],
    ADD_DATA_URI_TAGS: ['img']
  });
  document.querySelectorAll('table').forEach(table => {
    const wrapper = document.createElement('div');
    wrapper.className = 'table-scroll';
    wrapper.tabIndex = 0;
    wrapper.setAttribute('role', 'region');
    wrapper.setAttribute('aria-label', 'Scrollable table');
    table.before(wrapper); wrapper.append(table);
  });
  document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach((heading) => {
    const base = heading.textContent.toLowerCase().trim().replace(/[^\p{L}\p{N}\s_-]/gu,'').replace(/\s/g,'-') || 'section';
    let id = base, n = 1;
    while (document.getElementById(id)) id = `${base}-${n++}`;
    heading.id = id;
  });
  // Avoid subpixel scroll rounding on every refresh when the position is unchanged.
  if (window.scrollY !== y) window.scrollTo(0,y);
};
