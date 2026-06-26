<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import episodesRaw from '../episodes_1_245_utf8.txt?raw'
import { signUp, signIn, signOut, onAuthChanged, setRating, listenToRatings, loadUsersMap } from './firebase'

interface Episode {
  id: number
  title: string
  rating: number | null // current user rating
  ratingsMap?: Record<string, number | null> // uid -> rating
}

const parseEpisodeList = (raw: string): Episode[] => {
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+):\s*(.*)$/)
      if (!match) {
        throw new Error(`Unexpected episode line: ${line}`)
      }
      return {
        id: Number(match[1]),
        title: match[2].trim(),
        rating: null,
        ratingsMap: {},
      }
    })
}

const defaultEpisodes: Episode[] = parseEpisodeList(episodesRaw)
const episodes = ref<Episode[]>([...defaultEpisodes])
const sortBy = ref<'episode' | 'rating'>('episode')
const sortDirection = ref<'asc' | 'desc'>('asc')
const ratingOptions = Array.from({ length: 10 }, (_, index) => 10 - index)

const email = ref('')
const password = ref('')
const displayName = ref('')
const authError = ref<string | null>(null)
const user = ref<any>(null)
const usersMap = ref<Record<string, string | null>>({})

const loadUsers = async () => {
  try {
    usersMap.value = await loadUsersMap()
  } catch (e) {
    // ignore
  }
}

const applyRatingsSnapshot = (snapshotData: Record<string, any>) => {
  // snapshotData: { '001': { uid1: 8, uid2: 7, updatedAt: ... }, ... }
  for (const [docId, data] of Object.entries(snapshotData)) {
    const epId = Number(docId)
    const episode = episodes.value.find((e) => e.id === epId)
    if (!episode) continue
    episode.ratingsMap = {}
    for (const [k, v] of Object.entries(data as Record<string, any>)) {
      if (k === 'updatedAt') continue
      episode.ratingsMap[k] = v as number | null
    }
    // set current user rating if available
    if (user.value && episode.ratingsMap) {
      episode.rating = episode.ratingsMap[user.value.uid] ?? null
    }
  }
}

const unsubscribeRatings = ref<(() => void) | null>(null)

const startListening = () => {
  if (unsubscribeRatings.value) return
  unsubscribeRatings.value = listenToRatings((snap) => {
    applyRatingsSnapshot(snap)
  })
}

onAuthChanged((u) => {
  user.value = u
  // when auth state changes, ensure user map and start listening
  loadUsers()
  startListening()
})

onMounted(() => {
  // start listening even without auth so everyone sees live updates
  startListening()
  loadUsers()
})

const handleSignUp = async () => {
  authError.value = null
  try {
    await signUp(email.value, password.value, displayName.value || undefined)
    email.value = ''
    password.value = ''
    displayName.value = ''
  } catch (e: any) {
    authError.value = e?.message || String(e)
  }
}

const handleSignIn = async () => {
  authError.value = null
  try {
    await signIn(email.value, password.value)
    email.value = ''
    password.value = ''
  } catch (e: any) {
    authError.value = e?.message || String(e)
  }
}

const handleSignOut = async () => {
  try {
    await signOut()
    user.value = null
  } catch {
    // ignore
  }
}

const updateRating = async (episodeId: number, value: string) => {
  const episode = episodes.value.find((item) => item.id === episodeId)
  if (!episode) return
  const numeric = value === '' ? null : Number(value)
  // update local
  episode.rating = numeric
  // push to Firestore if user is signed in
  if (user.value) {
    const docId = String(episodeId).padStart(3, '0')
    await setRating(docId, user.value.uid, numeric)
  }
}

const sortedEpisodes = computed(() => {
  const list = [...episodes.value]
  if (sortBy.value === 'rating') {
    return list.sort((a, b) => {
      const aValue = (a.rating ?? -1)
      const bValue = (b.rating ?? -1)
      if (aValue === bValue) return a.id - b.id
      const direction = sortDirection.value === 'asc' ? 1 : -1
      return direction * (aValue - bValue)
    })
  }
  const direction = sortDirection.value === 'asc' ? 1 : -1
  return list.sort((a, b) => direction * (a.id - b.id))
})

const averageRating = computed(() => {
  const all: number[] = []
  for (const ep of episodes.value) {
    if (!ep.ratingsMap) continue
    for (const v of Object.values(ep.ratingsMap)) {
      if (typeof v === 'number') all.push(v)
    }
  }
  if (!all.length) return null
  return all.reduce((s, n) => s + n, 0) / all.length
})

const getOtherRatings = (episode: Episode) => {
  const out: Record<string, number | null> = {}
  if (!episode.ratingsMap) return out
  for (const [uid, value] of Object.entries(episode.ratingsMap)) {
    if (user.value && uid === user.value.uid) continue
    out[uid] = value
  }
  return out
}

const toggleDirection = () => {
  sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc'
}

