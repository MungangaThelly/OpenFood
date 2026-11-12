const $ = (selector, root = document) => root.querySelector(selector);
const offersEl = $('#offers');
let offers = [];
let currentFilter = 'open';

const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));
const human = value => String(value || '').replaceAll('_', ' ').replace(/\b\w/g, c => c.toUpperCase());
const when = value => new Date(value).toLocaleString([], {month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit'});
const dateLabel = offer => offer.date_type === 'not_applicable' ? 'No date marking' : `${human(offer.date_type)} · ${offer.date_value || 'date not entered'}`;
const isOpen = offer => ['available', 'claimed', 'exception'].includes(offer.status);
const isDone = offer => ['collected', 'resolved', 'cancelled', 'expired'].includes(offer.status);

async function api(path, options = {}) {
  const response = await fetch(path, {headers: {'content-type': 'application/json'}, ...options});
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || `Request failed (${response.status})`);
  return result;
}

function actions(offer) {
  const buttons = [];
  if (offer.status === 'available') buttons.push(`<button class="small-button primary-action" data-action="claim" data-id="${offer.id}">Claim for charity</button>`);
  if (offer.status === 'claimed') buttons.push(`<button class="small-button primary-action" data-action="collect" data-id="${offer.id}">Record pickup</button>`);
  if (offer.status === 'claimed' || offer.status === 'collected') buttons.push(`<button class="small-button warn" data-action="issue" data-id="${offer.id}">Report an issue</button>`);
  if (offer.status === 'exception') buttons.push(`<button class="small-button primary-action" data-action="resolve" data-id="${offer.id}">Resolve issue</button>`);
  if (['available', 'claimed'].includes(offer.status)) buttons.push(`<button class="small-button" data-action="cancel" data-id="${offer.id}">Withdraw</button>`);
  buttons.push(`<button class="small-button" data-action="audit" data-id="${offer.id}">View audit trail</button>`);
  return buttons.join('');
}

function card(offer) {
  const recipient = offer.recipient ? `<div class="fact"><span>Claimed by</span>${esc(offer.recipient)}</div>` : '';
  const price = offer.kind === 'discount' ? `${Number(offer.price || 0).toFixed(2)} SEK` : 'Free donation';
  const temp = offer.storage_temperature || 'Not specified';
  const handoff = offer.handoff ? `<div class="safety"><b>Handoff recorded:</b> ${esc(offer.handoff.confirmed_by)} received ${esc(offer.collected_quantity)} ${esc(offer.unit)}${offer.handoff.temperature_c !== undefined ? ` · ${esc(offer.handoff.temperature_c)} °C` : ''}. Package and date checks confirmed.</div>` : '';
  const issue = offer.exception ? `<div class="safety"><b>Issue:</b> ${esc(offer.exception.reason)} · reported by ${esc(offer.exception.actor)}</div>` : '';
  const resolved = offer.resolution ? `<div class="safety"><b>Resolution:</b> ${esc(offer.resolution.note)} · ${esc(offer.resolution.actor)}</div>` : '';
  return `<article class="card">
    <div class="card-top"><span class="kind ${offer.kind === 'discount' ? 'discount' : ''}">${offer.kind === 'discount' ? 'Discounted' : 'Donation'} · ${esc(price)}</span><span class="status ${esc(offer.status)}">${esc(human(offer.status))}</span></div>
    <h3>${esc(offer.title)}</h3><div class="business">${esc(offer.business)} · Ref ${esc(offer.batch_reference || '—')}</div>
    <div class="quantity">${esc(offer.quantity)} ${esc(offer.unit)} offered${offer.collected_quantity !== undefined ? ` · ${esc(offer.collected_quantity)} ${esc(offer.unit)} collected` : ''}</div>
    <div class="facts"><div class="fact"><span>Pickup by</span>${esc(when(offer.pickup_by))}</div><div class="fact"><span>Pickup location</span>${esc(offer.address)}</div>
      <div class="fact"><span>Date marking</span>${esc(dateLabel(offer))}</div><div class="fact"><span>Storage</span>${esc(temp)}</div>${recipient}
      <div class="fact"><span>Donor contact</span>${esc(offer.donor_contact || 'See donor')}</div>
    </div>
    <div class="safety"><b>Handling:</b> ${esc(offer.handling || 'Not entered')}<br><b>Ingredients / allergens:</b> ${esc(offer.ingredients || 'Not provided')}</div>
    ${handoff}${issue}${resolved}<div class="card-actions">${actions(offer)}</div>
  </article>`;
}

function render() {
  const shown = offers.filter(offer => currentFilter === 'all' ||
    (currentFilter === 'open' && isOpen(offer)) || (currentFilter === 'completed' && isDone(offer)));
  offersEl.innerHTML = shown.length ? shown.map(card).join('') : '<div class="empty">No records in this view yet.</div>';
  $('#openCount').textContent = offers.filter(isOpen).length;
}

async function refresh() {
  try {
    offers = await api('/api/offers');
    render();
    const impact = await api('/api/impact');
    $('#pickupCount').textContent = impact.completed_pickups;
    $('#quantityTotal').textContent = Object.entries(impact.quantities_by_unit || {}).map(([unit, qty]) => `${qty} ${unit}`).join(', ') || '0';
  } catch (error) {
    offersEl.innerHTML = `<div class="empty">Could not load the board: ${esc(error.message)}</div>`;
  }
}

async function perform(action, id) {
  const offer = offers.find(item => item.id === id);
  try {
    if (action === 'claim') {
      const recipient = prompt('Recipient organization name:');
      if (!recipient) return;
      const actor = prompt('Coordinator or volunteer making the claim:');
      if (!actor) return;
      await api(`/api/offers/${id}/claim`, {method: 'POST', body: JSON.stringify({recipient, actor})});
    } else if (action === 'collect') {
      const form = $('#handoffForm');
      form.reset(); form.elements.offer_id.value = id; form.elements.quantity.max = offer.quantity;
      $('#handoffDialog').showModal(); return;
    } else if (action === 'issue') {
      const actor = prompt('Your name / organization:'); if (!actor) return;
      const reason = prompt('Describe the pickup or food issue:'); if (!reason) return;
      await api(`/api/offers/${id}/issue`, {method: 'POST', body: JSON.stringify({actor, reason})});
    } else if (action === 'resolve') {
      const actor = prompt('Coordinator name:'); if (!actor) return;
      const resolution = prompt('How was the issue resolved?'); if (!resolution) return;
      await api(`/api/offers/${id}/resolve`, {method: 'POST', body: JSON.stringify({actor, resolution})});
    } else if (action === 'cancel') {
      if (!confirm('Withdraw this offer? The action will be recorded.')) return;
      const actor = prompt('Your name / organization:'); if (!actor) return;
      await api(`/api/offers/${id}/cancel`, {method: 'POST', body: JSON.stringify({actor})});
    } else if (action === 'audit') {
      const events = await api(`/api/offers/${id}/audit`, {method: 'POST', body: '{}'});
      $('#auditEvents').innerHTML = events.length ? events.map(event => `<article class="event"><strong>${esc(human(event.action))}</strong><time>${esc(when(event.at))}</time><p>By ${esc(event.actor)} · ${esc(JSON.stringify(event.details))}</p></article>`).join('') : '<p>No audit events.</p>';
      $('#auditDialog').showModal(); return;
    }
    await refresh();
  } catch (error) { alert(error.message); }
}

$('#offers').addEventListener('click', event => {
  const button = event.target.closest('[data-action]');
  if (button) perform(button.dataset.action, button.dataset.id);
});
document.querySelectorAll('.filter').forEach(button => button.addEventListener('click', () => {
  currentFilter = button.dataset.filter;
  document.querySelectorAll('.filter').forEach(item => item.classList.toggle('active', item === button));
  render();
}));
$('#newOffer').addEventListener('click', () => $('#offerDialog').showModal());
document.querySelectorAll('[data-close]').forEach(button => button.addEventListener('click', () => $(`#${button.dataset.close}`).close()));

$('#offerForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const data = Object.fromEntries(new FormData(form));
  data.quantity = Number(data.quantity); data.price = Number(data.price || 0);
  data.pickup_by = new Date(data.pickup_by).toISOString();
  data.donor_safety_confirmed = form.elements.donor_safety_confirmed.checked;
  if (data.date_type !== 'not_applicable' && !data.date_value) { alert('Enter the date shown on the food.'); return; }
  try {
    await api('/api/offers', {method: 'POST', body: JSON.stringify(data)});
    form.reset(); $('#offerDialog').close(); await refresh();
  } catch (error) { alert(error.message); }
});

$('#handoffForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const data = Object.fromEntries(new FormData(form));
  data.quantity = Number(data.quantity);
  data.temperature_c = data.temperature_c === '' ? undefined : Number(data.temperature_c);
  data.package_intact = form.elements.package_intact.checked;
  data.date_checked = form.elements.date_checked.checked;
  try {
    await api(`/api/offers/${data.offer_id}/collect`, {method: 'POST', body: JSON.stringify(data)});
    $('#handoffDialog').close(); await refresh();
  } catch (error) { alert(error.message); }
});

const events = new EventSource('/api/events');
events.onmessage = () => refresh();
refresh();
