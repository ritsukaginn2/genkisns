const VALID_INSTALLATION_STATUSES = new Set(['allowed', 'limited', 'blocked']);

export function normalizeInstallationStatus(status) {
  return VALID_INSTALLATION_STATUSES.has(status) ? status : 'allowed';
}

export function reviewInstallation(installation) {
  const status = normalizeInstallationStatus(installation?.status);
  if (status === 'blocked') {
    return { ok: false, reason: 'installation_blocked', fallbackRequired: true };
  }
  if (status === 'limited') {
    return { ok: false, reason: 'installation_limited', fallbackRequired: true };
  }
  return { ok: true };
}

export function reviewContent({ payload, config }) {
  const values = collectReviewableText(payload);
  for (const value of values) {
    const trimmed = value.trim();
    if (trimmed.length > config.maxTextLength) {
      return {
        ok: false,
        reason: 'content_too_long',
        fallbackRequired: true,
      };
    }
    const lowerValue = trimmed.toLocaleLowerCase();
    const matched = config.safetyBlocklist.find((term) =>
      lowerValue.includes(term.toLocaleLowerCase()),
    );
    if (matched) {
      return {
        ok: false,
        reason: 'content_rejected',
        fallbackRequired: true,
        matched,
      };
    }
  }
  return { ok: true };
}

function collectReviewableText(payload) {
  const values = [];
  if (typeof payload.text === 'string') values.push(payload.text);
  if (typeof payload.user?.nickname === 'string') values.push(payload.user.nickname);
  if (typeof payload.user?.bio === 'string') values.push(payload.user.bio);
  for (const friend of payload.friends ?? []) {
    // friend.id also reaches the LLM prompt, so it must be reviewed too.
    if (typeof friend.id === 'string') values.push(friend.id);
    if (typeof friend.name === 'string') values.push(friend.name);
    if (typeof friend.relationship === 'string') values.push(friend.relationship);
    if (typeof friend.personality === 'string') values.push(friend.personality);
    if (typeof friend.speaking_style === 'string') values.push(friend.speaking_style);
  }
  return values;
}
