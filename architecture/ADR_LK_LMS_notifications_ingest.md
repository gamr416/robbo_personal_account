# ADR: доставка уведомлений LMS → ЛК (HTTP ingest)

## Status

Accepted

## Context

- Inbox хранится в **`robbo_portal_notifications`** (legacy Postgres `robbo_db`), не в LMS MySQL и не в Projects Postgres (`scratch_*`).
- Источники: LMS (HTTP ingest) и админы ЛК (планировался REST `/api/notifications/*` — **не реализован** на backend, UI на фронте есть).
- При **`legacyPostgres.enabled=false`** portal gateway = noop — ingest и inbox **недоступны** до отдельного хранилища или включения legacy.
- OIDC SSO ([ADR_LK_LMS_SSO_OIDC.md](ADR_LK_LMS_SSO_OIDC.md)) не используется для доставки текста уведомлений — нужен отдельный server-to-server вызов.

См. также [FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md) (раздел «Уведомления»).

## Decision

- LMS (или сервис рядом с Open edX) вызывает **POST** `https://<lk-backend>/internal/lms/notifications`.
- Аутентификация: заголовок `Authorization: Bearer <LMS_NOTIFICATIONS_INGEST_TOKEN>` (значение из конфига ЛК, общий секрет для инфраструктуры).
- Тело JSON (UTF-8), минимальный контракт:

```json
{
  "recipientUserId": "123",
  "recipientEmail": "user@example.com",
  "title": "Заголовок",
  "body": "Текст",
  "kind": "lms_enrollment",
  "severity": "INFO",
  "actionUrl": "https://lms.example.com/...",
  "dedupeKey": "edx:enrollment:course-v1:xxx:user-42"
}
```

- Должен быть задан **ровно один** способ адресации получателя: `recipientUserId` **или** `recipientEmail` (приоритет: если задан `recipientUserId`, email игнорируется).
- Поле `lmsUserSub` зарезервировано для будущего явного маппинга OIDC `sub` → пользователь ЛК; в текущей версии может игнорироваться, если передан `recipientUserId` / `recipientEmail`.
- `dedupeKey` опционально: при повторной отправке с тем же ключом и тем же получателем вторая запись не создаётся (идемпотентность).
- `severity`: `INFO` | `WARNING` | `CRITICAL` (по умолчанию `INFO`).
- Ответы: `201` создано, `200` дубликат (идемпотентность), `400` валидация, `401` неверный токен, `404` получатель не найден.

## Consequences

- На стороне LMS нужно один раз настроить URL и токен и формировать JSON при выбранных событиях.
- Токен хранить как секрет (не в репозитории); ротация — смена значения в конфиге ЛК и на LMS одновременно.
