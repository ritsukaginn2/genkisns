export function validateJobResult(raw, { friendIds, maxComments, maxCommentLength = 160 }) {
  if (!raw || typeof raw !== 'object') {
    throw new Error('llm_result_not_object');
  }
  const aiLikeCount = normalizeInteger(raw.ai_like_count, 0, 999, 'ai_like_count');
  if (!Array.isArray(raw.comments)) {
    throw new Error('comments_not_array');
  }
  const allowedFriendIds = new Set(friendIds);
  const comments = raw.comments.slice(0, maxComments).map((comment, index) => {
    if (!comment || typeof comment !== 'object') {
      throw new Error(`comment_${index}_not_object`);
    }
    const actorId = requireString(comment.actor_id, `comments[${index}].actor_id`);
    if (!allowedFriendIds.has(actorId)) {
      throw new Error(`unknown_actor_id:${actorId}`);
    }
    const content = requireString(comment.content, `comments[${index}].content`);
    if (content.length > maxCommentLength) {
      throw new Error(`comment_too_long:${index}`);
    }
    return {
      actor_id: actorId,
      content,
      like_count: normalizeInteger(comment.like_count, 0, 99, `comments[${index}].like_count`),
    };
  });
  if (comments.length === 0) {
    throw new Error('comments_empty');
  }
  return {
    ai_like_count: aiLikeCount,
    comments,
  };
}

function requireString(value, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${field}_required`);
  }
  return value.trim();
}

function normalizeInteger(value, min, max, field) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    throw new Error(`${field}_out_of_range`);
  }
  return parsed;
}
