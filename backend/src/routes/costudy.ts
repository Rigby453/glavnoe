import { randomUUID } from 'node:crypto';
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

  // ---------------------------------------------------------------------------
  // Study groups (Ф3) — настоящие группы поверх одиночных сессий.
  // Вступление по коду с модерацией владельцем (pending → accepted).
  // ---------------------------------------------------------------------------

  // POST /api/v1/study-groups — создать группу. Создатель сразу accepted/owner.
  app.post<{ Body: { name: string } }>('/api/v1/study-groups', {
    preHandler: requireAuth,
    schema: {
      body: {
        type: 'object',
        required: ['name'],
        properties: { name: { type: 'string' } },
      },
    },
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const name = req.body.name.trim();
      if (!name) return reply.code(400).send({ error: 'Name is required' });

      // Короткий код — первые 8 символов uuid (как у одиночных сессий).
      const code = randomUUID().substring(0, 8);

      const group = await prisma.studyGroup.create({
        data: {
          ownerId: userId,
          name,
          code,
          members: {
            create: { userId, role: 'owner', status: 'accepted' },
          },
        },
      });

      return reply.code(201).send({
        id: group.id,
        name: group.name,
        code: group.code,
        created_at: group.createdAt.toISOString(),
      });
    },
  });

  // POST /api/v1/study-groups/join/:code — подать заявку (status=pending).
  app.post<{ Params: { code: string } }>('/api/v1/study-groups/join/:code', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const code = req.params.code.toLowerCase();

      const group = await prisma.studyGroup.findFirst({
        where: { code: { equals: code, mode: 'insensitive' } },
      });
      if (!group) return reply.code(404).send({ error: 'Group not found' });

      const existing = await prisma.studyGroupMember.findUnique({
        where: { groupId_userId: { groupId: group.id, userId } },
      });
      if (existing) {
        return reply.code(409).send({
          error: existing.status === 'accepted' ? 'Already a member' : 'Request already pending',
          status: existing.status,
        });
      }

      await prisma.studyGroupMember.create({
        data: { groupId: group.id, userId, role: 'member', status: 'pending' },
      });

      return reply.code(201).send({
        group_id: group.id,
        name: group.name,
        status: 'pending',
      });
    },
  });

  // POST /api/v1/study-groups/:groupId/members/:userId/accept — владелец принимает.
  app.post<{ Params: { groupId: string; userId: string } }>(
    '/api/v1/study-groups/:groupId/members/:userId/accept',
    {
      preHandler: requireAuth,
      handler: async (req, reply) => {
        const ownerId = req.user.userId;
        const { groupId, userId: targetUserId } = req.params;

        const group = await prisma.studyGroup.findUnique({ where: { id: groupId } });
        if (!group) return reply.code(404).send({ error: 'Group not found' });
        if (group.ownerId !== ownerId) {
          return reply.code(403).send({ error: 'Only the owner can accept members' });
        }

        const member = await prisma.studyGroupMember.findUnique({
          where: { groupId_userId: { groupId, userId: targetUserId } },
        });
        if (!member) return reply.code(404).send({ error: 'Request not found' });

        // Идемпотентность: уже принятый участник → успех без повторной записи.
        if (member.status === 'accepted') {
          return reply.send({ user_id: member.userId, status: member.status });
        }
        // Принимаем только заявки в статусе pending — иначе ничего не «оживляем».
        if (member.status !== 'pending') {
          return reply.code(409).send({ error: 'Member is not pending', status: member.status });
        }

        const updated = await prisma.studyGroupMember.update({
          where: { groupId_userId: { groupId, userId: targetUserId } },
          data: { status: 'accepted' },
        });
        return reply.send({ user_id: updated.userId, status: updated.status });
      },
    },
  );

  // POST /api/v1/study-groups/:groupId/members/:userId/decline — владелец отклоняет (удаляет).
  app.post<{ Params: { groupId: string; userId: string } }>(
    '/api/v1/study-groups/:groupId/members/:userId/decline',
    {
      preHandler: requireAuth,
      handler: async (req, reply) => {
        const ownerId = req.user.userId;
        const { groupId, userId: targetUserId } = req.params;

        const group = await prisma.studyGroup.findUnique({ where: { id: groupId } });
        if (!group) return reply.code(404).send({ error: 'Group not found' });
        if (group.ownerId !== ownerId) {
          return reply.code(403).send({ error: 'Only the owner can decline members' });
        }
        // Нельзя отклонить владельца (это сломало бы группу).
        if (targetUserId === ownerId) {
          return reply.code(400).send({ error: 'Owner cannot be declined' });
        }

        await prisma.studyGroupMember.deleteMany({
          where: { groupId, userId: targetUserId },
        });
        return reply.code(204).send();
      },
    },
  );

  // DELETE /api/v1/study-groups/:groupId/leave — выйти из группы.
  // Если выходит владелец — группа удаляется со всеми участниками (cascade).
  app.delete<{ Params: { groupId: string } }>('/api/v1/study-groups/:groupId/leave', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const { groupId } = req.params;

      const group = await prisma.studyGroup.findUnique({ where: { id: groupId } });
      if (!group) return reply.code(404).send({ error: 'Group not found' });

      if (group.ownerId === userId) {
        // Владелец покидает → группа удаляется целиком (участники сносятся каскадом).
        await prisma.studyGroup.delete({ where: { id: groupId } });
        return reply.send({ deleted_group: true });
      }

      await prisma.studyGroupMember.deleteMany({ where: { groupId, userId } });
      return reply.send({ deleted_group: false });
    },
  });

  // GET /api/v1/study-groups — мои группы (где я accepted) + pending-счётчик для владельца.
  app.get('/api/v1/study-groups', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;

      const memberships = await prisma.studyGroupMember.findMany({
        where: { userId, status: 'accepted' },
        include: {
          group: {
            include: {
              _count: { select: { members: { where: { status: 'accepted' } } } },
            },
          },
        },
        orderBy: { joinedAt: 'desc' },
      });

      // Pending-заявки только для групп, где я владелец.
      const ownedGroupIds = memberships
        .filter((m) => m.group.ownerId === userId)
        .map((m) => m.groupId);

      const pendingCounts = ownedGroupIds.length
        ? await prisma.studyGroupMember.groupBy({
            by: ['groupId'],
            where: { groupId: { in: ownedGroupIds }, status: 'pending' },
            _count: { _all: true },
          })
        : [];
      const pendingMap = new Map(pendingCounts.map((p) => [p.groupId, p._count._all]));

      return reply.send(
        memberships.map((m) => ({
          id: m.group.id,
          name: m.group.name,
          code: m.group.code,
          is_owner: m.group.ownerId === userId,
          member_count: m.group._count.members,
          pending_count: m.group.ownerId === userId ? pendingMap.get(m.groupId) ?? 0 : 0,
        })),
      );
    },
  });

  // GET /api/v1/study-groups/:groupId — детали с участниками (accepted + pending).
  app.get<{ Params: { groupId: string } }>('/api/v1/study-groups/:groupId', {
    preHandler: requireAuth,
    handler: async (req, reply) => {
      const userId = req.user.userId;
      const { groupId } = req.params;

      const group = await prisma.studyGroup.findUnique({
        where: { id: groupId },
        include: {
          members: {
            include: { user: { select: { id: true, email: true } } },
            orderBy: { joinedAt: 'asc' },
          },
        },
      });
      if (!group) return reply.code(404).send({ error: 'Group not found' });

      // Доступ только участникам группы.
      const me = group.members.find((m) => m.userId === userId);
      if (!me) return reply.code(403).send({ error: 'Not a member of this group' });

      const isOwner = group.ownerId === userId;
      // Pending видит только владелец; обычный участник — только accepted.
      const visible = isOwner
        ? group.members
        : group.members.filter((m) => m.status === 'accepted');

      return reply.send({
        id: group.id,
        name: group.name,
        code: group.code,
        is_owner: isOwner,
        members: visible.map((m) => ({
          user_id: m.user.id,
          email: m.user.email,
          role: m.role,
          status: m.status,
        })),
      });
    },
  });
};
