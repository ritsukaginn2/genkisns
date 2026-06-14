import { setTimeout as delay } from 'node:timers/promises';

export class StubLlmProvider {
  constructor(config = {}) {
    this.maxComments = config.maxComments ?? 5;
  }

  async generate({ request }) {
    const friends = request.friends.length > 0 ? request.friends : fallbackFriends(request.friend_ids);
    const comments = friends.slice(0, this.maxComments).map((friend, index) => ({
      actor_id: friend.id,
      content: buildStubComment({ request, friend, index }),
      like_count: Math.max(0, 12 - index * 2),
    }));
    await delay(20);
    return {
      ai_like_count: Math.max(8, comments.length + request.media.image_count * 2 + (request.media.has_video ? 4 : 0)),
      comments,
    };
  }
}

export class OpenAICompatibleProvider {
  constructor(config) {
    this.config = config;
  }

  async generate({ request, signal }) {
    if (!this.config.llmApiKey) {
      throw new Error('llm_api_key_missing');
    }
    const response = await fetch(this.config.llmEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.config.llmApiKey}`,
      },
      body: JSON.stringify({
        model: this.config.llmModel,
        temperature: 0.8,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content:
              'You generate warm GenkiSNS AI friend interactions. Return only valid JSON with ai_like_count and comments.',
          },
          {
            role: 'user',
            content: buildPrompt(request, this.config),
          },
        ],
      }),
      signal,
    });
    if (!response.ok) {
      throw new Error(`llm_http_${response.status}`);
    }
    const body = await response.json();
    const content = body.choices?.[0]?.message?.content;
    if (typeof content !== 'string') {
      throw new Error('llm_response_missing_content');
    }
    return JSON.parse(stripCodeFence(content));
  }
}

export function createLlmProvider(config) {
  if (config.llmProvider === 'openai-compatible') {
    return new OpenAICompatibleProvider(config);
  }
  return new StubLlmProvider(config);
}

function buildPrompt(request, config = {}) {
  const maxComments = config.maxComments ?? 5;
  const maxCommentLength = config.maxCommentLength ?? 160;
  return JSON.stringify({
    output_schema: {
      ai_like_count: 'integer 0..999',
      comments: [
        {
          actor_id: 'one of friend ids',
          content: `Chinese comment, max ${maxCommentLength} chars`,
          like_count: 'integer 0..99',
        },
      ],
    },
    user: request.user,
    post: {
      text: request.text,
      media: request.media,
    },
    friends: request.friends,
    rules: [
      'Use only provided actor_id values.',
      'Do not mention that you are an AI or a model.',
      'Do not invent image or video details beyond the provided media metadata.',
      `Return one to ${maxComments} comments.`,
    ],
  });
}

function stripCodeFence(content) {
  return content
    .trim()
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/i, '')
    .trim();
}

function fallbackFriends(friendIds) {
  return friendIds.map((id) => ({ id, name: id }));
}

function buildStubComment({ request, friend, index }) {
  const hasText = request.text.trim().length > 0;
  if (request.media.has_video) {
    return `${friend.name || '好友'}看完觉得这段很有现场感，值得被认真留一下。`;
  }
  if (request.media.image_count > 0) {
    return `${friend.name || '好友'}觉得这组图很有生活感，第 ${index + 1} 眼就停住了。`;
  }
  if (hasText) {
    return `${friend.name || '好友'}认真读完了，这条文字很像把心情稳稳存档。`;
  }
  return `${friend.name || '好友'}来给这条悄悄点个赞。`;
}
