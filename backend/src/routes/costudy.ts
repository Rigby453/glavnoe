import type { FastifyPluginAsync } from 'fastify';
import prisma from '../models/prisma.js';
import { requireAuth } from './middleware/auth.js';

export const coStudyRoutes: FastifyPluginAsync = async (app) => {
  // POST /api/v1/friends — добавить друга по email
  app.post<{ Body: { email: string } }>('/api/v1/friends', {
    preHandler: requireAuth,
    schema: {
      body: {
        type: 'object',
        required: ['email'],
        properties: { email: { type: 'string' } },
      },
    },
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const { email } = req.body;

      const friend = await prisma.user.findUnique({ where: { email } });
      if (!friend) return reply.code(404).send({ error: 'User not found' });
      if (friend.id === userId) return reply.code(400).send({ error: 'Cannot add yourself' });

      const existing = await prisma.friend.findUnique({
        where: { userId_friendId: { userId, friendId: friend.id } },
      });
      if (existing) return reply.code(409).send({ error: 'Already following' });

      await prisma.friend.create({ data: { userId, friendId: friend.id } });
      return reply.code(201).send({ id: friend.id, email: friend.email });
    },
  });

  // GET /api/v1/friends — список друзей со статусом сессии
  app.get('/api/v1/friends', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const rows = await prisma.friend.findMany({
        where: { userId },
        include: {
          friend: {
            select: {
              id: true,
              email: true,
              coStudySessions: {
                where: { endedAt: null },
                orderBy: { startedAt: 'desc' },
                take: 1,
              },
            },
          },
        },
      });

      return reply.send(
        rows.map((r) => ({
          id: r.friend.id,
          email: r.friend.email,
          in_session: r.friend.coStudySessions.length > 0,
          session_minutes:
            r.friend.coStudySessions[0]
              ? Math.floor(
                  (Date.now() - new Date(r.friend.coStudySessions[0].startedAt).getTime()) /
                    60000,
                )
              : null,
        })),
      );
    },
  });

  // DELETE /api/v1/friends/:friendId — убрать из друзей
  app.delete<{ Params: { friendId: string } }>('/api/v1/friends/:friendId', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;
      await prisma.friend.deleteMany({
        where: { userId, friendId: req.params.friendId },
      });
      return reply.code(204).send();
    },
  });

  // POST /api/v1/study-sessions — начать сессию
  app.post('/api/v1/study-sessions', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;

      // Авто-закрытие незакрытой сессии
      await prisma.coStudySession.updateMany({
        where: { userId, endedAt: null },
        data: { endedAt: new Date(), minutesLogged: 0 },
      });

      const session = await prisma.coStudySession.create({ data: { userId } });
      return reply.code(201).send({
        id: session.id,
        code: session.id.substring(0, 8),
        started_at: session.startedAt.toISOString(),
      });
    },
  });

  // GET /api/v1/study-sessions/join/:code — найти активную сессию по короткому коду
  app.get<{ Params: { code: string } }>('/api/v1/study-sessions/join/:code', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const code = req.params.code.toLowerCase();
      // Find active session where id starts with code
      const sessions = await prisma.coStudySession.findMany({
        where: { endedAt: null },
        include: { user: { select: { id: true, email: true } } },
      });
      const session = sessions.find((s) => s.id.toLowerCase().startsWith(code));
      if (!session) return reply.code(404).send({ error: 'Session not found or ended' });
      const elapsed = Math.floor((Date.now() - new Date(session.startedAt).getTime()) / 60000);
      return reply.send({
        id: session.id,
        code: session.id.substring(0, 8),
        user_email: session.user.email,
        user_id: session.user.id,
        started_at: session.startedAt.toISOString(),
        elapsed_minutes: elapsed,
      });
    },
  });

  // PATCH /api/v1/study-sessions/:id — завершить сессию
  app.patch<{ Params: { id: string }; Body: { minutes?: number } }>(
    '/api/v1/study-sessions/:id',
    {
      preHandler: requireAuth,
      schema: {
        body: {
          type: 'object',
          properties: { minutes: { type: 'number' } },
        },
      },
      handler: async (req, reply) => {
        const userId = req.user.userId;
        const session = await prisma.coStudySession.findFirst({
          where: { id: req.params.id, userId },
        });
        if (!session) return reply.code(404).send({ error: 'Session not found' });
        if (session.endedAt) return reply.code(400).send({ error: 'Already ended' });

        const endedAt = new Date();
        const elapsed = Math.floor(
          (endedAt.getTime() - session.startedAt.getTime()) / 60000,
        );
        const minutesLogged = req.body?.minutes ?? elapsed;

        const updated = await prisma.coStudySession.update({
          where: { id: session.id },
          data: { endedAt, minutesLogged },
        });
        return reply.send({
          id: updated.id,
          started_at: updated.startedAt.toISOString(),
          ended_at: updated.endedAt!.toISOString(),
          minutes_logged: updated.minutesLogged,
        });
      },
    },
  );

  // GET /api/v1/leaderboard — еженедельный рейтинг (я + друзья)
  app.get('/api/v1/leaderboard', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const friends = await prisma.friend.findMany({
        where: { userId },
        select: { friendId: true },
      });
      const ids = [userId, ...friends.map((f) => f.friendId)];
      const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

      const grouped = await prisma.coStudySession.groupBy({
        by: ['userId'],
        where: {
          userId: { in: ids },
          endedAt: { gte: since },
          minutesLogged: { gt: 0 },
        },
        _sum: { minutesLogged: true },
        orderBy: { _sum: { minutesLogged: 'desc' } },
      });

      const users = await prisma.user.findMany({
        where: { id: { in: ids } },
        select: { id: true, email: true },
      });
      const userMap = new Map(users.map((u) => [u.id, u.email]));

      const board = grouped.map((g, i) => ({
        rank: i + 1,
        user_id: g.userId,
        email: userMap.get(g.userId) ?? '',
        is_me: g.userId === userId,
        minutes: g._sum.minutesLogged ?? 0,
      }));

      if (!board.some((b) => b.is_me)) {
        board.push({
          rank: board.length + 1,
          user_id: userId,
          email: userMap.get(userId) ?? '',
          is_me: true,
          minutes: 0,
        });
      }

      return reply.send(board);
    },
  });
};