const getCoverUrl = (episodeId: number) => {
  const episodeIdString = String(episodeId).padStart(3, '0')
  return `https://www.3fragezeichen.de/folgen_images/cover/${episodeIdString}.jpg`
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 text-slate-100">
    <div class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:px-8">
      <header class="mb-10 overflow-hidden rounded-[2rem] border border-[#E2001A]/20 bg-slate-950/90 p-8 shadow-[0_30px_80px_-40px_rgba(0,0,0,0.8)] backdrop-blur-xl">
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(226,0,26,0.22),transparent_25%),radial-gradient(circle_at_top_right,rgba(0,158,224,0.18),transparent_18%)]"></div>
        <div class="relative z-10 flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-sm uppercase tracking-[0.35em] text-sky-400">Die drei Fragezeichen</p>
            <div class="mt-3 flex flex-wrap items-end gap-3">
              <span class="text-4xl font-black tracking-tight text-white sm:text-5xl">Die drei</span>
              <span class="text-5xl font-black tracking-tight text-white sm:text-6xl">?</span>
              <span class="text-5xl font-black tracking-tight text-[#E2001A] sm:text-6xl">?</span>
              <span class="text-5xl font-black tracking-tight text-sky-400 sm:text-6xl">?</span>
            </div>
            <p class="mt-4 max-w-2xl text-slate-300">Alle 245 Folgen mit offiziellen Coverbildern anzeigen und nach Bewertung oder Folge sortieren. Deine Noten bleiben im Browser gespeichert.</p>
          </div>
          <div class="rounded-3xl border border-slate-800/80 bg-slate-900/80 p-6 shadow-lg shadow-slate-950/20">
            <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Ranking</p>
            <p class="mt-2 text-3xl font-semibold text-white">1–245</p>
            <p class="mt-1 text-sm text-slate-400">Cover, Titel und Bewertung auf einen Blick.</p>
          </div>
        </div>

    <div class="mt-6 grid gap-4 rounded-3xl border border-slate-800/80 bg-slate-900/80 p-4 shadow-lg shadow-slate-950/20 sm:grid-cols-[1fr_auto]">
      <div>
        <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Benutzer</p>
        <div class="mt-3">
          <div v-if="!user">
            <div class="grid gap-2 sm:grid-cols-3">
              <input v-model="email" type="email" placeholder="E-Mail" class="rounded-2xl px-3 py-2 bg-slate-950/70 text-slate-100 outline-none" />
              <input v-model="password" type="password" placeholder="Passwort" class="rounded-2xl px-3 py-2 bg-slate-950/70 text-slate-100 outline-none" />
              <input v-model="displayName" type="text" placeholder="Anzeigename (bei Registrierung)" class="rounded-2xl px-3 py-2 bg-slate-950/70 text-slate-100 outline-none" />
            </div>
            <div class="mt-3 flex gap-2">
              <button @click="handleSignIn" class="rounded-2xl bg-sky-500 px-4 py-2 text-sm font-semibold">Anmelden</button>
              <button @click="handleSignUp" class="rounded-2xl bg-[#E2001A] px-4 py-2 text-sm font-semibold">Registrieren</button>
            </div>
            <p v-if="authError" class="mt-2 text-sm text-red-400">{{ authError }}</p>
          </div>
          <div v-else>
            <p class="text-sm text-slate-300">Angemeldet als</p>
            <p class="mt-2 text-lg font-medium text-white">{{ user.displayName || user.email }}</p>
            <div class="mt-3">
              <button @click="handleSignOut" class="rounded-2xl bg-slate-700 px-4 py-2 text-sm">Abmelden</button>
            </div>
          </div>
        </div>
      </div>
      <div class="rounded-3xl border border-slate-800/80 bg-slate-950/70 p-4">
        <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Bekannte Nutzer</p>
        <div class="mt-2 max-h-32 overflow-auto">
          <div v-for="(name, uid) in usersMap" :key="uid" class="text-sm text-slate-300">{{ name || uid }}</div>
        </div>
      </div>
    </div>
  </header>

      <section class="mb-8 grid gap-4 md:grid-cols-[1fr_auto]">
        <div class="grid gap-3 rounded-3xl border border-slate-800/70 bg-slate-900/80 p-6 shadow-xl shadow-slate-950/20">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="space-y-2">
              <p class="text-sm font-medium uppercase tracking-[0.3em] text-sky-400">Sortieren</p>
              <div class="flex gap-2">
                <button
                  class="rounded-2xl border border-slate-700/90 bg-slate-800 px-4 py-2 text-sm font-medium text-slate-100 transition hover:bg-slate-700/90"
                  :class="{ 'ring-2 ring-sky-500': sortBy === 'episode' }"
                  @click="sortBy = 'episode'"
                >
                  Folge
                </button>
                <button
                  class="rounded-2xl border border-slate-700/90 bg-slate-800 px-4 py-2 text-sm font-medium text-slate-100 transition hover:bg-slate-700/90"
                  :class="{ 'ring-2 ring-sky-500': sortBy === 'rating' }"
                  @click="sortBy = 'rating'"
                >
                  Bewertung
                </button>
              </div>
            </div>

            <div class="flex items-center gap-3">
              <button
                class="inline-flex items-center justify-center rounded-2xl border border-slate-700/90 bg-slate-800 px-4 py-2 text-sm font-medium text-slate-100 transition hover:bg-slate-700/90"
                @click="toggleDirection"
              >
                Richtung wechseln
              </button>
            </div>
          </div>
        </div>

        <div class="rounded-3xl border border-slate-800/70 bg-slate-900/80 p-6 shadow-xl shadow-slate-950/20">
          <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Durchschnitt</p>
          <p class="mt-2 text-3xl font-semibold text-white">
            {{ averageRating !== null ? averageRating.toFixed(1) : 'Noch keine Bewertungen' }}
          </p>
          <p class="mt-1 text-sm text-slate-400">Aus allen vergebenen Wertungen.</p>
        </div>
      </section>

      <section class="grid gap-4">
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="rounded-3xl border border-slate-800/70 bg-slate-900/80 p-6 shadow-lg shadow-slate-950/10">
            <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Hinweis</p>
            <p class="mt-3 text-slate-300">Wähle eine Bewertung für jede Folge. Deine Angaben werden automatisch gespeichert.</p>
          </div>
          <div class="rounded-3xl border border-slate-800/70 bg-slate-900/80 p-6 shadow-lg shadow-slate-950/10">
            <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Tipp</p>
            <p class="mt-3 text-slate-300">Sortiere nach Bewertung, um schnell deine Favoriten zu sehen.</p>
          </div>
        </div>

        <div class="grid gap-4">
          <div
            v-for="episode in sortedEpisodes"
            :key="episode.id"
            class="overflow-hidden rounded-[2rem] border border-slate-800/70 bg-slate-900/90 p-6 shadow-lg shadow-slate-950/20"
          >
            <div class="grid gap-6 lg:grid-cols-[220px_1fr]">
              <div class="relative">
                <img
                  :src="getCoverUrl(episode.id)"
                  :alt="episode.title"
                  loading="lazy"
                  class="h-full w-full min-h-[220px] rounded-[1.75rem] border border-slate-700/80 bg-slate-950/80 object-cover shadow-xl shadow-slate-950/30"
                />
                <span class="absolute left-4 bottom-4 rounded-full bg-slate-950/80 px-4 py-2 text-xs uppercase tracking-[0.3em] text-slate-200 shadow-lg shadow-slate-950/30">Folge {{ episode.id }}</span>
              </div>

              <div class="flex flex-col justify-between gap-6">
                <div>
                  <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Titel</p>
                  <h2 class="mt-3 text-2xl font-semibold leading-tight text-white">{{ episode.title }}</h2>
                  <p class="mt-3 text-sm leading-6 text-slate-400">Offizielles Coverbild der Folge. Bewertung speichern wir lokal im Browser.</p>
                </div>

                <div class="grid gap-4 sm:grid-cols-[1fr_auto]">
                  <div class="rounded-3xl border border-slate-800/70 bg-slate-950/90 p-4">
                    <p class="text-sm uppercase tracking-[0.28em] text-slate-500">Bewertung</p>
                    <p class="mt-2 text-4xl font-semibold text-white">{{ episode.rating !== null ? episode.rating : '-' }}</p>
                    <p class="mt-2 text-xs text-slate-400">{{ Object.keys(getOtherRatings(episode)).length }} andere Bewertungen</p>
                  </div>

                  <label class="grid gap-3 rounded-3xl border border-slate-800/70 bg-slate-950/90 p-4">
                    <span class="text-sm uppercase tracking-[0.28em] text-slate-400">Deine Wertung</span>
                    <select
                      class="w-full rounded-2xl border border-slate-700/90 bg-slate-950/90 px-4 py-3 text-slate-100 outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-500/20"
                      :value="episode.rating === null ? '' : episode.rating"
                      @change="updateRating(episode.id, ($event.target as HTMLSelectElement).value)"
                    >
                      <option value="">Auswählen</option>
                      <option v-for="rating in ratingOptions" :key="rating" :value="rating">
                        {{ rating }}
                      </option>
                    </select>
                  </label>
                </div>
                <div v-if="Object.keys(getOtherRatings(episode)).length" class="rounded-3xl border border-slate-800/70 bg-slate-950/90 p-4">
                  <p class="text-sm uppercase tracking-[0.28em] text-sky-400">Andere Bewertungen</p>
                  <div class="mt-3 space-y-2 text-sm text-slate-300">
                    <div v-for="(rating, uid) in getOtherRatings(episode)" :key="uid" class="flex items-center justify-between rounded-2xl bg-slate-900/80 px-4 py-3">
                      <span>{{ usersMap[uid] || uid }}</span>
                      <span>{{ rating !== null ? rating : '-' }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
