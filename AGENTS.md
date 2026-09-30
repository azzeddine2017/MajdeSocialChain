# AGENTS.md - Mejde (SocialChain)  Vision

## Project
**Mejde** - Truly Decentralized, Open-Source Social Network and Content Discovery Platform on Blockchain (Ring + WebView + LibSQL + Ring2APK).

## Mission & Vision
- **No Centralized Monopoly**: Content creators and node operators own the platform, content, and revenue without rent-seeking corporate intermediaries.
- **Native Economy (WalaCoin / عملة الولاء)**: Fixed max emission (24,375,000 WALA). Transparent reward distribution based on quality contributions and node services.
- **Companion Embedded DB (No 404 NFT/Media Error)**: Built-in LibSQL replica on every node tightly coupled with blockchain hashes (avoiding expensive IPFS decay and Filecoin ongoing fees).
- **Sybil & Anti-Bot Defense**: Account balance thresholds and activity-rate limiting prevent bot swarms without KYC or invasive identity tracking.
- **12-Word Mnemonic Portability**: Private key import/export allows deterministic login and instant state recovery across all devices and browsers.

## Stack
- **Frontend**: Svelte + Tailwind + Vite (single standalone HTML bundle)
  - Internationalization: Full Arabic (RTL) & English (LTR) i18n support.
  - Themes: OLED Midnight (`#070709`) and Cyber Dark (`#12121c`).
  - Responsive: Single-column mobile dock view (<768px) and 3-column Twitter/Reddit desktop view (>=768px).
- **Backend**: Ring 1.27+ with LibSQL (`ring-libsql`), WebView (`ysdragon/webview`).
- **Mobile**: `ring2apk` (NativeActivity, bytecode embedding).
- **Sync**: LibSQL embedded replica (offline-first, zero downtime).
- **Docker**: `ring-docker` for deployment.

## Technical Rules
- Use `load "libsql.ring"` (never `sqlite.ring`).
- Use `conn.prepare()` + `bindString/bindInt/bindFloat` for all queries (zero raw SQL interpolation).
- WebView communication via `aBindList` + `bindMany(NULL)` + `wreturn(id, WEBVIEW_ERROR_OK, json)`.
- All keys and sensitive data encoded as valid UTF-8 Hex (`str2hex` / `hex2str`).
- Definition of Done: clean build (`npm run build`) + zero lint warnings + responsive UI test.

## Design Decisions
- **Token**: WalaCoin (WALA / عملة الولاء). Max emission: 24,375,000 WALA.
- **Content Scoring**: Merit-based ranking (1-5 stars & like interactions) with time decay algorithm.
- **Anti-Spam**: Free tier daily limits (15 posts / 45 ratings for new accounts), scaled up with WalaCoin balance.
- **UI Architecture**: Text-first compact feed cards, responsive multi-column on desktop (3 columns), floating navigation dock on mobile (<768px), bilingual RTL/LTR, OLED/Cyber Dark themes.

## Strategic Roadmap & Implementation Plans

### Phase 1: Sovereign Foundation & Bilingual Responsive UI (Completed & Refining)
- [x] **Companion Database Architecture**: Embedded LibSQL database with tables for accounts, posts, comments, likes, ratings, and transactions.
- [x] **Crypto Engine**: RSA 2048 keypair generation + AES-CBC encryption with PBKDF2 salt/IV safely hex-encoded (`str2hex`/`hex2str`) for LibSQL parameter safety.
- [x] **Universal Bilingual i18n**: Arabic (`dir="rtl"`, Cairo font) and English (`dir="ltr"`, Inter font) with instant reactive switching.
- [x] **Dual Premium Dark Themes**: OLED Midnight (`#070709`) and Cyber Dark (`#0d1117`) with glassmorphism and subtle glowing accents.
- [x] **Adaptive Responsive Layout**: 3-column desktop layout (Sidebar, Timeline, Telemetry/Trending widgets) + Mobile bottom floating dock.
- [x] **WalaCoin (WALA) Economy v1**: Faucet (+50 WALA), live balance, tipping mechanism on posts, and local transaction ledger.

