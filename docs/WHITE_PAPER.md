# Mejde (مجد) Network: Whitepaper & System Architecture
**A Truly Decentralized, Self-Sovereign Social Platform & Digital Economy on Blockchain**

*Version 1.0 — September 2026*  
*Authors: The Mejde Core Protocol Contributors*  
*Website / Repository: [Mejde Network](file:///g:/RingProject/Project/SocialChain)*

---

## Abstract

Centralized social networks have devolved into extractive surveillance architectures that monetize human attention, enforce arbitrary algorithmic censorship, and expropriate value from content creators. Existing Web3 attempts often suffer from the "NFT 404 Error"—external IPFS link degradation, prohibitive gas fees, and complex onboarding that alienates mainstream users.

**Mejde** (Arabic: **مَجْد**, meaning *Glory* or *Merit*) is an open-source, peer-to-peer social discovery network, companion database, and sovereign digital economy built on the **Ring Programming Language**, **LibSQL**, and **RingSockets**. Mejde eliminates centralized intermediaries through five foundational pillars:

1. **WalaCoin (عملة الولاء)**: A native cryptocurrency with a hard-coded emission cap of **24,375,000 WALA**, governed by on-chain smart contracts.
2. **Companion Embedded Database Architecture**: An offline-first LibSQL replica running locally on every node, permanently pairing media and social graphs with blockchain hashes to eliminate IPFS gateway decay.
3. **Merit-Weighted Content Engine**: A decentralized curation protocol inspired by the Bastyon/Pocketnet meritocracy model, utilizing 1–5 star ratings, stake weights, and time-decay curves to surface high-signal discourse without manipulative engagement algorithms.
4. **Zero-KYC Sybil & Anti-Bot Defense**: Dynamic daily publication quotas scaled mathematically by token staking, preventing bot floods while preserving uncompromising user anonymity.
5. **Deterministic 12-Word Mnemonic Identity**: Complete wallet and profile portability derived from standard BIP-39 mnemonic seeds, allowing instant state recovery across desktop, mobile, and web runtimes.

---

## Table of Contents

1. [Introduction & Problem Statement](#1-introduction--problem-statement)
2. [Design Philosophy & Core Axioms](#2-design-philosophy--core-axioms)
3. [System Architecture](#3-system-architecture)
   - 3.1 [Tri-Tier Runtime Topology](#31-tri-tier-runtime-topology)
   - 3.2 [The Companion Embedded Database (LibSQL)](#32-the-companion-embedded-database-libsql)
   - 3.3 [P2P Gossip & RingSockets Protocol](#33-p2p-gossip--ringsockets-protocol)
4. [WalaCoin (WALA) Tokenomics](#4-walacoin-wala-tokenomics)
   - 4.1 [Monetary Policy & Fixed Hard Cap](#41-monetary-policy--fixed-hard-cap)
   - 4.2 [Token Utility Matrix](#42-token-utility-matrix)
   - 4.3 [Smart Contract Architecture](#43-smart-contract-architecture)
5. [The Decentralized Merit Engine](#5-the-decentralized-merit-engine)
   - 5.1 [Merit Score Calculation Formula](#51-merit-score-calculation-formula)
   - 5.2 [Creator Incentives via RewardContract](#52-creator-incentives-via-rewardcontract)
6. [Sybil Defense & Staking Quotas](#6-sybil-defense--staking-quotas)
7. [Cryptographic Identity & Privacy](#7-cryptographic-identity--privacy)
   - 7.1 [BIP-39 Mnemonic Derivation](#71-bip-39-mnemonic-derivation)
   - 7.2 [Asymmetric Encryption (RSA 2048) & E2EE Direct Messaging](#72-asymmetric-encryption-rsa-2048--e2ee-direct-messaging)
   - 7.3 [Hex-Safe LibSQL Parameter Isolation](#73-hex-safe-libsql-parameter-isolation)
8. [Node Operations & Network Verification](#8-node-operations--network-verification)
   - 8.1 [Headless Server Node (`node.ring`)](#81-headless-server-node-nodering)
   - 8.2 [Command-Line Client (`cli.ring`)](#82-command-line-client-cliring)
   - 8.3 [Desktop & Mobile Client (`app.ring` & Ring2APK)](#83-desktop--mobile-client-appring--ring2apk)
9. [Roadmap & Strategic Milestones](#9-roadmap--strategic-milestones)
10. [Conclusion](#10-conclusion)

---

## 1. Introduction & Problem Statement

Modern social internet platforms suffer from three systemic crises:

### 1.1 The Extraction Crisis
Centralized platforms (Twitter/X, Facebook, Reddit) monetize creator content while capturing up to 100% of the advertising revenue. Creators are exposed to unpredictable demonetization, platform lock-in, and sudden policy shifts without recourse.

### 1.2 The Storage Fragility Crisis (The "NFT 404" Flaw)
Early Web3 social networks attempted to offload media to external services like IPFS gateways, Filecoin, or Arweave. In practice, public IPFS gateways frequently experience timeout drops, garbage-collection purges, and subscription expirations, causing user media and avatars to disappear into permanent HTTP 404 errors.

### 1.3 The Sybil vs. Privacy Paradox
To combat bot farms and spam swarms, centralized platforms increasingly enforce intrusive Know-Your-Customer (KYC) verifications, phone-number tracking, and biometric scans. Conversely, completely permissionless protocols frequently collapse under spam floods without a viable economic friction layer.

---

## 2. Design Philosophy & Core Axioms

Mejde is engineered under four foundational axioms:

* **Self-Sovereignty**: Users retain sole custody of their private keys, social identity, follow graph, and balances. No central server or administrator holds master override authority.
* **Embedded Permanence**: Media, posts, and social metadata are embedded directly inside local LibSQL database replicas synchronized across peers. If a node is alive, its content is permanently accessible.
* **Merit-Weighted Organic Reach**: Content distribution is dictated by transparent mathematical scoring based on authentic human merit and star ratings, rather than rage-inducing algorithmic engagement loops.
* **Universal Accessibility**: First-class bilingual native support (Right-to-Left Arabic and Left-to-Right English), low barrier to entry (no initial gas fees required to browse or post within free tiers), and ultra-lightweight hardware requirements.

---

## 3. System Architecture

### 3.1 Tri-Tier Runtime Topology

```
+--------------------------------------------------------------------------+
|                            MEJDE NETWORK                                 |
+--------------------------------------------------------------------------+
       |                                                    |
       v                                                    v
+-------------------------------+            +-------------------------------+
|  Headless Node Server         |            |  Client Application (GUI)     |
|  (`node.ring`)                |            |  (`app.ring` / Ring2APK)      |
|  - Ring 1.27+ Core            |  P2P HTTP  |  - Svelte 5 + Tailwind Engine |
|  - Native RingSockets Daemon  |<---------->|  - WebView Desktop Container  |
|  - LibSQL Local Companion DB  |   Gossip   |  - Dual Theme (OLED / Cyber)  |
|  - Smart Contract Manager     |            |  - BIP-39 Wallet Manager      |
+-------------------------------+            +-------------------------------+
       ^                                                    ^
       |                      Local / Remote REST           |
       +----------------------------------------------------+
                                |
                                v
                 +-------------------------------+
                 |  CLI Management Tool          |
                 |  (`cli.ring`)                 |
                 |  - Headless Node Testing      |
                 |  - Account Balance / Refill   |
                 |  - Direct Peer-to-Peer CLI    |
                 +-------------------------------+
```

The system operates across three seamlessly synchronized components:
1. **Headless Server Node (`node.ring`)**: High-performance daemon operating in server or headless VPS environments without GUI dependencies. Hosts the RingSockets HTTP sync listener, processes gossip broadcasts, and maintains block integrity.
2. **Desktop & Mobile Application (`app.ring`)**: Modern client providing an OLED/Cyber Dark UI, responsive multi-column layout on desktop, floating navigation dock on mobile, and biometric/mnemonic identity storage.
3. **CLI Control Tool (`cli.ring`)**: Command-line administrative interface for DevOps, automated health monitoring, transaction broadcasting, and peer status queries.

### 3.2 The Companion Embedded Database (LibSQL)

Unlike traditional blockchain designs that decouple transactions from storage, Mejde implements a **Companion LibSQL Database Architecture** (`core/Database.ring`).

```
+------------------------------------------------------------------+
|                   Local Companion LibSQL Node                    |
+------------------------------------------------------------------+
| Tables:                                                          |
|  - users        : id, username, pubkey, enc_privkey, bio, avatar |
|  - posts        : id, user_id, content, media_cid, media_data    |
|  - ratings      : user_id, post_id, stars, created_at            |
|  - comments     : id, post_id, user_id, content, created_at      |
|  - transactions : id, sender, receiver, amount, signature, block |
|  - blocks       : id, previous_hash, merkle_root, nonce, hash    |
|  - messages     : id, sender, receiver, enc_content, iv, is_read |
|  - peers        : url, name, last_seen, status, blocks_count     |
|  - contract_state: contract_id, state_key, state_val             |
+------------------------------------------------------------------+
```

* **Embedded Media Storage (`media_data`)**: Images are compressed on the client, converted to Base64 data structures, and inserted directly into the node's companion database. Media is broadcasted along with post metadata via gossip, guaranteeing zero 404 links.
* **Prepared Parameter Isolation**: All queries strictly enforce prepared statements with parameter binding (`prepare()`, `bindString()`, `bindFloat()`, `bindInt()`), totally eradicating SQL injection vectors.

### 3.3 P2P Gossip & RingSockets Protocol

Network communication is handled by Mejde's gossip protocol implemented natively in `p2p/P2PServer.ring` and `services/P2PSyncService.ring` using official **RingSockets** (`sockets.ring`):

* **Standard Endpoints**:
  - `GET /p2p/status`: Node telemetry, active peers, block count, post count, transaction ledger height.
  - `GET /p2p/posts`, `GET /p2p/blocks`, `GET /p2p/transactions`, `GET /p2p/peers`: Data exchange feeds for newly joined nodes.
  - `POST /p2p/broadcast`: Real-time push notification for newly mined blocks, published posts, star ratings, and transactions.
  - `POST /p2p/faucet_request`: Autonomous token circulation grant endpoint hosted by the Genesis Mother Node.

---

## 4. WalaCoin (WALA) Tokenomics

### 4.1 Monetary Policy & Fixed Hard Cap

**WalaCoin (عملة الولاء - WALA)** is the native utility and settlement token of Mejde.

* **Hard Cap**: Exactly **24,375,000.0000 WALA**.
* **Zero Inflation**: No protocol backdoor or governance vote can increase total token emission beyond the 24,375,000 WALA ceiling.
* **Smallest Unit**: 0.0001 WALA.

```
Total Max Emission: 24,375,000 WALA
[============================================================] 100%
  - Genesis Faucet & Community Bootstrap Pool:  25%
  - Content Creator Merit Rewards (Ongoing):    45%
  - Node Operator & Storage Verification Pool:   20%
  - Core Development & Security Bounty Reserve: 10%
```

### 4.2 Token Utility Matrix

| Use Case | Description | Economic Effect |
| :--- | :--- | :--- |
| **Creator Tipping** | Direct peer-to-peer micro-tipping on timeline posts. | Organic velocity, 100% value transfer to creator. |
| **Quota Staking** | Locking WALA to expand daily post and rating quotas. | Reduces circulating supply (deflationary pressure). |
| **Merit Rewards** | Automatic protocol minting/reward for >= 3-star posts. | Value accrual for high-signal content. |
| **Node Incentives**| Node operators claim compensation for bandwidth & uptime. | Secures storage replication and decentralization. |

### 4.3 Smart Contract Architecture

The smart contract subsystem is coordinated by `blockchain/ContractManager.ring` and persists state to LibSQL's `contract_state` table:

1. **`TokenContract` (`contracts/TokenContract.ring`)**:
   - Manages token ledger balances, mint allowances, and validates the 24,375,000 WALA cap.
2. **`RewardContract` (`contracts/RewardContract.ring`)**:
   - Evaluates content rating distributions and distributes on-chain rewards to creators who receive authentic ratings.
   - Dispenses uptime rewards to node operators via `rewardNodeOperator()`.
3. **`StakingContract` (`contracts/StakingContract.ring`)**:
   - Locks user funds into staking pools and calculates dynamic post limits:
     $$\text{Daily Quota} = \text{Base Quota (25)} + \left\lfloor \frac{\text{Staked WALA}}{10} \right\rfloor$$

---

## 5. The Decentralized Merit Engine

Traditional social algorithms maximize engagement through controversy, rage bait, and tribal conflict. Mejde introduces the **Merit Engine**, inspired by Pocketnet/Bastyon, replacing black-box algorithms with transparent mathematical scoring.

### 5.1 Merit Score Calculation Formula

Every post accumulates merit through community ratings (1 to 5 stars) and likes. The merit score $M(p)$ for post $p$ is computed as:

$$M(p) = \left[ \sum_{i=1}^{n} w(r_i) \cdot 2.0 + L \cdot 1.5 \right] \cdot e^{-\lambda \cdot \Delta t}$$

Where:
* $r_i \in \{1, 2, 3, 4, 5\}$ is an individual star rating.
* $w(r_i)$ is the rating weight (ratings from staked accounts carry proportionally higher validity, shielding against newly created sockpuppet accounts).
* $L$ is total verified likes count.
* $\Delta t = (t_{\text{now}} - t_{\text{created}})$ in hours.
* $\lambda$ is the time-decay constant ensuring fresh, timely content continually surfaces to the timeline.

### 5.2 Creator Incentives via RewardContract

When a post receives community acclaim (average rating $\ge 3.0$ stars from distinct user accounts), `PostService.ring` coordinates with `RewardContract.ring` to automatically credit protocol rewards directly to the author's wallet.

---

## 6. Sybil Defense & Staking Quotas

Mejde avoids invasive KYC procedures through a multi-tier economic rate-limiting framework:

```
+-------------------------------------------------------------------+
|               SYBIL DEFENSE RATE-LIMITING HIERARCHY               |
+-------------------------------------------------------------------+
| Free Tier (New Account)   | 25 Posts / Day   | 45 Ratings / Day   |
| Staked Tier (+100 WALA)   | 35 Posts / Day   | 90 Ratings / Day   |
| Staked Tier (+500 WALA)   | 75 Posts / Day   | 250 Ratings / Day  |
| Staked Tier (+2,500 WALA) | 275 Posts / Day  | Unlimited Ratings  |
+-------------------------------------------------------------------+
```

* **Zero-Balance Protection**: A brand new user can immediately post up to 25 items daily and interact without spending fiat or purchasing crypto.
* **Spam Disincentive**: Automated bot swarms attempting to flood the network with millions of posts would require locking millions of WALA tokens, creating financial resistance that renders spam economically unviable.

---

## 7. Cryptographic Identity & Privacy

### 7.1 BIP-39 Mnemonic Derivation

User identity is initialized using a deterministic 12-word seed phrase (`frontend/src/lib/WalletOnboarding.svelte`):
* Generated from cryptographic entropy.
* Allows instantaneous identity recovery on any fresh installation or browser session without relying on email, SMS, or centralized passwords.

### 7.2 Asymmetric Encryption (RSA 2048) & E2EE Direct Messaging

* **Key Generation**: Upon account creation, `utils/Crypto.ring` generates an RSA 2048-bit keypair.
* **Public Key**: Broadcasted and stored in the `users` table as the user's public identity.
* **Private Key**: Encrypted locally with AES-256-CBC using a key derived from the user's password via PBKDF2 (10,000 iterations). The plaintext private key never touches disk unencrypted.
* **Direct Messaging (E2EE)**: Messages between `@alice` and `@bob` are encrypted using AES session keys sealed with the recipient's RSA public key. Only the intended recipient holding the corresponding private key can decrypt the message payload.

### 7.3 Hex-Safe LibSQL Parameter Isolation

To prevent corruption from binary byte collisions with LibSQL statement parsers, all cryptographic nonces, salts, initialization vectors (IVs), and ciphertext blobs are encoded as uppercase UTF-8 Hex strings via `str2hex()` and decoded via `hex2str()`.

---

## 8. Node Operations & Network Verification

### 8.1 Headless Server Node (`node.ring`)

Full node operators and validators can deploy headless instances on Linux/Windows VPS servers or local hardware:

```bash
# Launch Genesis Mother Node (Port 8545)
ring node.ring 8545 social_mother.db

# Launch Peer Node (Port 8546) auto-syncing with Mother Node
ring node.ring 8546 social_peer.db http://127.0.0.1:8545
```

### 8.2 Command-Line Client (`cli.ring`)

The lightweight CLI provides complete network inspection and transaction dispatching without a browser or GUI:

```bash
# Query node telemetry
ring cli.ring 8545 status

# Check account balance
ring cli.ring 8545 balance user_alice

# Request initial token grant from Mother Node
ring cli.ring 8545 refill user_alice 100

# Publish a post directly to the blockchain
ring cli.ring 8545 post user_alice "Decentralized speech is unyielding."

# Dispatch a peer-to-peer WALA transfer
ring cli.ring 8545 send user_alice user_bob 25

# Trigger manual synchronization on a peer node
ring cli.ring 8546 sync
```

### 8.3 Desktop & Mobile Client (`app.ring` & Ring2APK)

Users experience Mejde as a standalone desktop executable (powered by `ysdragon/webview`) or Android APK (compiled via `ring2apk`):
* Single-bundle local asset loading (instant startup, zero external CDN dependencies).
* Interactive Web3 metallic wallet card with live balance counter, QR receiving modal, and staking slider.
* Full bilingual Arabic (Cairo font, RTL) & English (Inter font, LTR) interface.

---

## 9. Roadmap & Strategic Milestones

```
+---------------------------------------------------------------------+
| Phase 1: Sovereign Foundation & Bilingual UI            [COMPLETED] |
| Phase 2: Decentralized Merit Engine & Companion DB      [COMPLETED] |
| Phase 3: P2P Gossip Network & Headless Node Daemon      [COMPLETED] |
| Phase 4: Encrypted Sovereign Communication (E2EE)       [IN PROGRESS]|
| Phase 5: Mobile Compilation (Ring2APK) & Docker Nodes   [ACTIVE]     |
+---------------------------------------------------------------------+
```

* **Phase 1 (Completed)**: LibSQL companion database, dual dark themes, bilingual i18n, RSA 2048 keypairs.
* **Phase 2 (Completed)**: BIP-39 mnemonic phrase wallet, merit algorithm, direct Base64 media storage, smart contracts suite (`TokenContract`, `RewardContract`, `StakingContract`).
* **Phase 3 (Completed)**: RingSockets P2P gossip server daemon, headless server node (`node.ring`), CLI client (`cli.ring`), live multi-node synchronization and WALA circulation.
* **Phase 4 (In Progress)**: Full asymmetric E2EE messaging queue, real-time decentralized notifications.
* **Phase 5 (Active)**: Automated `ring2apk` mobile builds for Android NativeActivity and one-click Docker Compose validator orchestration.

---

## 10. Conclusion

Mejde proves that social discovery and blockchain economics can converge without sacrificing user experience, performance, or privacy. By coupling Ring's lightweight cross-platform execution with an embedded LibSQL companion database and native RingSockets gossip protocol, Mejde restores the internet to its original promise: an open, peer-to-peer network where creators own their audience, speech remains unconstrained, and economic value circulates freely without corporate tolls.

---

### Technical References & Specifications
1. **Ring Programming Language**: [Official Documentation](https://ring-lang.github.io/)
2. **LibSQL / SQLite**: Embedded replica architecture for distributed systems.
3. **BIP-39**: Mnemonic code for generating deterministic keys.
4. **Pocketnet / Bastyon**: Decentralized proof-of-stake merit social network model.
5. **RingSockets**: Native TCP/IP and HTTP networking extension for Ring.
