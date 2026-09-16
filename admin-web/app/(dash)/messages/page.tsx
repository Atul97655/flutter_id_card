'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { Megaphone, MessageSquare, Plus, Send } from 'lucide-react';
import Link from 'next/link';
import { Topbar } from '@/components/layout/topbar';
import {
  Banner,
  Button,
  EmptyState,
  MOTION,
  Panel,
  Skeleton,
  Spinner,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';
import { useAuth } from '@/lib/auth-context';
import { useStore } from '@/lib/store';
import {
  createChat,
  markChatRead,
  sendMessage,
  watchMessages,
} from '@/lib/data';
import type { Chat, ChatMessage } from '@/lib/types';

/**
 * Admin side of the hub-and-spoke messaging.
 *
 * Every school talks to this office and to nobody else - that is enforced in
 * the database, not here: only an admin can create a conversation, so a
 * teacher has no way to open one with another teacher.
 */
export default function MessagesPage() {
  const { profile } = useAuth();
  const { chats, schools, users, loading } = useStore();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const direct = useMemo(() => chats.filter((c) => c.kind === 'direct'), [chats]);
  const active = chats.find((c) => c.id === activeId) ?? null;

  // Open the first conversation so the pane is never empty on arrival.
  useEffect(() => {
    if (!activeId && direct.length > 0) setActiveId(direct[0].id);
  }, [activeId, direct]);

  /** Schools that have an operator but no conversation yet. */
  const missing = useMemo(() => {
    const withChat = new Set(chats.map((c) => c.schoolId).filter(Boolean));
    return schools.filter((s) => !withChat.has(s.id));
  }, [chats, schools]);

  const openFor = async (schoolId: string, schoolName: string) => {
    if (!profile) return;
    setError(null);
    try {
      const operators = users
        .filter((u) => u.schoolId === schoolId && u.role !== 'Admin')
        .map((u) => u.uid);

      if (operators.length === 0) {
        setError(
          `No operator account is linked to ${schoolName} yet, so nobody would see the conversation. Assign one under Teachers & Schools first.`,
        );
        return;
      }

      const id = await createChat(schoolName, [profile.uid, ...operators], schoolId);
      setActiveId(id);
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="Conversations" title="Messages" />

      {error ? <Banner tone="warn" title="Could not open the conversation">{error}</Banner> : null}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,300px)_minmax(0,1fr)]">
        {/* Conversation list */}
        <Panel className="flex max-h-[calc(100vh-190px)] flex-col overflow-hidden">
          <div className="flex items-center justify-between gap-2 px-4 pt-4 pb-2">
            <h2 className="text-[14px] font-semibold text-ink-700">Schools</h2>
            <Link
              href="/broadcast"
              className="inline-flex items-center gap-1 text-[12px] font-semibold text-mint-600 transition hover:text-mint-700"
            >
              <Megaphone size={12} /> Announce
            </Link>
          </div>

          <div className="min-h-0 flex-1 overflow-y-auto px-2 pb-2">
            {loading ? (
              <div className="flex flex-col gap-2 px-2">
                <Skeleton className="h-14" />
                <Skeleton className="h-14" />
              </div>
            ) : direct.length === 0 && missing.length === 0 ? (
              <EmptyState
                icon={MessageSquare}
                title="No schools yet"
                body="Add a school and assign an operator, then you can start a conversation."
              />
            ) : (
              <ul className="flex flex-col gap-0.5">
                {direct.map((c, i) => (
                  <ChatRow
                    key={c.id}
                    chat={c}
                    active={c.id === activeId}
                    unread={c.unreadFor.includes(profile?.uid ?? '')}
                    index={i}
                    onClick={() => setActiveId(c.id)}
                  />
                ))}

                {missing.length > 0 ? (
                  <li className="px-2 pb-1 pt-3 text-[10.5px] font-bold uppercase tracking-wider text-ink-400">
                    No conversation yet
                  </li>
                ) : null}

                {missing.map((s) => (
                  <li key={s.id}>
                    <button
                      type="button"
                      onClick={() => void openFor(s.id, s.name)}
                      className="flex w-full items-center gap-2 rounded-xl px-2.5 py-2.5 text-left transition hover:bg-white/70"
                    >
                      <span className="grid size-7 shrink-0 place-items-center rounded-lg border border-dashed border-ink-400/30 text-ink-400">
                        <Plus size={13} />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[12.5px] font-medium text-ink-600">
                          {s.name}
                        </span>
                        <span className="block text-[11px] text-ink-400">
                          Start a conversation
                        </span>
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </Panel>

        {/* Thread */}
        {active ? (
          <Thread key={active.id} chat={active} />
        ) : (
          <Panel index={1}>
            <EmptyState
              icon={MessageSquare}
              title="Pick a conversation"
              body="Choose a school on the left to read and reply to its messages."
            />
          </Panel>
        )}
      </div>
    </div>
  );
}

function ChatRow({
  chat,
  active,
  unread,
  index,
  onClick,
}: {
  chat: Chat;
  active: boolean;
  unread: boolean;
  index: number;
  onClick: () => void;
}) {
  return (
    <motion.li
      initial={{ opacity: 0, y: 5 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
    >
      <button
        type="button"
        onClick={onClick}
        className={`flex w-full items-start gap-2.5 rounded-xl px-2.5 py-2.5 text-left transition ${
          active ? 'bg-mint-500/12' : 'hover:bg-white/70'
        }`}
      >
        <span
          className={`mt-0.5 grid size-7 shrink-0 place-items-center rounded-lg text-[11px] font-bold ${
            active ? 'bg-mint-600 text-white' : 'bg-ink-400/12 text-ink-500'
          }`}
        >
          {chat.title.slice(0, 2).toUpperCase()}
        </span>

        <span className="min-w-0 flex-1">
          <span className="flex items-center gap-1.5">
            <span
              className={`min-w-0 flex-1 truncate text-[12.5px] ${
                unread ? 'font-bold text-ink-900' : 'font-medium text-ink-700'
              }`}
            >
              {chat.title}
            </span>
            {unread ? (
              <span className="size-1.5 shrink-0 rounded-full bg-[var(--color-status-pending)]" />
            ) : null}
          </span>
          <span className="mt-0.5 block truncate text-[11.5px] text-ink-400">
            {chat.lastMessage || 'No messages yet'}
          </span>
        </span>
      </button>
    </motion.li>
  );
}

function Thread({ chat }: { chat: Chat }) {
  const { profile } = useAuth();
  const [messages, setMessages] = useState<ChatMessage[] | null>(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setMessages(null);
    return watchMessages(
      chat.id,
      (m) => setMessages(m),
      (e) => setError(e.message),
    );
  }, [chat.id]);

  // Clearing the badge is a write the rules allow a member to make on exactly
  // this field, so it is safe to fire on open.
  useEffect(() => {
    if (!profile || !chat.unreadFor.includes(profile.uid)) return;
    void markChatRead(chat.id, profile.uid).catch(() => {
      // Not worth interrupting reading over.
    });
  }, [chat.id, chat.unreadFor, profile]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [messages]);

  const send = async () => {
    if (!profile || !draft.trim()) return;
    setSending(true);
    setError(null);
    const text = draft;
    setDraft('');
    try {
      await sendMessage(
        chat,
        profile.uid,
        profile.displayName || 'Office',
        text,
      );
    } catch (e) {
      setDraft(text); // Give it back rather than losing what they typed.
      setError((e as Error).message);
    } finally {
      setSending(false);
    }
  };

  return (
    <Panel index={1} className="flex max-h-[calc(100vh-190px)] flex-col overflow-hidden">
      <div className="flex items-center gap-2.5 border-b border-ink-400/10 px-5 py-3.5">
        <span className="grid size-8 place-items-center rounded-lg bg-mint-600 text-[12px] font-bold text-white">
          {chat.title.slice(0, 2).toUpperCase()}
        </span>
        <div className="min-w-0">
          <p className="truncate text-[14px] font-semibold text-ink-700">
            {chat.title}
          </p>
          <p className="text-[11.5px] text-ink-400">
            {chat.members.length - 1} operator
            {chat.members.length - 1 === 1 ? '' : 's'}
          </p>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">
        {messages === null ? (
          <div className="flex justify-center py-6">
            <Spinner />
          </div>
        ) : messages.length === 0 ? (
          <p className="py-8 text-center text-[13px] text-ink-400">
            No messages yet. Say hello.
          </p>
        ) : (
          <ul className="flex flex-col gap-2.5">
            {messages.map((m) => (
              <Bubble key={m.id} message={m} mine={m.senderId === profile?.uid} />
            ))}
          </ul>
        )}
        <div ref={endRef} />
      </div>

      {error ? (
        <div className="px-5 pb-2">
          <p className="text-[12px] text-[var(--color-status-rejected)]">{error}</p>
        </div>
      ) : null}

      <div className="border-t border-ink-400/10 px-4 py-3">
        <div className="flex items-end gap-2">
          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                void send();
              }
            }}
            rows={1}
            placeholder="Write a message…"
            className={`${inputClass} max-h-28 min-h-[42px] resize-y py-2.5`}
          />
          <Button
            icon={Send}
            busy={sending}
            disabled={!draft.trim()}
            onClick={() => void send()}
          >
            Send
          </Button>
        </div>
        <p className="mt-1.5 text-[11px] text-ink-400">
          Enter sends · Shift + Enter for a new line
        </p>
      </div>
    </Panel>
  );
}

function Bubble({ message, mine }: { message: ChatMessage; mine: boolean }) {
  return (
    <motion.li
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: MOTION.normal, ease: MOTION.ease }}
      className={`flex ${mine ? 'justify-end' : 'justify-start'}`}
    >
      <div
        className={`max-w-[76%] rounded-2xl px-3.5 py-2.5 ${
          mine
            ? 'rounded-br-md bg-mint-600 text-white'
            : 'rounded-bl-md bg-white text-ink-700 shadow-sm'
        }`}
      >
        {!mine ? (
          <p className="mb-0.5 text-[11px] font-bold text-mint-700">
            {message.senderName}
          </p>
        ) : null}

        {message.attachmentUrl ? (
          <a
            href={message.attachmentUrl}
            target="_blank"
            rel="noreferrer"
            className="mb-1.5 block overflow-hidden rounded-lg"
          >
            {message.kind === 'image' ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={message.attachmentUrl}
                alt={message.attachmentName ?? 'Attachment'}
                className="max-h-56 w-full object-cover"
                loading="lazy"
              />
            ) : (
              <span
                className={`block rounded-lg px-2.5 py-2 text-[12px] underline ${
                  mine ? 'bg-white/15' : 'bg-ink-400/8'
                }`}
              >
                {message.attachmentName ?? 'Attachment'}
              </span>
            )}
          </a>
        ) : null}

        {message.body ? (
          <p className="whitespace-pre-wrap text-[13px] leading-relaxed">
            {message.body}
          </p>
        ) : null}

        <p
          className={`mt-1 text-[10.5px] ${mine ? 'text-white/70' : 'text-ink-400'}`}
        >
          {message.sentAt
            ? new Date(message.sentAt).toLocaleTimeString(undefined, {
                hour: '2-digit',
                minute: '2-digit',
              })
            : ''}
        </p>
      </div>
    </motion.li>
  );
}