### Phase 2: Decentralized Merit Engine & Rich Interactions (Completed & Active)
- [x] **12-Word Mnemonic Phrase System (BIP-39 Compatible)**:
  - Generate deterministic 12-word seed phrases for account generation.
  - One-click backup and mnemonic recovery to restore identity across any device/browser without centralized servers.
- [x] **Merit-Based Feed Algorithm (Pocketnet / Bastyon Model)**:
  - 1-5 star ratings alongside likes with real-time recalculation.
  - Merit feed formula: `Score = Sum(Rating_Weights) * 2 + Likes * 1.5`.
  - Filter tabs in timeline: "Latest 🕒", "Merit ⭐", and "Subscriptions 👥".
- [x] **Embedded Companion DB Media Storage**:
  - Local image upload and Base64 compression stored directly inside LibSQL companion database (`media_data`).
  - Eliminates external IPFS 404 drops and broken media links.
- [x] **Avatar Customization & Profile Media**:
  - Upload, compress, and update profile avatars stored in companion DB `users` table (`avatar_data`).
  - Image rendering in user personal streams.
- [x] **Followers & Subscriptions Graph**:
  - Decentralized follower system recorded in companion DB `follows` table.
  - Follow/Unfollow user interactions and follower counters.
- [x] **Sybil & Anti-Bot Defense (Daily Quota)**:
  - Free tier daily limits (25 posts/day) preventing automated bot spam.
- [x] **Smart Contract Engine & WalaCoin Token**:
  - `SmartContract` base class with persistent LibSQL key-value storage (`contract_state`).
  - `TokenContract` managing 24,375,000 WALA hard cap.
  - `RewardContract` distributing on-chain WALA rewards to creators on high-star ratings (>=3 stars).
  - `StakingContract` allowing users to lock WALA for additional daily post quotas (+1 post/day per 10 WALA staked).
  - `ContractManager` orchestrating all contracts and bridging to `BlockchainService` and `PostService`.

### Phase 3: P2P Network, Sybil Defense & Consensus Engine
- [x] **Sybil & Anti-Bot Dynamic Rate Limiting (Staking Quotas)**:
  - Daily post/comment/rating quotas tied to WalaCoin balance and staked coins.
  - Free tier (25 posts/day) for new accounts without KYC, expanding proportionally (+1 post per 10 WALA staked).
  - Interactive wallet staking dashboard in frontend.
- [ ] **LibSQL Embedded Replica Synchronization**:
  - P2P block exchange and Merkle root verification.
  - Node-to-node gossip protocol for instant post broadcast and transaction mempool.
- [ ] **Validator & Storage Node Incentives**:
  - Block rewards (mining/minting) distributed to nodes providing storage and network uptime via `RewardContract`.

### Phase 4: Encrypted Sovereign Communication
- [ ] **End-to-End Encrypted (E2EE) Direct Messaging**:
  - Asymmetric encryption using recipient's public key (RSA / Curve25519).
  - Decentralized message queue stored in companion DB until retrieved.
- [ ] **P2P Decentralized Notifications**:
  - Instant on-chain notifications for tips, mentions, comments, and ratings.

### Phase 5: Mobile Packaging & Distribution
- [x] **Standalone Desktop Bundling (ring2exe-plus)**:
  - Native binary compilation via `ring2exe-plus` with `-gui` (console hidden), `-auto-libs` (runtime DLLs bundled), `-icon` branding, and `ring2exe.conf`.
  - Professional Inno Setup installer script with bilingual UI, custom protocol `mejde://`, and desktop shortcuts (`installer/mejde_installer.iss`).
  - Standalone multi-platform build scripts (`scripts/build_desktop.bat` & `scripts/build_desktop.sh`).
- [x] **Ring2APK Android Build Pipeline**:
  - Official `Ring2ApkConfig` configuration in `ring2apk.ring` for ARM64/ARMv7/x86_64, Android SDK 34, embedded LibSQL, and WebView singlefile bundle.
  - Automated APK packaging script (`android/build_apk.bat` & `android/build_apk.sh`) + automated environment setup (`android/setup_android_env.bat`).
- [ ] **One-Click Node Deployment (Docker)**:
  - `ring-docker` container for running a full validator/companion node on headless VPS or home server.

