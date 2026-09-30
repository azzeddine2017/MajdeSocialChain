# Mejde (مجد) - Decentralized Sovereign Social Network & Blockchain

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ring Language](https://img.shields.io/badge/Language-Ring_1.27+-purple.svg)](https://ring-lang.github.io/)
[![Database](https://img.shields.io/badge/Companion_DB-LibSQL-emerald.svg)](https://github.com/tursodatabase/libsql)
[![Token](https://img.shields.io/badge/Token-WalaCoin_(WALA)-amber.svg)](docs/WHITE_PAPER.md)
[![Platform](https://img.shields.io/badge/Platform-Desktop_|_Android_|_Headless_Node-cyan.svg)](docs/DISTRIBUTION_GUIDE.md)

**Mejde (مجد)** is a truly decentralized, censorship-resistant social discovery platform, creator economy, and companion blockchain network built with **Ring**, **LibSQL**, **WebView**, and **Ring2APK**.

Rooted in the cypherpunk ethos and Bitcoin's philosophy of self-sovereignty, Mejde returns platform governance, content ownership, and monetization rights directly to creators and node operators—eliminating algorithmic manipulation, corporate rent-seeking, and invasive identity surveillance.

> 📄 **Official Whitepaper & Architecture**: Read the full technical specification in [docs/WHITE_PAPER.md](docs/WHITE_PAPER.md).  
> 📦 **Multi-Platform Distribution Guide**: Learn how to package standalone Windows/Linux executables, Inno Setup installers, and Android APKs in [docs/DISTRIBUTION_GUIDE.md](docs/DISTRIBUTION_GUIDE.md).

---

## 🌟 Core Innovations & Highlights

### 1. WalaCoin (WALA / عملة الولاء) & Native Tokenomics
* **Fixed Hard Cap**: Exact lifetime emission ceiling of **24,375,000 WALA** (no inflation or corporate dilution).
* **Sub-Unit Precision**: 1 WALA = 1,000,000 Ikhlas (IKH / إخلاص) for low-latency micro-transactions and creator tipping.
* **On-Chain Micro-Tipping**: Reward posts directly from feed cards with zero intermediary transaction fees.
* **Crypto On-Ramp**: Built-in P2P and USDT on-ramps to fund wallets seamlessly.

### 2. Companion Embedded Database (LibSQL)
* **Zero 404 NFT/Media Errors**: Solves the notorious IPFS gateway timeout and file expiration issues. Media blobs and attachments are content-addressed (SHA-256) and persistently replicated across companion node databases.
* **Offline-First Resilience**: Full local cache enables instant feed loading and wallet operations even with intermittent internet connectivity.

### 3. BIP-39 Deterministic Mnemonic Portability
* **Self-Sovereign Identity**: Generate standard 12-word recovery seed phrases for deterministic RSA 2048 keypair derivation.
* **Cross-Device Portability**: Restore your entire identity, subscriber graph, transaction ledger, and posts across any phone, browser, or desktop without centralized servers.
* **Local AES-256 Vault**: Private keys are securely encrypted at rest using PBKDF2 salt derivation and AES-CBC hex encoding.

### 4. Merit-Based Discovery Algorithm
* **Pocketnet / Bastyon Model**: Transparent 1–5 star community ratings coupled with like interactions replace opaque black-box feeds:
  $$\text{Merit Score} = \sum (\text{Rating Weights}) \times 2.0 + (\text{Likes} \times 1.5)$$
* **Feed Filters**: Instant toggling between **Merit ⭐**, **Latest 🕒**, and **Subscriptions 👥**.
* **Automated Creator Rewards**: High-scoring posts ($\ge 3$ stars) trigger automated smart contract reward distributions via `RewardContract`.

### 5. Sybil Defense & Dynamic Staking Quotas
* **Free Tier Daily Quota**: New accounts receive a daily limit (25 posts/day) preventing automated bot spam swarms without requiring KYC or invasive phone verification.
* **Staking Boost**: Stake WALA coins via `StakingContract` to unlock scaled publishing throughput (+1 post/day per 10 WALA staked).

### 6. End-to-End Encrypted (E2EE) Direct Messaging
* **Asymmetric Key Exchange**: Messages are encrypted using recipient public keys (RSA / AES-256-CBC) with local salts/IVs.
* **Decentralized Inbox**: Private communication stored in companion databases and decrypted strictly on user devices.

### 7. Universal Bilingual Responsive UI
* **True Bilingual i18n**: Seamless, reactive switching between Arabic (`dir="rtl"`, Cairo typography) and English (`dir="ltr"`, Inter typography).
* **Dual Ultra-Dark Themes**: **OLED Midnight** (`#070709`) and **Cyber Dark** (`#12121c`) with subtle glowing glassmorphism accents.
* **Adaptive Multi-Device Layout**:
  * **Desktop ($\ge 768\text{px}$)**: 3-column timeline (Navigation Dock, Main Feed, Trending Telemetry).
  * **Mobile ($< 768\text{px}$)**: Single-column feed with bottom floating dock for smooth one-thumb navigation.

---

## 📁 Repository Structure

```
SocialChain/
├── app.ring                 # Native WebView Desktop application & JS RPC bridges
├── node.ring                # Standalone Headless Node Server (P2P gossip daemon)
├── cli.ring                 # CLI node testing, transaction, and management utility
├── ring2apk.ring            # Official Ring2APK mobile packaging configuration
├── ring2exe.conf            # ring2exe-plus desktop compilation configuration
├── docs/
│   ├── WHITE_PAPER.md       # Comprehensive Whitepaper & System Architecture
│   └── DISTRIBUTION_GUIDE.md# Multi-platform desktop & APK deployment guide
├── core/
│   ├── Database.ring        # Embedded LibSQL companion database manager
│   ├── Model.ring           # Base data model class
│   └── Service.ring         # Base service result wrapper
├── blockchain/
│   ├── SmartContract.ring   # Base smart contract class with persistent LibSQL state
│   └── ContractManager.ring # Central coordinator for token, reward, and staking contracts
├── contracts/
│   ├── TokenContract.ring   # WalaCoin (WALA) smart contract (24,375,000 WALA hard cap)
│   ├── RewardContract.ring  # Merit creator rewards & node validator incentives
│   └── StakingContract.ring # WALA staking pool & dynamic post quota booster
├── services/
│   ├── BlockchainService.ring # Ledger balance, mining, and transaction validation
│   ├── PostService.ring     # Post creation, comments, ratings, and profile hydration
│   ├── MediaStorageService.ring # Content-Addressable Storage (CAS) for media & avatars
│   ├── MessageService.ring  # End-to-end encrypted (E2EE) direct messaging
│   └── P2PSyncService.ring  # P2P HTTP gossip synchronization engine
├── p2p/
│   └── P2PServer.ring       # Standalone P2P TCP socket daemon
├── models/
│   ├── Block.ring           # Blockchain block model
│   ├── Transaction.ring     # Ledger transaction model
│   ├── Post.ring            # Post data model
│   └── User.ring            # User account model
├── utils/
│   ├── Crypto.ring          # RSA 2048 keypair & AES-256 PBKDF2 vault
│   ├── Crypto_Internal.ring # Low-level OpenSSL cipher wrappers
│   ├── Logger.ring          # System logging utility
│   └── Validator.ring       # Input and format sanitization
├── frontend/
│   ├── src/
│   │   ├── lib/
│   │   │   ├── i18n.js      # Bilingual translation engine (Arabic & English)
│   │   │   ├── Feed.svelte  # Merit feed with star ratings and thread comments
│   │   │   ├── CreatePost.svelte # Compact composer with camera & media uploads
│   │   │   ├── WalletView.svelte # Web3 metallic card, faucet, staking & ledger
│   │   │   ├── MessagesView.svelte # E2EE Direct Messenger with tipping
│   │   │   ├── ProfileView.svelte# User profile, avatar uploads & personal stream
│   │   │   ├── Stories.svelte    # Trending hashtags & network telemetry widget
│   │   │   └── WalletOnboarding.svelte # 12-word seed & password login
│   │   ├── App.svelte       # Main responsive adaptive layout (Mobile + Desktop)
│   │   └── app.css          # Design system tokens, OLED styling & animations
│   └── vite.config.js       # Vite singlefile bundle build configuration
├── installer/
│   └── mejde_installer.iss  # Inno Setup Windows installer script (Bilingual)
├── android/
│   ├── build_apk.bat        # Automated Android APK build script (Windows)
│   ├── build_apk.sh         # Automated Android APK build script (Linux/macOS)
│   └── setup_android_env.bat# One-click Android SDK/NDK environment bootstrapper
└── scripts/
    ├── build_desktop.bat    # Automated desktop executable bundler (Windows)
    └── build_desktop.sh     # Automated desktop executable bundler (Linux)
```

---

## 🗺️ Strategic Phased Roadmap

### 📍 Phase 1: Sovereign Foundation & Bilingual Responsive UI (Completed)
- [x] **Companion Database Architecture**: Embedded LibSQL database tables for users, posts, comments, likes, ratings, transactions, and media blobs.
- [x] **Universal Bilingual UI**: Full Arabic (RTL, Cairo font) and English (LTR, Inter font) with instant reactive switching.
- [x] **Dual Dark Themes**: OLED Midnight (`#070709`) and Cyber Dark (`#12121c`) with glassmorphism effects.
- [x] **Adaptive Responsive Layout**: 3-column desktop layout (Sidebar, Timeline, Telemetry) + Mobile bottom navigation dock.
- [x] **WalaCoin (WALA) Economy v1**: Faucet (+50 WALA), real-time balance tracking, and post tipping.

### 📍 Phase 2: Decentralized Merit Engine & Rich Media (Completed)
- [x] **12-Word Mnemonic Seed System**: Deterministic BIP-39 compatible key derivation for zero-server login and portable recovery.
- [x] **Merit-Based Feed Algorithm**: 1–5 star ratings combined with likes, real-time recalculation, and timeline filters.
- [x] **Companion DB Media Storage**: Base64 local image upload and compression stored in SQLite `media_blobs` with SHA-256 CID, eliminating 404 media decay.
- [x] **Avatar Customization & Profile Media**: In-app avatar uploads, camera selection, and personal profile stream rendering.
- [x] **Decentralized Follow Graph**: Follow/unfollow mechanics and dynamic follower counts.
- [x] **Smart Contract Engine**: LibSQL persistent state storage with `TokenContract`, `RewardContract`, and `StakingContract`.

### 📍 Phase 3: P2P Network, Anti-Bot & Consensus Engine (Active & Refining)
- [x] **Dynamic Anti-Bot Rate Limiting**: Free-tier limits (25 posts/day) expandable through WALA staking (+1 post/day per 10 WALA staked).
- [x] **Peer-to-Peer HTTP Gossip Synchronization**: Asynchronous block and post propagation via `P2PSyncService`.
- [ ] **LibSQL Distributed Replica Sync**: Decentralized block exchange with Merkle root verification.
- [ ] **Validator & Storage Node Incentives**: Automated block rewards for network uptime and storage provision.

### 📍 Phase 4: Encrypted Sovereign Communication (Active)
- [x] **End-to-End Encrypted (E2EE) Direct Messaging**: Private message encryption using AES-256-CBC and RSA key exchange.
- [x] **Decentralized In-App Notifications**: On-chain alerts for tips, comments, and mentions.
- [ ] **Decentralized P2P Push Relays**: Node-to-node push notification relay without centralized push gateways (FCM/APNs).

### 📍 Phase 5: Mobile Packaging & Production Distribution (Completed)
- [x] **Standalone Desktop Bundling (`ring2exe-plus`)**: Console-free native Windows/Linux binaries with bundled runtime libraries.
- [x] **Professional Inno Setup Installer**: Bilingual installer script with desktop shortcuts and `mejde://` custom protocol registration.
- [x] **Android Build Pipeline (`ring2apk`)**: NativeActivity bytecode embedding, embedded LibSQL, and Android WebView singlefile bundle.
- [ ] **One-Click Headless VPS Node (Docker)**: `ring-docker` container for running a validator node on any home server or cloud VPS.

---

## 🚀 Getting Started

### Prerequisites
- **Ring Language 1.27+**: [Download Ring](https://ring-lang.github.io/)
- **Node.js (v18+)**: [Download Node.js](https://nodejs.org/)
- **Ring Packages**:
  ```bash
  ringpm install webview from ysdragon
  ringpm install ring-libsql from ysdragon
  ```

---

### Running Mejde Locally

#### 1. Build the Frontend Singlefile Bundle
```bash
cd frontend
npm install
npm run build
cd ..
```

#### 2. Launch the Desktop Application
```bash
ring app.ring
```

#### 3. Run a Headless Node Server (P2P Daemon)
```bash
# Starts a Mother Node on port 8545 with default database social.db
ring node.ring 8545 social.db

# Or connect as a peer to an existing node
ring node.ring 8546 peer.db http://127.0.0.1:8545
```

#### 4. Interact via Node CLI
```bash
ring cli.ring
```

---

## 📦 Packaging & Distribution

### Building Desktop Binary (Windows & Linux)
Use the automated build scripts:
```cmd
:: On Windows
scripts\build_desktop.bat

# On Linux
chmod +x scripts/build_desktop.sh
./scripts/build_desktop.sh
```

### Creating the Inno Setup Windows Installer
1. Open [installer/mejde_installer.iss](installer/mejde_installer.iss) in **Inno Setup Compiler**.
2. Click **Compile** (`Ctrl + F9`).
3. The standalone installer will be generated at `release\Mejde_Setup_v1.0.0_x64.exe`.

### Building the Android APK (`ring2apk`)
```cmd
:: Windows
android\build_apk.bat

# Linux / macOS
chmod +x android/build_apk.sh
./android/build_apk.sh
```
The compiled APK will be produced at `build/Mejde-debug.apk` or `build/Mejde-release.apk`.

For full step-by-step instructions and troubleshooting, see the [Distribution Guide](docs/DISTRIBUTION_GUIDE.md).

---

## 📄 License & Philosophy

Mejde is free and open-source software licensed under the **MIT License**.  
Contributions, feedback, and independent node deployments are warmly welcomed!
