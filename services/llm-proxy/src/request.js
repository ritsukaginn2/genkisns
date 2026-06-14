export function buildInteractionRequest(raw, { maxFriends = 12 } = {}) {
  const postId = requireString(raw.post_id, 'post_id');
  const text = typeof raw.text === 'string' ? raw.text : '';
  const media = normalizeMedia(raw);
  const friends = normalizeFriends(raw).slice(0, maxFriends);
  const user = {
    nickname: requireString(raw.user?.nickname ?? raw.user_name ?? 'User', 'user.nickname'),
    bio: typeof raw.user?.bio === 'string' ? raw.user.bio : '',
  };

  return {
    post_id: postId,
    text,
    media,
    friends,
    friend_ids: friends.map((friend) => friend.id),
    user,
  };
}

function normalizeMedia(raw) {
  if (raw.media && typeof raw.media === 'object') {
    return {
      image_count: clampInteger(raw.media.image_count, 0, 9),
      has_video: Boolean(raw.media.has_video),
      video_count: clampInteger(raw.media.video_count, 0, 1),
    };
  }
  return {
    image_count: clampInteger(raw.image_count, 0, 9),
    has_video: Boolean(raw.has_video),
    video_count: Boolean(raw.has_video) ? 1 : 0,
  };
}

function normalizeFriends(raw) {
  const friends = Array.isArray(raw.friends) ? raw.friends : [];
  if (friends.length > 0) {
    return friends.map((friend) => ({
      id: requireString(friend.id, 'friend.id'),
      name: requireString(friend.name, 'friend.name'),
      relationship: stringOrEmpty(friend.relationship),
      personality: stringOrEmpty(friend.personality),
      speaking_style: stringOrEmpty(friend.speaking_style),
    }));
  }

  const friendIds = Array.isArray(raw.friend_ids) ? raw.friend_ids : [];
  return friendIds.map((id) => ({
    id: requireString(id, 'friend_ids[]'),
    name: id,
    relationship: '',
    personality: '',
    speaking_style: '',
  }));
}

function requireString(value, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw badRequest(`${field} is required`);
  }
  return value.trim();
}

function stringOrEmpty(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function clampInteger(value, min, max) {
  const parsed = Number.parseInt(value ?? 0, 10);
  if (!Number.isFinite(parsed)) return min;
  return Math.max(min, Math.min(max, parsed));
}

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}
