# Campus Connect — CRUD & Frontend Completion Plan

This plan gets **basic CRUD fully working** and the **frontend feature-complete** for the flows already in the app (Find → Provider detail → Booking → Appointments, Profile, Services, Availability, Favorites).

---

## Current state (summary)

| Area | Backend (Firestore) | Frontend |
|------|---------------------|----------|
| **User profile** | Upsert on sign-in ✓ | Account Details: read-only, edit taps do nothing |
| **Provider profile** | Create ✓, stream ✓. **No update/delete** | Profile: create works; list tap does nothing; no edit/set active |
| **Services** | Add, update, delete, stream ✓ | My Services: full CRUD ✓ |
| **Availability** | Stream, set (replace) ✓ | Availability page: add/remove slots ✓ |
| **Appointments** | Create, stream (consumer + provider), update status ✓ | Appointments + Booking: create & accept/decline ✓ |
| **Favorites** | Add, remove ✓ | Provider detail heart + Favorites page ✓ |
| **Booking flow** | createAppointment with serviceName/slot/price ✓ | **No service selection** — always "Service" / TBD; service list on provider detail doesn’t start booking |

---

## Phase 1: Backend — close CRUD gaps

### 1.1 Provider profile: update (and optional delete)

- **Add** `FirestoreService.updateProviderProfile(providerProfileId, { businessName, tags, contact?, location? })` with owner check and `updatedAt`.
- **Optional:** `deleteProviderProfile(providerProfileId)` or “deactivate” (e.g. remove from user’s `providerProfileIds` / clear `activeProviderProfileId`). If you add delete, update Firestore rules so only owner can delete.

### 1.2 User profile: update display info

- **Add** `FirestoreService.updateUserProfile(uid, { displayName?, photoUrl? })` (and any other editable fields you want). Keep `updatedAt`. Use only for the current user (`uid == request.auth.uid`); rules already enforce this.

---

## Phase 2: Booking flow — service selection

- **Booking page:** Insert a **service selection step** (before or after time slot):
  - Load provider’s services via `fs.streamServices(providerId)`.
  - Let user pick one; store `serviceId`, `serviceName`, `price`.
- **Review step:** Show selected service name and price (already have slot).
- **Confirm:** Call `createAppointment(..., serviceId, serviceName, price)` (you already have the params; ensure `serviceId` is passed).
- **Provider detail:** Optionally make “Services offered” list tappable: tap service → go to Booking with that service pre-selected (e.g. query param or route arg).

---

## Phase 3: Profile — provider list and account details

### 3.1 Your provider profiles (Profile tab)

- **List item tap:** Either open an “Edit provider” screen/sheet or a small menu (Edit / Set as active / Delete if you added it).
- **Edit provider:** Form with business name, tags (and contact/location if you use them). On save call `updateProviderProfile`.
- **Set as active:** Call existing `setActiveProviderProfile(uid, providerProfileId)` and refresh view (stream already updates when user doc changes).
- If you added delete: add “Delete” with confirmation; then call backend and switch view if that was the active profile.

### 3.2 Account details

- **Name row** `onTap`: open dialog or small edit screen; on save call `updateUserProfile(uid, { displayName })`. Reload or re-stream user profile so UI updates.
- **Photo:** If you support photo URL in `UserProfile`, add edit for `photoUrl` the same way (or “change photo” that updates URL after upload elsewhere).
- Keep Email/Username read-only unless you add auth-level email change later.

---

## Phase 4: Frontend polish and consistency

### 4.1 Find

- **Consumer “Businesses you follow”:** Use real data: stream user’s `favoriteProviderIds` and resolve to `ProviderProfile` (or reuse same pattern as Favorites page) instead of `mockProviders`.
- **“From” price on cards:** If you have services, show “From $X” using the minimum service price for that provider (optional; requires either storing min price on `ProviderProfile` or loading services per card).

### 4.2 Provider detail

- **Services list:** Make service tile `onTap` navigate to booking with this service pre-selected (e.g. `context.push('/booking?providerId=$id&serviceId=${s.serviceId}&serviceName=${s.name}&price=${s.price}')` and have BookingPage read query params to prefill and skip service step if desired).
- **Location:** Use `profile.location` if you have it; otherwise keep “Austin, TX” or “TBD” until you add it in Phase 3.1.

### 4.3 Public profile

- Use `userProfile.activeProviderProfileId` when available; only fall back to `list.first` when active is null (you already have the stream; ensure the widget uses `activeId` when present).

### 4.4 Appointments / Booking

- Ensure consumer appointment cards can **cancel** (e.g. “Cancel” button that calls `updateAppointmentStatus(id, 'cancelled')`). You already have provider accept/decline.
- Any empty or “TBD” labels in booking review should be replaced by selected service/slot/price once Phase 2 is done.

### 4.5 Notifications

- Already wired to local preferences; no Firestore CRUD needed. Optionally persist to Firestore under `users/{uid}/settings` later if you want cross-device sync.

---

## Phase 5: Firestore rules and validation

- If you added **update/delete** for provider profiles, ensure rules allow:
  - `update`: same as existing (owner only, no `ownerUid` change).
  - `delete`: only owner (e.g. `request.auth.uid == resource.data.ownerUid`).
- Validate required fields (e.g. `businessName` non-empty) in the service layer before writing.

---

## Suggested order of implementation

1. **Phase 1.1** — `updateProviderProfile` (and optional delete).
2. **Phase 1.2** — `updateUserProfile`.
3. **Phase 2** — Booking: service selection step + pass `serviceId`/`serviceName`/`price` through to `createAppointment`.
4. **Phase 3.1** — Profile: provider list tap → edit / set active (and delete if implemented).
5. **Phase 3.2** — Account details: edit name (and photo if applicable).
6. **Phase 4** — Find favorites from Firestore, provider detail service tap → booking, public profile active id, consumer cancel, “From” price optional.
7. **Phase 5** — Rules and validation.

---

## Definition of “done” for this plan

- **CRUD:** User profile (create + update), Provider profile (create + update [+ optional delete]), Services (full CRUD), Availability (read + set), Appointments (create + read + update status), Favorites (add + remove).
- **Frontend:** Find (real favorites on profile), Provider detail (real services, tap service → book), Booking (choose service + time, confirm with real data), Appointments (consumer cancel + provider accept/decline), Profile (create + edit provider, set active), Account details (edit name/photo), My Services & Availability unchanged and working, Favorites and Public profile using correct data.

After this, the app has basic CRUD fully working and the main flows implemented end-to-end on the frontend.
